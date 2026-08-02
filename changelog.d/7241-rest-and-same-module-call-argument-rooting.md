### Fixed

- **`codegen`: the rest-argument and same-module direct-call paths now root
  their arguments too** (#7154). #7240 fixed `lower_call/extern_func.rs`'s
  cross-module NON-rest arm and named two siblings it would not ship
  unmeasured. These are those two, each with a gap test that is a hard fault on
  the parent.

  **`extern_func.rs`'s `has_rest` arm** had *two* unprotected registers where
  the non-rest arm had one. The fixed parameters, as before — except their
  window does not close when the last argument is lowered, because the rest
  array is materialized afterwards and materializing it runs `js_array_alloc`
  plus one `js_array_push_f64` per trailing argument. And the **accumulator**,
  which has no analogue in the non-rest arm: `current` is a raw
  `*mut ArrayHeader` in a bare SSA register, threaded through the push loop,
  holding the only reference to every argument pushed so far while the next
  argument's expression is lowered. Nothing rooted it, so a minor landing in
  that window was free to *sweep* the array, not merely move it.
  `temp_root::rooted_array_begin` has named this exact shape as "the shape
  behind every variadic / spread / rest argument list" since #6951 and
  `console_promise.rs` has used it since; this path never adopted it.

  **`func_ref.rs`'s same-module arms** — all four — had the identical defect.
  #7240's regression test needed a two-file fixture precisely because a
  same-file callee does not reach `extern_func.rs` at all: it resolves through
  `Expr::FuncRef(fid)` into `func_ref.rs`, so the bug sat one `else` away,
  unreached by that PR's test. This was not folded into #7240 because
  `func_ref.rs` threads its lowered arguments through four specialized-ABI
  dispatch paths, each a fast/fallback diamond with a phi at the merge; the
  temp-root release has to sit in the merge block that post-dominates all five
  call sites, since releasing on one side of a diamond leaves the other side's
  call reading dropped slots.

  All five arms now share one `lower_call/mod.rs` helper rather than five
  copies of the same three mistakes. Each argument is still gated by
  `temp_root::operand_protection`, so a list of scalars emits the IR it emitted
  before.

### Changed

- **`scripts/gc_root_dominance_check.py` models a load of a string-literal
  handle global as a heap-value source** (#7154). `--stale-registers`
  classified a source as an `ALLOC_RE` call or a shadow-slot load; a
  `load double, ptr @…_.str.N.handle` is neither, so the register it defines
  was never tracked and no stale use could be attributed to it. That is the
  blind spot #7240 shipped its fix through — over #7240's own gap test the
  checker reported 24 `--moving-only` stale uses at the offending call and
  named neither of the two literals that actually faulted.

  The pattern already existed: `--unrooted-allocas` had `REWRITTEN_LOAD_RE` and
  used it, while `--stale-registers` had only `GLOBAL_ROOT_RE` and knew about
  `@perry_global_*` alone. **The two modes disagreed about what a
  collector-rewritten load is, and the narrower one was wrong.** There is now
  one definition and both modes read it. Unlike #7226's `js_implicit_this_set`
  and #7227's `js_regexp_new`, this could not be closed by adding a name to
  `ALLOC_RE` — the source is a `load`, not a `call`.

  Strictly additive by construction: `GLOBAL_ROOT_RE` is still consulted first,
  so no previously reported source changes kind. Over the 133-module corpus the
  raw count moves 2779 → 4599 (+1820 `source=strhandle`), `--moving-only` — the
  mode `gc-root-dominance.yml` gates on — is **unchanged at 62**, and the gate
  itself still exits 0 with 0 violations and 40/40 seeded violations caught.
  `--self-test` asserts the new source in both directions and under
  `--moving-only`, so the widening cannot silently stop working.
