The workspace architecture audit stored member and decision totals alongside the Cargo metadata and crate classifications it already checks. Removing an unrelated member therefore required editing redundant aggregate values, even when the exact dependency closures were unchanged.

This partial #10739 repair moves the policy to schema 2, removes those stored totals, and keeps the exact default and `perry` dependency closures as structural checks. The checker rejects schema 1 and any unexpected baseline fields. The contributor guide documents the migration. This addresses derived workspace counts only; it does not close the broader issue.

Validation at `1ce48b9d067c02456d49fe2257c184ba6b26e71e`:

- All 18 checker self-tests pass, including two independent removals in both orders, combined removals, and rejection of unclassified additions, stale entries, forbidden closure changes and structural-edge changes. Python compilation, the real Cargo metadata audit (68 members, two default members, closures 25/24), and diff checks pass.
- The required full lint driver completed: **32 of 137 commands failed; two CI-only checks skipped**. Both workspace architecture checks pass. This is not a green full-lint result.
- Thirty failures are baseline-attributed: 19 static diagnostics match saved `d74498b` results; eight further static gate failures reproduce at exact parent `bc8625f`; the three compile gates reproduce there with 42 product warning errors, 35 host warning errors and one Clippy error. Nine targeted static invocations were run because the native-handle self-test was also replayed as supplemental evidence.
- Two failures are environmental: xwin's MSVC download received proxy HTTP 403; the API-doc regeneration wrapper looks under checkout `target/release` while this run uses an external Cargo target directory. Its later drift check ran after regeneration aborted and does not prove freshly regenerated docs match.

The final source review is clear. A live duplicate check found no overlapping open PR, and all three affected upstream-main blobs still match the validated parent. Linux validation does not prove macOS behavior. The PR-numbered changelog fragment and final fragment-head checks follow draft creation; this code packet does not authorize marking the draft ready yet.

Refs #10739
