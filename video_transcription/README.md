# video_transcription

A self-contained command-line tool that turns lecture videos into **full text
transcripts**, using OpenAI's Whisper model running **locally on your CPU**.

Built for the case where a video has no captions (or unusable auto-captions) and
taking notes by hand is too slow to keep up.

- **Free and private** — no API keys, no cloud, no per-minute cost. Runs offline
  once the model is cached.
- **No `ffmpeg` required** — audio is decoded through the PyAV library bundled
  with `faster-whisper`.
- **No GPU required** — runs on CPU with int8 quantization, using all cores.
- Works on a single video, several videos, or a whole playlist.
- Works on YouTube and on other hosts (e.g. university Kaltura/MediaSpace sites).

---

## Contents

| File | Purpose |
|---|---|
| `transcribe.py` | The entire tool (single self-contained script) |
| `pyproject.toml` | Declares the two dependencies: `yt-dlp`, `faster-whisper` |
| `uv.lock` | Pins exact dependency versions for reproducible installs |
| `.python-version` | Pins Python 3.12 |
| `.gitignore` | Keeps `.venv/`, `transcripts/`, and `*.log` out of git |

That is the complete tool — about 90 KB. Everything else (the virtual
environment, the Whisper model, transcripts, logs) is generated on demand.

---

## 1. Prerequisites

**Python 3.12+** and **[uv](https://docs.astral.sh/uv/)** (the package manager
that handles the virtual environment for you).

```bash
python3 --version     # need 3.12 or newer
uv --version          # if missing, see install below
```

If `uv` is not installed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

You do **not** need `ffmpeg`, CUDA, or a GPU.

Roughly 2.5 GB of free disk is needed in total: ~420 MB for the virtual
environment plus ~1.5 GB for the `medium` Whisper model.

---

## 2. First-time setup

There is no install step. The first `uv run` reads `pyproject.toml` / `uv.lock`,
creates a `.venv/`, and installs the dependencies:

```bash
uv run transcribe.py --help
```

Expect this first run to take a minute or two while it downloads packages.

### If dependency downloads fail with a certificate error

On networks that intercept TLS (corporate proxies, some VPNs, WSL setups), you
may see:

```
× Failed to download `onnxruntime==1.27.0`
╰─▶ invalid peer certificate: UnknownIssuer
```

`uv` ships its own certificate bundle and does not trust your system's. Add
`--system-certs` for the setup run:

```bash
uv run --system-certs transcribe.py --help
```

