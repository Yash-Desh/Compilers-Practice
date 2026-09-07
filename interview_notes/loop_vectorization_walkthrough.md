# Loop Vectorization — Interview Walk-through

A compiler interview question worked end to end: read the optimized LLVM IR of a
ReLU-style loop, explain every basic block, work out why the compiler vectorized
the arithmetic but not the store, and find the fixes.

## Files in this directory

| File | What it is |
|---|---|
| `loop.cpp` | The original question |
| `loop_O0.ll` | Unoptimized IR — allocas, no SSA promotion |
| `loop_O3.ll` | Optimized IR from local clang 18 |
| `loop_interviewer.ll` | The IR shown in the interview (newer LLVM, Godbolt-filtered) |
| `optimized_loop.cpp` | The fixed source |
| `optimized_loop.ll` | Optimized IR of the fix — stores fully vectorized |

---

## 1. The question

```cpp
void foo1(float* a, int n) {
    for (int i = 0; i < n; i++) {
        if (a[i] < 0.0f) {
            a[i] = 0.0f;
        }
    }
}
```

Clamp negatives to zero, in place. A ReLU.

---

## 2. Generating and reading the IR

Godbolt's LLVM IR pane runs the **full optimization pipeline**. Without an `-O`
flag you get `-O0` IR, which is a literal transcription of the C with allocas
everywhere and no vectorization at all.

```bash
clang++ -O3 -S -emit-llvm -fno-discard-value-names -g0 loop.cpp -o loop_O3.ll
```

| Flag | Why |
|---|---|
| `-O3` | run the optimizer — without it there is nothing to look at |
| `-S` | stop after compile; don't assemble or link |
| `-emit-llvm` | emit LLVM IR instead of target assembly |
| `-fno-discard-value-names` | keep `%a`, `%n`, `vector.body` instead of `%0`, `%1`, `9:` |
| `-g0` | drop debug info |

`-S` vs `-c` decides the *encoding*, `-emit-llvm` decides the *language*:

|  | `-S` | `-c` |
|---|---|---|
| default | `.s` (x86 asm text) | `.o` (object) |
| `-emit-llvm` | `.ll` (IR text) | `.bc` (bitcode) |

### Matching Godbolt's presentation exactly

```bash
clang++ -O3 -S -emit-llvm -fno-discard-value-names -g0 loop.cpp -o - \
 | c++filt \
 | sed -E '/^; ModuleID/d; /^source_filename/d; /^target /d;
           /^; Function Attrs:/d; /^attributes #/d;
           /^![A-Za-z0-9._]+ = /d; /^!llvm\./d;
           s/, !tbaa ![0-9]+//g; s/, !llvm\.loop ![0-9]+//g;
           s/ #[0-9]+ \{/ {/; s/[[:space:]]*; preds = .*$//' \
 | cat -s > out.ll
```

Each stage corresponds to one of Godbolt's IR-pane checkboxes: demangle symbols,
filter IR metadata, filter attributes, filter comments.

### Why `loop_O3.ll` and `loop_interviewer.ll` differ

They are the **same optimization outcome** — 26 basic blocks each, same block
names in the same order, same VF, same UF, same predication strategy. Every
difference is cosmetic or LLVM-version:

| Difference | Interviewer's | Local clang 18 | Cause |
|---|---|---|---|
| `@foo1(float*, int)` | demangled | `@_Z4foo1Pfi` | `c++filt` / Godbolt's demangle filter |
| `captures(none)` | newer spelling | `nocapture` | attribute respelled in the LLVM 20/21 era |
| `getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index` | byte-offset GEP | `getelementptr inbounds float, …` | GEP→ptradd canonicalization in newer LLVM |
| no `!tbaa`, no `attributes #0` | stripped | present | Godbolt filters |

To reproduce exactly, install a newer clang (`clang-20` is in the stock Ubuntu
repos; apt.llvm.org for 21+). Neither change affects vectorization — only
printing.

### Inspecting *why* a loop did or didn't vectorize

