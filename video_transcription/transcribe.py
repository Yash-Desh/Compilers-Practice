#!/usr/bin/env python3
"""Download a YouTube video's audio and produce a raw transcript with local Whisper.

No system ffmpeg required: yt-dlp grabs the raw audio stream and faster-whisper
decodes it through its bundled PyAV library. Runs fully offline after the model
is downloaded once.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path


def configure_system_certs() -> None:
    """Point networking libs at the system CA bundle.

    Some networks intercept TLS with a proxy whose root CA lives only in the
    system trust store (not in certifi). Setting these env vars makes yt-dlp and
    huggingface_hub trust it. Must run before importing those libraries.
    """
    candidates = [
        "/etc/ssl/certs/ca-certificates.crt",  # Debian/Ubuntu
        "/etc/pki/tls/certs/ca-bundle.crt",    # RHEL/Fedora
    ]
    bundle = next((c for c in candidates if os.path.exists(c)), None)
    if not bundle:
        return
    for var in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE"):
        os.environ.setdefault(var, bundle)


def sanitize_filename(name: str, max_len: int = 120) -> str:
    """Make a string safe to use as a filename."""
    name = re.sub(r"[^\w\s.-]", "", name).strip()
    name = re.sub(r"\s+", "_", name)
    return (name or "transcript")[:max_len]


def download_audio(url: str, tmpdir: Path, insecure: bool = False) -> list[dict]:
    """Download best audio for a video or every entry in a playlist.

    Returns a list of dicts: {"title", "id", "path"}.

    insecure: when True, disables TLS certificate verification for yt-dlp. Only
    needed for trusted hosts whose cert chain isn't in yt-dlp's bundled certifi
    store (e.g. some university media sites). Off by default; YouTube never needs it.
    """
    from yt_dlp import YoutubeDL

    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": str(tmpdir / "%(id)s.%(ext)s"),
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "ignoreerrors": True,
        "nocheckcertificate": insecure,
        # Flaky hosts can drop a connection mid-download; without generous retries
        # yt-dlp leaves a truncated-but-playable audio file that silently produces
        # a partial transcript.
        "retries": 20,
        "fragment_retries": 20,
        "socket_timeout": 60,
    }

    results: list[dict] = []
    with YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        if info is None:
            return results
        entries = info["entries"] if "entries" in info else [info]
        for entry in entries:
            if not entry:
                continue
            path = Path(ydl.prepare_filename(entry))
            if not path.exists():
                # Extension can differ from the template; fall back to id glob.
                matches = list(tmpdir.glob(f"{entry.get('id', '')}.*"))
                if not matches:
                    continue
                path = matches[0]
            results.append(
                {
                    "title": entry.get("title") or entry.get("id") or "transcript",
                    "id": entry.get("id", ""),
                    "path": path,
                }
            )
    return results


def transcribe_file(model, audio_path: Path, language: str | None):
    """Return (full_text, segments) for one audio file."""
    segments, info = model.transcribe(
        str(audio_path),
        language=language,
        vad_filter=True,
        beam_size=5,
    )
    seg_list = list(segments)
    full_text = " ".join(s.text.strip() for s in seg_list).strip()
    return full_text, seg_list, info


def format_timestamp(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transcribe a YouTube video (or playlist) to a raw text file using local Whisper.",
    )
    parser.add_argument(
        "url", nargs="+",
        help="One or more YouTube video/playlist URLs (transcribed in order).",
    )
    parser.add_argument(
        "-m", "--model", default="small",
        help="Whisper model size: tiny, base, small, medium, large-v3 (default: small)",
    )
    parser.add_argument(
        "-o", "--output-dir", default="transcripts",
        help="Directory to write transcript files (default: transcripts)",
    )
    parser.add_argument(
        "-l", "--language", default=None,
        help="Force a language code (e.g. en). Default: auto-detect.",
    )
    parser.add_argument(
        "--device", default="cpu", help="cpu or cuda (default: cpu)",
    )
    parser.add_argument(
        "--compute-type", default="int8",
        help="ctranslate2 compute type, e.g. int8, int8_float16, float16 (default: int8)",
    )
    parser.add_argument(
        "--timestamps", action="store_true",
        help="Also write a timestamped version of the transcript.",
    )
    parser.add_argument(
        "--keep-audio", action="store_true",
        help="Keep the downloaded audio file next to the transcript.",
    )
    parser.add_argument(
        "--skip-existing", action="store_true",
        help="Skip a video if its transcript .txt already exists (useful for resuming a batch).",
    )
    parser.add_argument(
        "--insecure", action="store_true",
        help="Disable TLS certificate verification for downloads (yt-dlp nocheckcertificate). "
             "Only for trusted hosts whose cert isn't in yt-dlp's bundle; never needed for YouTube.",
    )
    args = parser.parse_args()

    configure_system_certs()

    from faster_whisper import WhisperModel

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[1/3] Loading Whisper model '{args.model}' ({args.device}, {args.compute_type})...")
    model = WhisperModel(args.model, device=args.device, compute_type=args.compute_type)

    failures: list[str] = []
    for u_idx, url in enumerate(args.url, 1):
        with tempfile.TemporaryDirectory() as td:
            tmpdir = Path(td)
            print(f"[2/3] ({u_idx}/{len(args.url)}) Downloading audio from: {url}")
            items = download_audio(url, tmpdir, insecure=args.insecure)
            if not items:
                print(f"ERROR: No audio could be downloaded from: {url}", file=sys.stderr)
                failures.append(url)
                continue

            print(f"      {len(items)} item(s) from this URL.")
            for i, item in enumerate(items, 1):
                stem = sanitize_filename(item["title"])
                txt_path = out_dir / f"{stem}.txt"

                if args.skip_existing and txt_path.exists():
                    print(f"      SKIP (exists): {txt_path}")
                    continue

                print(f"[3/3] ({i}/{len(items)}) Transcribing: {item['title']}")
                full_text, segs, info = transcribe_file(model, item["path"], args.language)

                header = (
                    f"Title: {item['title']}\n"
                    f"Video ID: {item['id']}\n"
                    f"Detected language: {getattr(info, 'language', '?')}\n"
                    f"{'-' * 60}\n\n"
                )
                txt_path.write_text(header + full_text + "\n", encoding="utf-8")
                print(f"      -> {txt_path}")

                if args.timestamps:
                    ts_path = out_dir / f"{stem}.timestamps.txt"
                    lines = [
                        f"[{format_timestamp(s.start)} -> {format_timestamp(s.end)}] {s.text.strip()}"
                        for s in segs
                    ]
                    ts_path.write_text(header + "\n".join(lines) + "\n", encoding="utf-8")
                    print(f"      -> {ts_path}")

                if args.keep_audio:
                    kept = out_dir / f"{stem}{item['path'].suffix}"
                    kept.write_bytes(item["path"].read_bytes())
                    print(f"      -> {kept}")

    if failures:
        print(f"Done with {len(failures)} failed URL(s):", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
