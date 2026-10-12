fix(timer): limit freed-range cleanup to the primary partition
Refs #12145

Thread-exit cleanup scans only the existing `PRIMARY_AGENT` timer partition. Worker partitions remain owned by `retire_agent`; the freed-range predicate and poison recovery are preserved, primary counters are republished after removals, and removed entries are dropped after releasing the store lock.

The tests check exact primary counter transitions from 2 to 1 to 0 while worker entries remain untouched. A production-path integration witness exercises helper-thread arena exit and a surviving main-thread timer. At the consolidated head, the fresh build trio, 37 focused controls, and production witness pass.

This is a partial #12145 repair. The separate callback-loss behavior described in the issue remains open: this change does not prevent a primary-reachable callback allocated in a helper arena from being discarded at thread exit. No performance measurement is claimed. Validation is Linux-only; macOS behavior is unverified.

Validation at `4a24802a4b90bd897a5bbea9615d5fce9acc39ed` (one commit directly on `d3e535944edbe7f7cf858c9ec932da355a7de26b`):

- Fresh debug build trio (`perry`, `perry-runtime-static`, `perry-stdlib-static`): pass.
- Focused timer/store, inline-timer, agent, and thread-exit membership controls: 37/37 pass.
- Production helper-thread exit integration witness: 1/1 pass.
- `rustfmt` and `git diff --check`: pass.
- The earlier release compiler build passed at prior head `2e094d796cf675911cbc5fce87a55bf7128adfdb`; it was not rerun at this consolidated head. Full lint remains incomplete; no green full-lint claim is made.