```bash
# optimization remarks — the single most useful debugging tool here
clang++ -O3 -Rpass=loop-vectorize -Rpass-missed=loop-vectorize \
        -Rpass-analysis=loop-vectorize -c loop.cpp -o /dev/null

# run individual passes by hand
clang++ -O0 -S -emit-llvm -Xclang -disable-O0-optnone loop.cpp -o o0.ll
opt -passes='mem2reg,loop-simplify,lcssa,loop-vectorize' -S o0.ll -o vec.ll

# watch the IR mutate
opt -passes='default<O3>' -print-after=loop-vectorize -S o0.ll -o /dev/null
```

`-disable-O0-optnone` is required — clang marks `-O0` functions `optnone` and
`opt` will otherwise refuse to touch them.

### Syntax highlighting

- **VS Code:** install `colejcummins.llvm-syntax-highlighting` from the
  Extensions pane. Installing via `code --install-extension` from inside WSL
  fails, because it targets the remote side and LLVM grammars are UI-only
  extensions.
- **Terminal:** Pygments has an `LlvmLexer` —
  `pygmentize -l llvm -f terminal16m -O style=monokai file.ll | less -R`.
  Caveat: it flags newer keywords like `disjoint` and `nneg` as errors.
- **Vim:** `llvm/utils/vim/syntax/llvm.vim` from the LLVM repo; it is generated
  from LLVM's own keyword lists, so it's the most accurate of the three.

---

## 3. The CFG

```
entry  (n > 0 ?)
  ├── false ─────────────────────────────────► for.cond.cleanup (ret void)
  └── true ──► for.body.preheader (n < 8 ?)
                 ├── true  ──────────────────► for.body.preheader26
                 └── false ──► vector.ph ──► vector.body ──► middle.block
                                                  ▲   │           │ n.vec == n ?
                                                  └───┘           ├── true ──► for.cond.cleanup
                                                                  └── false ─► for.body.preheader26
                                                                                    │
                                                                                for.body  (scalar epilogue)
```

Two guards, stacked: `entry` asks *is there any work?*, `for.body.preheader`
asks *is there enough work to be worth vectorizing?*

---

## 4. Block by block

### `entry` — the loop guard

```llvm
entry:
  %cmp8 = icmp sgt i32 %n, 0
  br i1 %cmp8, label %for.body.preheader, label %for.cond.cleanup
```

- The function's unique entry block: no predecessors, illegal to branch to,
  therefore can never hold a `phi`. Conventional home for `alloca`s — note
  there are none, because `mem2reg` promoted `i` to an SSA register. Compare
  `loop_O0.ll`, where `%3 = alloca ptr` / `%4 = alloca i32` / `%5 = alloca i32`
  are the slots for `a`, `n`, `i`.
- `sgt` because `int` is signed. Signed overflow is UB, so LLVM knows `i` can't
  wrap — that's what licenses the `nneg` flag in the next block.
- Source says `i < n` with `i = 0`; LLVM canonicalizes constants to the
  right-hand operand, giving `n > 0`.
- The `8` in `%cmp8` is meaningless — SSA uniquing of clang's name `cmp`.

**Why this block exists: loop rotation.** `loop-rotate` converts

```c
for (int i = 0; i < n; i++) { body; }
```

into

```c
if (n > 0) { int i = 0; do { body; i++; } while (i < n); }
```

so the loop ends with the back-edge test instead of starting with a test plus a
jump. The rotation also creates a **preheader** — a block that dominates the
loop and runs exactly once — which is a prerequisite for vectorization.

### `for.body.preheader` — the vector/scalar dispatch

```llvm
for.body.preheader:
  %wide.trip.count = zext nneg i32 %n to i64
  %min.iters.check = icmp ult i32 %n, 8
  br i1 %min.iters.check, label %for.body.preheader26, label %vector.ph
```

- **`zext nneg … to i64`** widens the trip count so `IndVarSimplify` can promote
  the induction variable to pointer width. Without it every GEP inside the loop
  would need a `sext i32 → i64` on every iteration.
- **`nneg`** = "proven non-negative", trivially true on this path. Once
  non-negativity is known, `zext` and `sext` coincide and LLVM canonicalizes to
  `zext`; the flag preserves the proof. It is poison-generating — a negative
  value would make the result `poison`.
