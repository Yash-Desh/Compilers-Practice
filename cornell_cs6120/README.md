# Cornell CS 6120 — Advanced Compilers

Transcripts of Adrian Sampson's **CS 6120: Advanced Compilers** lecture videos,
hosted on [Cornell Video on Demand](https://vod.video.cornell.edu/).

**19 videos across 13 lessons · ~9 h 17 m total watch time · ~100,400 words transcribed**

This is the complete set: it matches all 19 videos listed on the
[official self-guided course page](https://www.cs.cornell.edu/courses/cs6120/2020fa/self-guided/).

## Layout

One directory per lesson, named `L<number>_<lesson title>` after the official
course lesson titles:

```
L1_Welcome_Overview/            L8_Interprocedural_Analysis/
L2_Representing_Programs/       L9_Alias_Analysis/
L3_Local_Analysis_Optimization/ L10_Memory_Management/
L4_Data_Flow/                   L11_Dynamic_Compilers/
L5_Global_Analysis_SSA/         L12_Program_Synthesis/
L6_LLVM/                        L13_Concurrency_Parallelism/
L7_Loop_Optimization/
```

A lesson directory holds every video for that lesson, plus any supplementary
reading for it (e.g. `L4_Data_Flow` also carries two data flow analysis PDFs).

Each video has two files:

- `<name>.txt` — clean raw transcript (single flowing text)
- `<name>.timestamps.txt` — same content with `[HH:MM:SS -> HH:MM:SS]` markers per
  segment, for jumping back to a specific point in the video

## Videos

| Lesson directory | Video (click to watch) | Length | Transcript |
|:---|:---|---:|:---|
| `L1_Welcome_Overview` | [Lesson 1 — Introduction](https://vod.video.cornell.edu/media/0_bug89uok) | 27:34 | `CS_6120_Lesson_1` |
| `L2_Representing_Programs` | [Representing Programs](https://vod.video.cornell.edu/media/1_vnx6laq9) | 31:31 | `CS_6120_Lesson_2_Representing_Programs` |
| `L2_Representing_Programs` | [Introduction to Bril](https://vod.video.cornell.edu/media/1_jc91ke0h) | 45:01 | `CS_6120_Lesson_2_Introduction_to_Bril` |
| `L3_Local_Analysis_Optimization` | [Local Optimization & Dead Code Elimination](https://vod.video.cornell.edu/media/1_6k52flbg) | 24:11 | `CS_6120_Lesson_3_Local_Optimization_Dead_Code_Elimination` |
| `L3_Local_Analysis_Optimization` | [Local Value Numbering](https://vod.video.cornell.edu/media/1_i2gnhw41) | 42:41 | `CS_6120_Lesson_3_Local_Value_Numbering` |
| `L4_Data_Flow` | [Data Flow](https://vod.video.cornell.edu/media/1_72tqupsb) | 40:38 | `CS_6120_Lesson_4_Data_Flow` |
| `L4_Data_Flow` | [Implementation Task](https://vod.video.cornell.edu/media/1_mjy6lamo) | 4:26 | `CS_6120_Lesson_4_Implementation_Task` |
| `L5_Global_Analysis_SSA` | [Global Analysis & Optimization](https://vod.video.cornell.edu/media/1_i5apfx6t) | 42:03 | `CS_6120_Lesson_5_Global_Analysis_Optimization` |
| `L5_Global_Analysis_SSA` | [Static Single Assignment](https://vod.video.cornell.edu/media/1_130pq2fh) | 28:21 | `CS_6120_Lesson_5_Static_Single_Assignment` |
| `L6_LLVM` | [Introduction to LLVM](https://vod.video.cornell.edu/media/1_f231lwkz) | 8:24 | `CS_6120_Lesson_6_Introduction_to_LLVM` |
| `L6_LLVM` | [Writing an LLVM Pass](https://vod.video.cornell.edu/media/1_4nrtmvc9) | 30:12 | `CS_6120_Lesson_6_Writing_an_LLVM_Pass` |
| `L7_Loop_Optimization` | [Loop Optimization](https://vod.video.cornell.edu/media/1_2shcxd1h) (see note) | 19:35 | `CS_6120_Lesson_7_Interprocedural_Analysis` |
| `L8_Interprocedural_Analysis` | [Interprocedural Analysis](https://vod.video.cornell.edu/media/1_9csov2la) | 25:55 | `CS_6120_Lesson_8_Interprocedural_Analysis` |
| `L9_Alias_Analysis` | [Alias Analysis](https://vod.video.cornell.edu/media/1_7ngps985) | 23:05 | `CS_6120_Lesson_9_Alias_Analysis` |
| `L10_Memory_Management` | [Memory Management](https://vod.video.cornell.edu/media/1_21p8mjsw) | 47:21 | `CS_6120_Lesson_10_Memory_Management` |
| `L11_Dynamic_Compilers` | [Dynamic Compilers](https://vod.video.cornell.edu/media/1_ltb1t94i) | 29:53 | `CS_6120_Lesson_11_Dynamic_Compilers` |
| `L11_Dynamic_Compilers` | [Tracing via Speculation](https://vod.video.cornell.edu/media/1_nk1o4hzm) | 13:19 | `CS_6120_Lesson_11_Tracing_via_Speculation` |
| `L12_Program_Synthesis` | [Program Synthesis](https://vod.video.cornell.edu/media/1_mxclvd8z) | 35:03 | `CS_6120_Lesson_12_Program_Synthesis` |
| `L13_Concurrency_Parallelism` | [Concurrency & Parallelism](https://vod.video.cornell.edu/media/1_8cpusna2) | 37:56 | `CS_6120_Lesson_13_Concurrency_Parallelism` |

### Note on Lesson 7

Cornell's page titles this video "Lesson 7: Interprocedural Analysis", but the
content is actually about **loop optimization** — natural loops, loop-invariant
code motion, and related transformations. The genuine interprocedural analysis
lecture is Lesson 8. The directory follows the official lesson title
(`L7_Loop_Optimization`); the filename inside still follows Cornell's video title.

## Lessons with two videos

Six lessons (2, 3, 4, 5, 6, 11) are split across two videos. The split is by
sub-topic rather than a fixed theory/exercise structure, though when a lesson has
an assignment or tooling component it usually gets its own video:

- **Lesson 2** — concepts (Representing Programs), then hands-on tooling (Bril)
- **Lesson 3** — two techniques: dead code elimination, then local value numbering
- **Lesson 4** — the data flow lecture, then a short video stating the task
- **Lesson 5** — two conceptual topics: global analysis, then SSA
- **Lesson 6** — LLVM overview, then a hands-on pass-writing walkthrough
- **Lesson 11** — JIT landscape overview, then the trace-optimizer task

## How these were produced

Generated locally with OpenAI Whisper (`medium` model, CPU) via `faster-whisper`,
using the `yt-transcribe` tool in this workspace. Audio was fetched with `yt-dlp`.
Transcript coverage was verified against each video's true duration — all files
cover 98–99% of their video (the small remainder is trailing music/silence).
