#!/usr/bin/env bash
# Final parity-run verdict shared by the harness and its offline self-test.

parity_final_verdict() {
    local test_suite="$1"
    local total_run="$2"
    local parity_pass="$3"
    local compile_fail="$4"
    local crash_fail="$5"
    local node_fail="$6"
    local skipped="${7:-0}"
    : "$skipped" # skipped cases are intentionally outside the final verdict.

    # The curated node suite treats execution failures as hard defects, even
    # when ordinary output parity remains above the historical 80% threshold.
    # These counts come from the final journal summary, so resume and fresh
    # runs use the same policy. Skips remain separate and do not fail the run.
    if [[ "$test_suite" == "node-suite" ]] \
        && (( compile_fail > 0 || crash_fail > 0 || node_fail > 0 )); then
        return 2
    fi

    if (( total_run == 0 || parity_pass * 100 < total_run * 80 )); then
        return 1
    fi

    return 0
}

parity_final_verdict_assert() {
    local expected="$1"
    local label="$2"
    shift 2
    local actual

    if parity_final_verdict "$@"; then
        actual=0
    else
        actual=$?
    fi
    if (( actual != expected )); then
        printf 'FAIL: %s expected status %s, got %s\n' "$label" "$expected" "$actual" >&2
        return 1
    fi
}

parity_final_verdict_self_test() {
    local failed=0

    parity_final_verdict_assert 0 'clean node suite with skipped cases' node-suite 100 100 0 0 0 3 || failed=1
    parity_final_verdict_assert 0 'ordinary mismatch above threshold' node-suite 101 100 0 0 0 || failed=1
    parity_final_verdict_assert 0 'exact 80 percent boundary' node-suite 10 8 0 0 0 || failed=1
    parity_final_verdict_assert 1 'below threshold' node-suite 100 79 0 0 0 || failed=1
    parity_final_verdict_assert 1 'empty run' node-suite 0 0 0 0 0 || failed=1

    # Each journal-derived execution failure is fatal independently of parity.
    parity_final_verdict_assert 2 'compile failure above threshold' node-suite 100 100 1 0 0 || failed=1
    parity_final_verdict_assert 2 'crash/timeout above threshold' node-suite 100 100 0 1 0 || failed=1
    parity_final_verdict_assert 2 'oracle node failure above threshold' node-suite 100 100 0 0 1 || failed=1

    # The harness has no allowlist input to this final verdict seam, so an
    # output-mismatch exception cannot waive a journaled hard execution status.
    parity_final_verdict_assert 2 'hard status is independent of output exceptions' node-suite 100 100 0 0 1 || failed=1

    # Other suite policies remain the existing percentage/empty-run rule.
    parity_final_verdict_assert 0 'other suite ignores these status counters' all 100 100 1 1 1 || failed=1

    # A resumed run supplies the same final journal counters to this seam.
    parity_final_verdict_assert 2 'resumed node-suite hard failure' node-suite 100 100 1 0 0 || failed=1

    parity_final_verdict_mock_harness_test || failed=1

    if (( failed )); then
        return 1
    fi
    echo 'parity final verdict self-test: all cases passed'
}