- **`icmp ult i32 %n, 8`** is the *minimum-iteration check*. **`8 = VF × UF`**
  — see §5. If fewer than 8 elements remain, the vector body cannot complete
  even one iteration, so take the scalar path.
- `ult` (unsigned) on a signed `int`: legal because `n > 0` is already known,
  and LLVM canonicalizes to unsigned whenever non-negativity is provable.
- Branch polarity: **true means "too small"**.
- `%wide.trip.count` must live *here*, not in `vector.ph`, because both paths
  use it and SSA requires the definition to dominate all uses.
- **Conspicuously absent: runtime alias checks.** With two pointers this block
  would also test that the ranges don't overlap. One pointer ⇒ nothing to
  disprove.

### `vector.ph` — the vector loop's preheader

```llvm
vector.ph:
  %n.vec = and i64 %wide.trip.count, 2147483640
  br label %vector.body
```

- Rounds the trip count **down to a multiple of 8**. `2147483640` = `0x7FFFFFF8`
  — clearing the low 3 bits is `x - (x % 8)`, one cheap `and`. This only works
  because 8 is a power of two, which is why VF and UF always are.
- Why `0x7FFFFFF8` rather than `~7`? `%wide.trip.count` came from a
  `zext nneg i32`, so `computeKnownBits` proves bits 31–63 are already zero and
  InstCombine drops them from the mask. The constant is a record of what the
  compiler knows about the value's range.

  | `n` | `%n.vec` | vector covers | epilogue |
  |---|---|---|---|
  | 8 | 8 | 0–7 | 0 |
  | 100 | 96 | 0–95 | 4 |
  | 101 | 96 | 0–95 | 5 |

- The branch is **unconditional**: `n >= 8` was already established, so
  `%n.vec >= 8` and the rotated do-while loop provably runs at least once.
- `%n.vec` is used in three places — the back-edge test, `middle.block`'s
  `%cmp.n`, and the epilogue's start-index phi.
- In a bigger loop this block also holds broadcasts of invariants, reduction
  identity vectors, and runtime alias checks. Here the compared-against `0.0f`
  folds to `zeroinitializer`, so nothing needs broadcasting.

### `vector.body` — the loop header

```llvm
vector.body:
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %pred.store.continue25 ]
  %0 = getelementptr inbounds nuw [4 x i8], ptr %a, i64 %index
  %1 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %wide.load   = load <4 x float>, ptr %0, align 4
  %wide.load11 = load <4 x float>, ptr %1, align 4
  %2 = fcmp olt <4 x float> %wide.load,   zeroinitializer
  %3 = fcmp olt <4 x float> %wide.load11, zeroinitializer
  %4 = extractelement <4 x i1> %2, i64 0
  br i1 %4, label %pred.store.if, label %pred.store.continue
```

This is the **header**, not the whole body — one logical vector iteration spans
17 blocks, `vector.body` through `pred.store.continue25`.

- **`phi`** has one `[value, predecessor]` pair per incoming edge: `0` from the
  preheader, `%index.next` from the **latch** `pred.store.continue25`. The fact
  that the back-edge comes from a different block is the tell that the body is
  multi-block. `%index` counts *elements* and steps by 8.
- **`[4 x i8]` GEP** is modern LLVM's spelling. Since opaque pointers, the
  element type is purely a scaling factor, so GEPs canonicalize toward byte-array
  forms. `[4 x i8]` = scale by 4 bytes, identical to `float` in clang 18's
  output. `inbounds` = result stays inside the object or is `poison`;
  `nuw` = the byte offset doesn't unsigned-wrap.
- `%1` chains off `%0` (+16 bytes = 4 floats) rather than recomputing from `%a`
  — a plain pointer-add that folds into an x86 addressing mode.
- **`align 4`, not `align 16`**: a `float*` only guarantees 4-byte alignment.
  `a = __builtin_assume_aligned(a, 16)` bumps it — a good experiment to diff.
- **The loads are unconditional and that's fine**: the source reads `a[i]`
  unconditionally too (it *is* the `if` condition), and all 8 elements are in
  bounds because `%n.vec` is a multiple of 8 and `<= n`.
