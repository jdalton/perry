Remove the unused `perry-ext-streams` crate, its workspace/binding rows, and duplicate export inventory entries. Web Streams remain provided by `perry-stdlib` through `bundled-streams`; Node `stream.Readable` keeps its separate runtime path. The registry floor decreases by exactly the six deleted registries, preserving the existing margin.

Fixes #12390.

Linux validation for code commit `c9e720b17f959c0052819939bd1328c7a56fd415`:

- Fresh compiler, runtime-static and stdlib-static build; two routing tests and 33 serial stdlib stream tests passed.
- Global ReadableStream, `node:stream/web` and Node Readable examples matched Node 26.5.1 with auto-optimization disabled and enabled (six runs). Genuine auto-optimization rebuilt matching feature-specific runtime/stdlib archives; link logs show no prebuilt-archive fallback and no `perry-ext-streams` archive. One shell post-check falsely matched an unrelated tiny-program optimization notice; actual compilation, execution and output comparison passed.
- The unchanged implementation tree completed full lint: 30/137 failures, with two CI-only skips. Twenty-eight failures reproduce on pristine upstream, including exact diagnostic matches for both warnings scopes and the host Clippy reversed-empty-range error. Two environment failures remain: Windows CRT download HTTP403 and API-doc regeneration's hardcoded default binary path. Direct generation using the fresh compiler matches baseline API output.
- File-size, diff, lockfile no-downgrade, export/handle no-raise, workspace/binding checks, cargo audit and cargo deny passed on the unchanged implementation tree.

Draft pending the actual PR-numbered changelog fragment and matching compiler/static-archive rebuild at that resulting commit. No version bump. Linux validation does not establish macOS behavior.
