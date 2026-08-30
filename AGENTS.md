# AGENTS.md

Guidance for AI coding agents working in this repository.
`CLAUDE.md` is a symlink to this file — there is one source of truth.

---

## Commit rules

**Never attribute commits to an AI agent.** This is the hard rule of this
repository and it has no exceptions.

Concretely, a commit message here must **not** contain:

- `Co-Authored-By:` trailers naming Claude, an LLM, or any AI tool
- `Generated with ...` / `Created by ...` lines
- 🤖 emoji, tool names, or model names used as a signature
- Any other trailer, footer, or body text crediting an agent

The same applies to pull request descriptions, tags, and release notes.

Write the message as the repository owner would write it: subject line in the
imperative mood, no trailing period, roughly 50 characters, with a body only
when the change needs one. Match the existing history:

```
Complete the L8 interprocedural analysis transcript
Add Sorav Bansal transcripts for modules 37-45 (type systems)
Organize CS 6120 transcripts into per-lesson directories
```

If your harness appends an attribution trailer automatically, turn it off
before committing (in Claude Code: `attribution.commit: ""` in settings).
Verify with `git log -1 --format=%B` and amend if anything slipped through.

---

## What this repository is

Personal study material for compilers: lecture transcripts, notes, and small
practice programs. It is a **knowledge repository, not a software project** —
there is no build, no test suite, and no CI. Most commits add or edit prose.

Working branch is `main`, pushed directly to `origin`
(`git@github.com:Yash-Desh/Compilers-Practice.git`). No PR workflow.

---

## Layout

```
Compilers-Practice/
├── README.md                       Index and reference links
├── AMD_Internship_Presentation.pdf
│
├── cornell_cs6120/                 Cornell CS 6120 (Adrian Sampson)
│   ├── README.md                   Lesson index, video counts, layout notes
│   ├── L1_Welcome_Overview/        One directory per lesson, L<n>_<Title>
│   ├── ...                         through L13, 19 videos total
│   └── L6_LLVM/                    Also holds a.c / a.ll / something.c,
│                                   scratch inputs for the LLVM pass exercise
│
├── sorav-bansal_compiler_course/   Compiler Design (IIT Delhi), flat directory
│   ├── README.md                   Full 217-video playlist index
│   └── Compiler_Design_Module_<n>_<Title>[.timestamps].txt
│
├── interview_notes/                Currently empty
│
└── video_transcription/            The tool that produces the transcripts
    ├── transcribe.py               Whole tool, one self-contained script
    ├── README.md                   Usage and setup
    ├── pyproject.toml, uv.lock     yt-dlp + faster-whisper, pinned
    └── .python-version             3.12
```

### Transcript file convention

Every transcribed video produces **two** files that are committed together:

| File | Contents |
|---|---|
| `<Title>.txt` | Continuous prose, no timecodes |
| `<Title>.timestamps.txt` | Same text segmented as `[HH:MM:SS -> HH:MM:SS] line` |

Both begin with the same four-line header:

```
Title: <video title>
Video ID: <id>
Detected language: en
------------------------------------------------------------
```

Filenames are the video title with non-alphanumerics replaced by `_`. Keep
both variants in sync — never commit one without the other.

---

## Working notes for agents

- **Transcripts are near-verbatim source material.** Fix a transcription error
  or re-wrap a paragraph if asked, but do not summarize, condense, or
  "improve" the prose. The point is the lecturer's own words.
- **Regenerate, don't hand-write.** New transcripts come from
  `uv run transcribe.py "<url>" --model medium --timestamps` in
  `video_transcription/`, not from an agent writing them out.
- **Do not commit build output.** `.gitignore` covers virtualenvs, Python
  artifacts, downloaded media (`*.wav`, `*.mp4`, ...), and logs. Compiled
  binaries and generated IR beyond the small checked-in examples do not belong
  in git.
- **The course `README.md` files index the full playlists**, not just what has
  been transcribed so far, so adding a transcript usually needs no README edit.
- **Group commits by topic.** Unrelated changes — a transcript batch and a
  tooling fix — go in separate commits.