- **`olt` = ordered less-than**, false if either operand is NaN — exactly C's
  `<`, since `NaN < 0.0f` is false. `ult` (unordered) would be wrong. Whenever
  you see `o*` vs `u*`, that's the NaN question.
- Both compares are computed **before any store**: all 8 mask bits are
  materialized up front, then consumed one at a time down the ladder.

The block splits cleanly in two:

```
unconditional, vectorized:   index, GEPs, 2 loads, 2 compares
─────────────────────────────────────────────────────────────
scalarized, branchy:         extractelement lane 0 → br
```

Everything that *could* stay in vector form did. The moment it hits an operation
with no vector encoding on this target — the conditional store — it falls off a
cliff into per-lane branching.

### `middle.block`, the epilogue, and the exit

- `middle.block`: `%cmp.n = icmp eq i64 %n.vec, %wide.trip.count` — was `n` a
  clean multiple of 8? If yes, skip the epilogue entirely.
- `for.body.preheader26`: a phi merging the "too small" path (start at `0`) with
  the "leftover tail" path (start at `%n.vec`). This is the handoff.
- `for.body`: the scalar epilogue, one element per trip, 0–7 trips. It is a
  full duplicate of the loop, and carries `llvm.loop.isvectorized` metadata
  purely so the vectorizer doesn't re-process it.

---

## 5. Why the min-iters check is 8, not 4

```
8  =  VF 4 (elements per <4 x float>)  ×  UF 2 (interleave factor)
```

LLVM calls this **interleaving**, done by the LoopVectorizer's
`selectInterleaveCount` — not by the separate `LoopUnroll` pass, which is why
the vector loop carries `llvm.loop.unroll.runtime.disable`.

Evidence throughout: two `wide.load`s, two `fcmp`s, eight `pred.store` pairs,
`add nuw i64 %index, 8`, and the `0x7FFFFFF8` mask clearing three bits.

Verify by pinning it:

```bash
clang++ -O3 -S -emit-llvm -fno-discard-value-names -g0 \
        -mllvm -force-vector-interleave=1 loop.cpp -o uf1.ll
# → icmp ult i32 %n, 4 ; and i64 …, 2147483644 ; one load ; add …, 4
```

### Why UF = 2 and not more

The benefit saturates while the cost grows linearly.

| UF | overhead share | marginal gain |
|---|---|---|
| 1 | 1 branch / 4 elems | — |
| 2 | 1 / 8 | removes 50% |
| 4 | 1 / 16 | another 25% |
| 8 | 1 / 32 | another 12.5% |

Two independent load→`fcmp` chains already saturate the load ports; a third and
fourth hide nothing.

Meanwhile, in *this* loop each interleave step adds `VF × 2 = 8` basic blocks,
because every predicated store is a branch pair per lane. Measured:

| UF | blocks |
|---|---|
| 1 | 18 |
| 2 | 26 |
| 4 | 42 |
| 8 | 74 |

At UF = 8 that's 64 unpredictable branches per iteration — ruinous for I-cache
and the branch predictor.

**Proof that predication is the binding constraint:** give the target real masked
stores and the same cost model immediately goes further.

| flags | VF | UF | stride | masked store |
|---|---|---|---|---|
| baseline | 4 | 2 | 8 | no |
| `-mavx2` | 8 | 4 | 32 | yes |
| `-mavx512f` | 16 | 4 | 64 | yes |

Other caps: **register pressure** (the cost model refuses a UF that would
spill), **epilogue waste** (UF = 8 means up to 31 elements run scalar and loops
shorter than 32 get no vectorization at all), and **code size** (`-Os` disables
interleaving almost entirely).

---

## 6. The core question: why didn't the stores vectorize?

> Because the store is conditional and baseline SSE2 has no masked store, and
> writing all four lanes unconditionally would be illegal — it would write memory
> the source program never wrote.

**A predicated store** is a store that must only happen for the lanes where the
mask is true. With no hardware masked store, it becomes one branch-guarded
scalar store per lane.

Both halves matter, and a common wrong framing is "the target has no vector
stores" — SSE2 *does* have vector stores, it just lacks **masked** ones.

---

## 7. The proposed fix, and the interviewer's objection

