Do not create a numbered fragment until the local publisher assigns the real PR number. No numbered fragment is included in this packet.

When the publisher relay supplies the PR number, the cloud implementation owner will use the existing clean worktree for the PR branch:

1. Run `git switch cloud/issue-9927-freshness-search` and confirm `git status --short` is empty. Verify `git rev-parse HEAD` equals `validated_final_head` in `metadata.json`. Keep the PR target as `main`; do not automatically rebase the partial candidate.
2. Set `ACTUAL_PR=<real-number-from-publisher>` and run `case "$ACTUAL_PR" in ''|*[!0-9]*) echo 'invalid PR number' >&2; exit 1;; esac`. Set `FRAGMENT="changelog.d/${ACTUAL_PR}-gate-freshness-search.md"`.
3. Create the file by copying `fragment-draft.txt` to `"$FRAGMENT"`; do not widen its scope or change it to a `Closes` claim.
4. Run `git diff --check`, commit only the numbered fragment, and push the same PR branch. Record the actual PR number, final exact head, and fragment path in `metadata.json`.
5. Re-run exact-head validation after the fragment commit and confirm the publisher-created PR points to that exact head and includes the numbered fragment. Only then set `ready_for_review=true`.
