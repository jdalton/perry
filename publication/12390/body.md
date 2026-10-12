The parked `perry-ext-streams` crate duplicates the Web Streams implementation in `perry-stdlib`, and its obsolete tests no longer compile. Remove the crate and wrapper registration. Web Streams retain the canonical stdlib implementation through `bundled-streams`; Node `stream.Readable` keeps its separate runtime path.

This removes the workspace, export-collision, handle and registry inventory entries, updates documentation, and adds two routing regression tests. The registry extraction floor decreases by exactly the six deleted registries, preserving its existing margin. Includes `changelog.d/12439-remove-unused-streams.md`; no version bump.

Closes #12390.

Linux validation passed at final head `1273aff03f8685e3d8a2f539dff9ac94088ac857`:

- Fresh compiler, runtime-static and stdlib-static build; both routing tests and all 33 serial stream tests passed.
- Global ReadableStream, `node:stream/web` and Node Readable examples matched Node with auto-optimization disabled and enabled: all six compile/run/output comparisons passed. The oracle was explicitly `/workspace/.toolchains/node-26.5.1/bin/node`, reporting `v26.5.1`.
- Both auto-optimized feature sets were forcibly rebuilt at this head. Link logs select the new feature-specific archives; no prebuilt-archive fallback occurred. Tiny-program optimization fallback notices are separate from archive selection.
- The fragment-only commit passed diff/file-size checks. Workspace, binding governance, lockfile, export/handle, audit and deny checks previously passed on the unchanged implementation source.

Full lint remains non-green: the earlier complete run on the unchanged implementation source reported 28 failures reproduced on pristine `d74498b261d087a301b80602835bc7199a067957` and two environment failures (Windows CRT download HTTP403 and API-doc generation's hardcoded default binary path). Direct API generation using the fresh compiler matched baseline output. The full driver was not repeated for the changelog-only commit; the matching compiler/archive rebuild and scoped acceptance above were repeated.

CI attribution for the two investigated jobs: [warnings](https://github.com/PerryTS/perry/actions/runs/38197365225/job/114643197500) reports 37 runtime diagnostics in product scope and 30 in host scope, plus two codegen diagnostics each; all 39 distinct diagnostics match saved baseline findings, including `I1`/`I64` and unnecessary `mut mllvm`. [TLS](https://github.com/PerryTS/perry/actions/runs/38197365255/job/114643665090) reports 16 grouped findings, all reproduced on pristine baseline, including the two raw `thread_local` declarations in `alloc_census.rs`. CI checked synthetic merge `429dabe838705910dd3cdbb2005716026336aaf1` into upstream `996bc5d629dfbc4b0e99a377b6eeab57c32e54c6`; upstream line shifts are recorded. This is attribution for those jobs, without a new full baseline build of that newer main or a green-CI claim.

[Final-head evidence and baseline attribution](https://github.com/jdalton/perry/tree/cloud/publication-handoffs/publication/12390) include artifact hashes and command results. The earlier Node-version metadata mismatch and shell fallback-check false positive remain archived; the final six runs explicitly record the pinned Node executable and successful exits. Linux validation does not establish macOS behavior.
