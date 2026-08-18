# Dev-facing targets. Perry is plain cargo (no mise), so this is intentionally
# minimal — add targets here only when a plain `cargo <verb>` isn't enough.

# Apply clippy's machine-applicable autofixes across the workspace via
# cargo-fixit (crate-ci/cargo-fixit, pinned 0.1.13 by the `fix-deps` target
# below) — the drop-in, faster replacement for `cargo clippy --fix` on
# repeated runs, because it skips the full re-check compile between fix
# rounds. There is deliberately no `cargo clippy --fix` fallback: install
# cargo-fixit with `make fix-deps` (or `cargo install cargo-fixit@0.1.13
# --locked`) first. Run on a dirty tree is intended
# (--allow-dirty --allow-staged); review the diff before committing. The CI
# clippy gate is unchanged. Mirrors the fleet's
# `scripts/fleet/lint-rust.mts --fix`.
.PHONY: fix
fix:
	@set -e; cargo fixit --clippy --workspace --all-targets --allow-dirty --allow-staged

# Install the pinned cargo-fixit dev tool that `make fix` drives. cargo-fixit
# is a cargo crate (not a release-asset binary), so it is pinned here rather
# than in external-tools.json. `--locked` respects the published Cargo.lock.
.PHONY: fix-deps
fix-deps:
	@set -e; cargo install cargo-fixit@0.1.13 --locked