Once `.venv/` exists, plain `uv run` works from then on. (The script itself
already handles this problem for *video downloads* — see
[How certificates are handled](#how-certificates-are-handled).)

---

## 3. Setting up the model

**You don't have to do anything.** The first time you transcribe, the chosen
Whisper model is downloaded automatically from Hugging Face and cached in:

```
~/.cache/huggingface/
```

Every later run reuses that cache and needs no network for the model, so
transcription works fully offline after the first download.

### Choosing a model

Whisper comes in sizes that trade speed against accuracy. Pass one with
`--model`; the default is `small`.

| Model | Download | Speed (CPU) | Accuracy | Use for |
|---|---|---|---|---|
| `tiny` | ~75 MB | fastest | low | quick skims only |
| `base` | ~140 MB | fast | okay | clear speakers, simple vocabulary |
| `small` | ~480 MB | moderate | good | **default**; general use |
| `medium` | ~1.5 GB | slow | very good | **recommended for technical lectures** |
| `large-v3` | ~3 GB | slowest | best | when accuracy really matters |

**Why `medium` for technical material:** smaller models mangle domain jargon. In
testing, `tiny` transcribed "elephant *trunks*" as "elephant *prompts*". For
compiler lectures — dominators, semilattices, phi nodes, Steensgaard's algorithm
— `medium` is the practical sweet spot.

To pre-download a model without transcribing anything:

```bash
uv run python -c "from faster_whisper import WhisperModel; WhisperModel('medium', device='cpu', compute_type='int8')"
```

### How long transcription takes

On a ~4-core CPU with `medium`, expect roughly **0.5×–1× the video's length**.
Measured examples:

```
$ time uv run transcribe.py "<20-min lecture>" --model medium --timestamps
real    13m45s        # wall clock
user    44m28s        # CPU time across all cores
sys      6m46s
```

`user` far exceeding `real` is expected and healthy: CTranslate2 (the engine
behind `faster-whisper`) is multithreaded and defaults to using all physical
cores. Here it averaged ~3.7 cores. A 60-minute lecture takes roughly 45–90
minutes; `small` is about 3× faster than `medium`.

---

## 4. Basic usage

```bash
# One video -> transcripts/<video_title>.txt
uv run transcribe.py "https://youtu.be/VIDEO_ID"

# Recommended for lectures: better model + timestamped copy
uv run transcribe.py "https://youtu.be/VIDEO_ID" --model medium --timestamps

# Several videos in one run (model loads once and is reused — much faster
# than separate invocations)
uv run transcribe.py "https://youtu.be/ID1" "https://youtu.be/ID2" "https://youtu.be/ID3" \
  --model medium --timestamps

# An entire playlist or channel
uv run transcribe.py "https://www.youtube.com/playlist?list=PLAYLIST_ID" --model medium

# A non-YouTube host with an untrusted certificate (see notes below)
uv run transcribe.py "https://vod.video.cornell.edu/media/1_abcd1234" \
  --model medium --timestamps --insecure

# Write somewhere other than ./transcripts
uv run transcribe.py "https://youtu.be/VIDEO_ID" --output-dir ~/notes/my_course
```

### All options

| Flag | Default | Description |
|---|---|---|
| `url ...` | — | One or more video/playlist URLs, transcribed in order |
| `-m`, `--model` | `small` | `tiny`, `base`, `small`, `medium`, `large-v3` |
| `-o`, `--output-dir` | `transcripts` | Where to write output files |
| `-l`, `--language` | auto-detect | Force a language code, e.g. `en` (slightly faster and more reliable) |
| `--timestamps` | off | Also write a `[HH:MM:SS -> HH:MM:SS]` version |
| `--skip-existing` | off | Skip videos whose transcript already exists — makes batches resumable |
| `--keep-audio` | off | Keep the downloaded audio file next to the transcript |
| `--insecure` | off | Disable TLS verification **for downloads only** (needed by some hosts) |
| `--device` | `cpu` | `cpu` or `cuda` |
| `--compute-type` | `int8` | CTranslate2 precision, e.g. `int8`, `float16` |

---

## 5. Output

For each video you get one or two files, named after the video title:

**`<title>.txt`** — the clean transcript:

```
Title: Compiler Design Module 25 : Introduction to Bottom up Parsing
Video ID: UuhxSihoeC8
Detected language: en
------------------------------------------------------------

So today we're going to look at bottom-up parsing, which is another parsing
algorithm that stands in stark contrast to recursive descent parsing...
```

**`<title>.timestamps.txt`** — the same content, segmented, when `--timestamps`
is used:

```
[00:00:00 -> 00:00:15] So today we're going to look at bottom-up parsing...
[00:00:15 -> 00:00:29] Unlike top-down parsing, which tries to derive...
```

Use the plain file for reading and searching; use the timestamped file to jump
back to the exact moment in the video.

---

## 6. Long batches: running in the background

Transcribing many lectures takes hours. Detach the job so it survives closing
the terminal, and set `PYTHONUNBUFFERED=1` so progress appears in the log
immediately instead of being buffered until the end:

```bash
PYTHONUNBUFFERED=1 nohup uv run transcribe.py \
  "https://youtu.be/ID1" \
  "https://youtu.be/ID2" \
  --model medium --timestamps --skip-existing \
  --output-dir ~/notes/my_course > batch.log 2>&1 &
```

Check on it:

```bash
tail -f batch.log                                   # live progress
ps -eo pid,pcpu,etime,cmd | grep "[t]ranscribe.py"  # is it alive?
```

A healthy run shows several hundred percent CPU (multi-core) and a log ending in
`[3/3] ... Transcribing: <title>`. Output files only appear once a video is
**fully** transcribed, so there is no mid-video progress percentage.

**Always use `--skip-existing` for batches.** If a run dies partway, re-running
the exact same command resumes and skips whatever already completed.

### Chaining a second batch behind a running one

Two jobs at once just split the CPU. To queue work instead, wait on the running
process ID:

```bash
nohup bash -c 'while kill -0 <PID> 2>/dev/null; do sleep 30; done
  export PYTHONUNBUFFERED=1
  exec uv run transcribe.py "https://youtu.be/ID1" "https://youtu.be/ID2" \
    --model medium --timestamps --skip-existing' > next_batch.log 2>&1 &
```

---

## 7. Verifying transcripts are complete

**This matters more than it sounds.** A download can be cut short and still
leave a *playable* audio file; Whisper will happily transcribe the fragment and
report success. The result looks fine but silently contains only part of the
lecture. This happened to four files in practice — one covered just 10% of its
video.

To check coverage, compare the last timestamp against the real video duration:

```bash
# Last timestamp actually transcribed
grep -oE '^\[[0-9:]+' "<title>.timestamps.txt" | tail -1

# True duration of the source video, in seconds
uv run yt-dlp --simulate --print "%(duration)s" "<url>"
```

Healthy files land at **98–99%** coverage; the small remainder is trailing
music or silence. Anything materially below that was truncated — re-run it
**without** `--skip-existing` so the partial file gets overwritten.

The downloader is configured with generous retries (`retries: 20`,
`fragment_retries: 20`, `socket_timeout: 60`) specifically to prevent this, but
it's still worth spot-checking after a large batch.

---

## 8. Troubleshooting

### `HTTP Error 403: Forbidden` on download

The most common failure in long batches. The tool logs it, skips that video,
continues, and lists the failed URLs at the end.

**First, check whether `yt-dlp` is out of date** — this is the single most
effective fix. YouTube changes its internals frequently, and a `yt-dlp` more
than a few weeks old starts failing with 403s that look like rate-limiting:

```bash
uv run yt-dlp --version                      # what you have
uv add --system-certs --upgrade yt-dlp       # update to latest
```

A stale `yt-dlp` (~2.5 months old) once caused 7 of 12 downloads in a batch to
fail, and made one video fail on every attempt; upgrading fixed it immediately.
Because `uv.lock` pins the version, the tool will *not* update on its own.

If it's already current, the 403 really is transient throttling: **re-run with
`--skip-existing`** so completed videos are skipped and only failures retried.
Heavy back-to-back downloading makes it more likely, so waiting an hour or two
helps.

### `Sign in to confirm you're not a bot`

YouTube's anti-bot gate, typically after many rapid downloads. Same remedy:
wait, then re-run with `--skip-existing`. If it persists, pass browser cookies
to `yt-dlp` (see its
[cookies FAQ](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)).

### `CERTIFICATE_VERIFY_FAILED` on a non-YouTube host

Some sites (university media servers in particular) present a certificate chain
that isn't in `yt-dlp`'s bundled `certifi` store, even though your system trusts
it. Add `--insecure` for that host:

```bash
uv run transcribe.py "https://vod.video.cornell.edu/media/1_abcd1234" --insecure
```

Only do this for hosts you trust. YouTube never needs it, and the flag changes
nothing unless you pass it.

### `Temporary failure in name resolution`

A brief local network/DNS hiccup. Re-run with `--skip-existing`.

### A long job vanished with an empty log

Almost certainly the machine rebooted or WSL shut down; an abrupt kill discards
Python's buffered output, leaving a 0-byte log. Confirm with `uptime -s` (boot
time). Use `PYTHONUNBUFFERED=1` so future runs record how far they got.

Note there is **no resume within a single video** — a 60-minute lecture that
gets killed starts over. Across a batch, `--skip-existing` preserves completed
videos, so prefer several medium batches over one enormous one.

### Wrong or misleading titles

Filenames come from the source page's title, which is occasionally wrong. One
Cornell video titled "Lesson 7: Interprocedural Analysis" is actually about loop
optimization. Skim the opening lines of a transcript if the title looks odd.

---

## How certificates are handled

`transcribe.py` sets `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, and `CURL_CA_BUNDLE`
to your system CA bundle (`/etc/ssl/certs/ca-certificates.crt` on Debian/Ubuntu,
`/etc/pki/tls/certs/ca-bundle.crt` on RHEL/Fedora) before importing `yt-dlp` or
`huggingface_hub`. That makes the Hugging Face model download work behind a
TLS-intercepting proxy without any flags.

`yt-dlp` ignores those variables and uses its own `certifi` bundle, which is why
the separate `--insecure` escape hatch exists for hosts it doesn't trust.

---

## How it works

```
URL ──> yt-dlp ──> raw audio stream ──> faster-whisper (Whisper, CPU int8) ──> .txt
```

1. `yt-dlp` fetches the best audio-only stream, without re-encoding (which is
   why no `ffmpeg` is needed).
2. Audio is decoded in-process by PyAV and fed to `faster-whisper`, a
   CTranslate2 reimplementation of Whisper that is faster and lighter on memory
   than the reference implementation.
3. Voice-activity filtering trims silence; segments are joined into the plain
   transcript and written with timestamps if requested.
4. Audio is downloaded to a temporary directory and deleted afterwards unless
   `--keep-audio` is set.

Each URL is processed independently, so one failure never aborts the batch.
