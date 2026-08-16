#!/usr/bin/env bats

setup() {
  ROOT="${BATS_TEST_DIRNAME}/../.."
  STAMP="${ROOT}/packages/agents/codex/.apm/skills/codex-commit/scripts/stamp-review.sh"
  COMMIT="${ROOT}/packages/agents/codex/.apm/skills/codex-commit/scripts/commit.sh"
  REPO="${BATS_TEST_TMPDIR}/repo"
  git init --quiet --initial-branch=main "$REPO"
  git -C "$REPO" config user.name Tester
  git -C "$REPO" config user.email tester@example.com
  printf 'before\n' >"${REPO}/tracked.txt"
  git -C "$REPO" add -- tracked.txt
  git -C "$REPO" commit --quiet -m 'test: initial state'
  printf 'test: bind the review\n\nSigned-off-by: Tester <tester@example.com>\n' >"${REPO}/COMMIT_AGENTMSG"
  printf 'VERDICT: PASS\n' >"${REPO}/verdict"
}

stage_change() {
  printf '%s\n' "$1" >"${REPO}/tracked.txt"
  git -C "$REPO" add -- tracked.txt
}

@test "stamp-review requires the exact delegated verdict" {
  stage_change reviewed
  printf 'VERDICT: CHANGES REQUIRED\n' >"${REPO}/verdict"

  run bash "$STAMP" "$REPO" "${REPO}/verdict"

  [ "$status" -eq 1 ]
  [[ "$output" == *"did not return an exact PASS verdict"* ]]
  [ ! -e "$(git -C "$REPO" rev-parse --absolute-git-dir)/commit-agentmsg.reviewed" ]
}

@test "commit refuses staged content changed after review" {
  stage_change reviewed
  bash "$STAMP" "$REPO" "${REPO}/verdict"
  stage_change changed-after-review

  run bash -c 'cd "$1" && bash "$2"' _ "$REPO" "$COMMIT"

  [ "$status" -eq 1 ]
  [[ "$output" == *"staged tree changed after review-commit-message"* ]]
  [ "$(git -C "$REPO" log -1 --format=%s)" = 'test: initial state' ]
}

@test "commit accepts the exact reviewed message and staged tree" {
  stage_change reviewed
  bash "$STAMP" "$REPO" "${REPO}/verdict"

  run bash -c 'cd "$1" && bash "$2"' _ "$REPO" "$COMMIT"

  [ "$status" -eq 0 ]
  [ "$(git -C "$REPO" log -1 --format=%s)" = 'test: bind the review' ]
  [ "$(git -C "$REPO" show HEAD:tracked.txt)" = reviewed ]
}
