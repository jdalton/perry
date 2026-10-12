The final `node-suite` parity check could return success when ordinary passing cases kept the aggregate above 80%, even though the same journal contained compile, crash/timeout, or Node-oracle failures. This change makes any of those three status counters fatal for `node-suite`, regardless of the percentage, while preserving the existing threshold for ordinary parity failures.

The runner uses its existing journal-derived counters and still writes the report before returning a failure. Interrupted-run handling, empty-run failure, skipped cases, and other suite policies remain unchanged. The shared verdict seam has offline regression coverage, including a resumed mock harness run that verifies the report is emitted before the fatal result.

This is a partial repair for #9202. It addresses the final node-suite verdict only; it does not fix the other historical failures, macOS behavior, or the issue's broader baseline and percentage-reporting concerns.

Validation at `073131fc900ac2e769cdd9a171d506b9df3b107b`:

- Verdict self-test, including high-parity compile/crash/Node failures, clean/skipped cases, the 80% boundary, empty runs, non-node-suite behavior, and a resumed harness journal: pass.
- Shell syntax checks for the runner, verdict helper, and affected test scripts: pass.
- `tests/test_parity_compile_budget.sh`: pass.
- `git diff --check HEAD^ HEAD`: pass.
- `tests/test_parity_build_reuse.sh`: partial. Its reuse checks and Windows timeout case pass, then its unrelated gap-wrapper fixture fails because `.node-version` is not copied into the temporary tree. The same failure was reproduced at exact base `243bdd7abbf5f81034ad29b4a05f6fc2946492a4`; no Cargo or full-lint run was performed.