parity_final_verdict_mock_harness_test() (
    local source_root helper_dir mock_root runtime_dir journal report output status
    helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source_root="$(cd "$helper_dir/.." && pwd)"
    mock_root="$(mktemp -d "${TMPDIR:-/tmp}/parity-verdict.XXXXXX")" || return 1
    trap 'rm -rf "$mock_root"' EXIT
    runtime_dir="$mock_root/runtime"
    journal="$mock_root/journal.jsonl"
    output="$mock_root/harness.out"
    mkdir -p "$mock_root/scripts" "$mock_root/test-parity/node-suite/url" \
        "$mock_root/test-files" "$runtime_dir"
    cp "$source_root/run_parity_tests.sh" "$mock_root/run_parity_tests.sh" || return 1
    cp "$helper_dir/parity_final_verdict.sh" "$mock_root/scripts/parity_final_verdict.sh" || return 1
    printf '#!/bin/sh\nexit 0\n' > "$mock_root/perry" || return 1
    chmod +x "$mock_root/perry" || return 1
    : > "$runtime_dir/libperry_runtime.a"
    : > "$runtime_dir/libperry_stdlib.a"
    printf 'console.log("mocked; this file is pre-recorded in the journal");\n' \
        > "$mock_root/test-parity/node-suite/url/probe.ts"

    # Pre-record the selected fixture plus 100 passes. The real harness will
    # resume it without invoking Perry or Node, rebuild the report from those
    # journal records, then take its actual final verdict path.
    python3 - "$mock_root/perry" "$runtime_dir/libperry_runtime.a" \
        "$runtime_dir/libperry_stdlib.a" "$journal" <<'PY' || return 1
import hashlib
import json
import os
import sys

paths = sys.argv[1:4]
outer = hashlib.sha256()
for path in paths:
    outer.update(os.path.basename(path).encode("utf-8"))
    inner = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            inner.update(chunk)
    outer.update(inner.digest())
    outer.update(str(os.path.getsize(path)).encode("utf-8"))
header = {
    "kind": "header", "journal_version": 1, "toolchain": outer.hexdigest(),
    "suite": "node-suite", "module": "url", "filter": "probe",
    "shard": "", "host_platform": "linux", "started_at": "self-test",
    "git_head": "self-test", "perry_bin": paths[0], "runtime_dir": os.path.dirname(paths[1]),
}
with open(sys.argv[4], "w", encoding="utf-8") as fh:
    fh.write(json.dumps(header, sort_keys=True, separators=(",", ":")) + "\n")
    for i in range(100):
        fh.write(json.dumps({"kind": "result", "id": f"mock/pass-{i}", "status": "pass"}) + "\n")
    fh.write(json.dumps({"kind": "result", "id": "node-suite/url/probe", "status": "crash"}) + "\n")
PY

    if PERRY_SKIP_BUILD=1 PERRY_BIN="$mock_root/perry" PERRY_RUNTIME_DIR="$runtime_dir" \
        PERRY_PARITY_JOURNAL="$journal" PERRY_HOST_PLATFORM=linux \
        bash "$mock_root/run_parity_tests.sh" --suite node-suite --module url \
            --filter probe --resume >"$output" 2>&1; then
        echo 'FAIL: mocked node-suite harness accepted a journaled crash' >&2
        return 1
    else
        status=$?
    fi
    if (( status != 1 )); then
        echo "FAIL: mocked node-suite harness exited $status, expected 1" >&2
        cat "$output" >&2
        return 1
    fi
    if ! grep -q 'Resuming from journal:' "$output" \
        || ! grep -q 'Node suite has compile, crash/timeout, or Node oracle failures' "$output"; then
        echo 'FAIL: mocked harness did not resume and reject the journaled crash' >&2
        cat "$output" >&2
        return 1
    fi
    report="$(sed -n 's/^Report saved to: //p' "$output" | tail -n 1)"
    if [[ -z "$report" || ! -s "$report" || ! -s "$mock_root/test-parity/reports/latest.json" ]]; then
        echo 'FAIL: mocked harness did not emit its report before failing' >&2
        cat "$output" >&2
        return 1
    fi
    if ! cmp -s "$report" "$mock_root/test-parity/reports/latest.json"; then
        echo 'FAIL: latest report does not match the completed resumed report' >&2
        return 1
    fi
    if ! python3 - "$report" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    summary = json.load(fh)["summary"]
assert summary["parity_pass"] == 100, summary
assert summary["crash_fail"] == 1, summary
assert summary["total_run"] == 101, summary
PY
    then
        echo 'FAIL: mocked harness report omitted the resumed hard failure counts' >&2
        return 1
    fi
    if (( $(grep -n 'Report saved to:' "$output" | cut -d: -f1) \
        >= $(grep -n 'Node suite has compile, crash/timeout' "$output" | cut -d: -f1) )); then
        echo 'FAIL: mocked harness reported failure before writing its report' >&2
        return 1
    fi

    # The real interruption branch remains before the final verdict call. The
    # mocked run is a completed resume; this source-order check proves the new
    # predicate cannot replace an interrupted-run status.
    local report_line interrupt_exit_line verdict_line
    report_line="$(grep -n '^cat > "$REPORT_FILE" << EOF$' "$mock_root/run_parity_tests.sh" | cut -d: -f1)"
    interrupt_exit_line="$(grep -n 'exit "$PARITY_INTERRUPTED"' "$mock_root/run_parity_tests.sh" | tail -n 1 | cut -d: -f1)"
    verdict_line="$(grep -n '^if parity_final_verdict ' "$mock_root/run_parity_tests.sh" | cut -d: -f1)"
    if [[ -z "$report_line" || -z "$interrupt_exit_line" || -z "$verdict_line" ]] \
        || (( report_line >= interrupt_exit_line || interrupt_exit_line >= verdict_line )); then
        echo 'FAIL: report/interruption/final-verdict ordering changed' >&2
        return 1
    fi
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" == "--self-test" && $# == 1 ]]; then
        parity_final_verdict_self_test
    else
        echo "usage: bash $0 --self-test" >&2
        exit 2
    fi
fi