**Proposal:** build a temp vector holding the final value for each lane, then
store it whole. That is a `select`/blend feeding one unconditional
`<4 x float>` store — compute `select(a[i] < 0, 0.0, a[i])` element-wise so the
unchanged lanes are rewritten with the value they already held.

**Correct as a transformation** — it's what `maxps` does. But the *compiler*
can't apply it unilaterally.

**Objection:** the programmer never intended to write elements `>= 0.0f`.
Introducing that write can

- turn a benign race into a real one for a concurrent reader,
- fault on a read-only page,
- dirty cache lines that would otherwise stay clean.

Note it's illegal on **write-visibility** grounds, not on results — the values
are unchanged.

---

## 8. The fix: change the source

If *the programmer* asserts every element is theirs to write, the store becomes
unconditional in the source and the compiler is free.

```cpp
// optimized_loop.cpp
void foo1(float *a, int n) {
    for (int i = 0; i < n; i++) {
        a[i] = (a[i] < 0.0f) ? 0.0f : a[i];
    }
}
```

**26 blocks → 9 blocks.** The entire predicated-store ladder disappears:

```llvm
vector.body:
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  ...
  %4 = select <4 x i1> %2, <4 x float> zeroinitializer, <4 x float> %wide.load
  %5 = select <4 x i1> %3, <4 x float> zeroinitializer, <4 x float> %wide.load15
  store <4 x float> %4, ptr %0, align 4
  store <4 x float> %5, ptr %1, align 4
  %index.next = add nuw i64 %index, 8
```

- The phi's back-edge is now `%vector.body` itself — the vector loop is a
  genuine single-block loop.
- VF and UF are unchanged (still 4 × 2 = 8, same mask). Removing predication
  didn't change the vectorization *decision*, it removed 17 blocks of
  scaffolding.
- The scalar epilogue got the same treatment: `%cond = select i1 …` plus an
  unconditional store, so `if.then` and `for.inc` collapsed away too.

### Use the ternary, not an explicit `else`

Writing `else { a[i] = a[i]; }` **does not work** — measured on clang 18 it
still produces 24 predicated-store blocks, while the ternary produces zero.

The reason is CFG shape, not semantics:

```
ternary                          if-else
  load a[i]                        cond = a[i] < 0
  cond = a[i] < 0                   ╱            ╲
  val = cond ? 0.0 : a[i]     store 0.0      store a[i]
  store val → a[i]                  ╲            ╱
  (always executes)                   (join)
```

The vectorizer's rule is mechanical: *is this store inside a block the branch
may skip?* If yes, some lanes would take that block and some wouldn't, so there
is no single moment when all 4 lanes agree to store — it must be predicated.

The `select` is just arithmetic on a register; it vectorizes as trivially as an
`add`. There is no control flow left to predicate.

**Why doesn't the compiler merge the two stores itself?** It can in principle —
that's if-conversion in SimplifyCFG. But merging *stores* means hoisting a write
out of a conditional block, which is only legal if both sides provably write the
same address. The pass stays conservative, and the vectorizer inherits the
two-block shape.

### The mask doesn't disappear — it changes job

A natural follow-up: does the ternary version avoid producing a per-lane mask?

No. The mask is still right there — `%2 = fcmp olt <4 x float> %wide.load,
zeroinitializer` produces the same `<4 x i1>` in both versions. What changes is
what the mask *feeds*:

| | mask feeds | ISA needs |
|---|---|---|
| `if` version | a **store predicate** — decides *whether to write memory* | a masked store |
| ternary version | a **`select`** — decides *which value sits in a register* | a blend, which every vector ISA has |

> The mask is still there, but it now picks *values* inside a register instead
> of deciding *whether to write memory* — and picking values is something every
> vector ISA can do in one instruction.

Two consequences worth keeping straight:

- **A mask is not inherently serial.** The vectorizer always forms the mask in
  target-independent IR; the cost model then consults the ISA to decide whether
  it lowers to *one* masked instruction or gets **scalarized** into a per-lane
  branch ladder. With `llvm.masked.store` on AVX2 or SVE, all lanes still go in
  a single parallel instruction. The serialization in `loop_interviewer.ll` is
  the scalarization, not the masking.
