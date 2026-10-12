fix(timer): limit freed-range cleanup to the primary partition
Refs #12145

Thread-exit cleanup scans only the existing `PRIMARY_AGENT` timer partition. Worker partitions remain owned by `retire_agent`; the freed-range predicate and poison recovery are preserved, primary counters are republished after removals, and removed entries are dropped after releasing the store lock.

The tests check exact primary counter transitions from 2 to 1 to 0 while worker entries remain untouched. A production-path integration witness exercises a helper-thread arena exit and a surviving main-thread timer. The verifier reports that all 37 focused controls and the production thread-exit witness pass at the current head.

This is a partial #12145 repair. The separate callback-loss behavior described in the issue remains open: this change does not prevent a primary-reachable callback allocated in a helper arena from being discarded at thread exit. No performance measurement is claimed. Validation is Linux-only; macOS behavior is unverified.

Validation at `2e094d796cf675911cbc5fce87a55bf7128adfdb`:

- Fresh candidate build trio: pass (verifier report; approximately 1m50s).
- Exact-head release compiler build (`cargo build --locked --release -p perry`): pass. API-doc generation/drift was not run.
- Pinned `rustfmt --check` and `git diff --check`: pass.
- Focused controls: 37/37 passed; production thread-exit witness: 1/1 passed at the exact head.
- The delimiter-only change keeps the four `PRIMARY_*` counters inside the `per_test_global!` block recognized by the isolation checker. Exact-base A/B removed those four candidate-only findings; the check still fails on the same 12 bare-global findings at the base.
- The earlier full lint at `22726d3c2dc7c05db6fd1ef997326accb1f46b29` timed out at 13:50:22 UTC after 104 passing steps, 31 failures, and 2 skips; its release/API-doc step was interrupted. The fresh full-lint run for this head hit its 30-minute cap at 14:56:21 UTC (exit 124) during the API release build. The last completed gate was Auto-optimize pruned feature builds; the API release build did not finish, and the driver emitted no footer or final gate total. Rustc/Clippy diagnostics in the retained log are clipped and remain unclassified; the Clippy fatal diagnostic is unresolved, and a tail warning is not treated as its fingerprint. No baseline-green claim is made. Full lint remains incomplete.

The complete provisional static comparison is in `static-failure-attribution.json`.
