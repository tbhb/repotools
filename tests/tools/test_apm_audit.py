from __future__ import annotations

import runpy
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "tools/apm_audit.py"
SUBJECT = runpy.run_path(str(SCRIPT))
suppressible_worktree_findings = SUBJECT["suppressible_worktree_findings"]


def report(*failed_checks: dict[str, object]) -> dict[str, object]:
    return {"checks": list(failed_checks)}


def test_accepts_unicode_findings_inside_registered_worktree(tmp_path: Path) -> None:
    worktree = tmp_path / ".codex/worktrees/example"
    finding = "unicode: .codex/worktrees/example/.venv/package.py"

    passed, ignored = suppressible_worktree_findings(
        report(
            {
                "name": "content-integrity",
                "passed": False,
                "details": [finding],
            }
        ),
        tmp_path,
        (worktree,),
    )

    assert passed
    assert ignored == (finding,)


def test_rejects_unicode_finding_outside_registered_worktree(tmp_path: Path) -> None:
    passed, ignored = suppressible_worktree_findings(
        report(
            {
                "name": "content-integrity",
                "passed": False,
                "details": ["unicode: .agents/skills/example/SKILL.md"],
            }
        ),
        tmp_path,
        (tmp_path / ".codex/worktrees/example",),
    )

    assert not passed
    assert ignored == ()


def test_rejects_hash_drift_inside_registered_worktree(tmp_path: Path) -> None:
    passed, ignored = suppressible_worktree_findings(
        report(
            {
                "name": "content-integrity",
                "passed": False,
                "details": ["hash-drift: .codex/worktrees/example/file"],
            }
        ),
        tmp_path,
        (tmp_path / ".codex/worktrees/example",),
    )

    assert not passed
    assert ignored == ()


def test_rejects_any_other_failed_check(tmp_path: Path) -> None:
    passed, ignored = suppressible_worktree_findings(
        report({"name": "drift", "passed": False, "details": []}),
        tmp_path,
        (),
    )

    assert not passed
    assert ignored == ()


def test_accepts_clean_report(tmp_path: Path) -> None:
    passed, ignored = suppressible_worktree_findings(
        report({"name": "content-integrity", "passed": True, "details": []}),
        tmp_path,
        (),
    )

    assert passed
    assert ignored == ()
