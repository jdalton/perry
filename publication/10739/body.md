The workspace architecture audit stored member and decision totals alongside the Cargo metadata and crate classifications it already checks. Removing an unrelated member therefore required editing redundant aggregate values, even when the exact dependency closures were unchanged.

This partial #10739 repair moves the policy to schema 2, removes those stored totals, and keeps the exact default and `perry` dependency closures as structural checks. The checker rejects schema 1 and any unexpected baseline fields. The contributor guide documents the migration. This addresses derived workspace counts only; it does not close the broader issue.

Validation: the checker self-test passes (18 cases, including independent and combined leaf removals and rejection controls), Python compilation passes, and the real `cargo metadata --no-deps` architecture audit passes with 68 members, two default members, and the expected closures. Full lint remains pending. The standalone file-size gate currently reports three unchanged files over the 2,000-line cap; their exact base-revision line counts are identical.

Refs #10739