- **`select` can never scalarize.** There is no target where blending two
  registers under a mask is unavailable, so the ternary version is portable in a
  way the `if` version is not — it vectorizes cleanly on SSE2, NEON, and
  everything above.

> **Rule of thumb for writing vectorizable loops: turn `if` into `select`.**
> Move the branch out of the control flow and into the data. Vector hardware
> handles a branch in the data — that's a blend. It cannot handle a branch in
> the control flow without predication.

---

## 9. The other fix: change the target

Without touching the source and without any illegal write:

```bash
clang++ -O3 -S -emit-llvm -mavx2 loop.cpp -o - | grep masked.store
```

`llvm.masked.store` writes **only** the true lanes — a genuine vector store that
never touches the untouched elements.

This is entirely an **ISA capability**:

| ISA | Masked store? |
|---|---|
| SSE2 | No (only the byte-granular, non-temporal `MASKMOVDQU`) |
| AVX / AVX2 | Yes — `VMASKMOVPS` / `VPMASKMOVD` |
| AVX-512 | Yes, fully general via EVEX write-masks `{k1}` |
| NEON | No |
| SVE / SVE2, MVE | Yes — predication is built into essentially every instruction |

Same IR, same cost model, same pass — a predicated-store ladder for SSE2 and a
clean masked store for AVX2.

---

## 10. Summary of the three options

| Approach | Source change | Legal? | Result |
|---|---|---|---|
| Compiler blends and stores all lanes | none | **No** — introduces a write the source never made | — |
| Ternary / `select` in source | yes | Yes — programmer asserts the write | 26 → 9 blocks, plain `store <4 x float>` |
| Target with masked stores (`-mavx2`) | none | Yes — only true lanes written | `llvm.masked.store`, no ladder |

---

## 11. Loose ends worth exploring

- **`-ffast-math` collapses the whole thing** — relaxing NaN and `-0.0`
  semantics lets it become a branchless `maxps`. The biggest remaining
  experiment.
- **Why it isn't already `fmax`** — `a[i] < 0.0f ? 0.0f : a[i]` differs from
  `fmaxf` on NaN and on `-0.0`, so strict IEEE forbids the rewrite.
- **Tail folding** — `-mllvm -prefer-predicated-vector-loop` masks the final
  iteration instead of emitting a scalar epilogue.
- **Alignment** — `__builtin_assume_aligned(a, 16)` and diff the `align`
  attributes.
- **A second pointer** — add `float* b` and watch runtime alias checks appear in
  `for.body.preheader`; add `restrict` and watch them vanish.
- **Function attributes** — `nofree captures(none) memory(argmem: readwrite)`,
  and what each licenses at the *caller's* side.
- **GCC vs LLVM** — compile the same source with `gcc -O3 -S` and compare
  vectorization strategy.
- **Dataflow practice** — the 26-block CFG is a real worked example for the
  dominator and liveness code in `cornell_cs6120/L4_Data_Flow/`.

---

## 12. Interview-ready one-liners

- **Side effect:** any observable change to state outside producing the
  instruction's result — writing memory, I/O, trapping — which is what makes an
  instruction unsafe to delete, duplicate, or reorder.
- **Terminator:** every LLVM basic block must end in exactly one (`br`, `ret`,
  `switch`, `unreachable`, `invoke`, …); the verifier rejects anything else.
- **Predicated store:** a store that must only happen for the lanes where the
  mask is true.
- **Why the stores didn't vectorize:** the store is conditional, SSE2 has no
  masked store, and writing all lanes unconditionally would write memory the
  source never wrote.
- **The fix:** turn the `if` into a `select` so the store becomes unconditional
  in the source — or compile for a target that has masked stores.
- **Masking vs scalarizing:** the vectorizer always forms the per-lane mask in
  target-independent IR; the ISA decides whether it becomes one masked
  instruction or a serial per-lane branch ladder. A mask is not inherently
  serial.
- **Why the ternary is different:** it still produces the same `<4 x i1>` mask,
  but the mask now picks *values* inside a register instead of deciding
  *whether to write memory* — and every vector ISA can do that in one
  instruction.
