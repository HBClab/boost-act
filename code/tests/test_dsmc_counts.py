from __future__ import annotations

import csv
import logging
from pathlib import Path

import pytest

from code import dsmc_counts


@pytest.fixture()
def study_dirs(tmp_path: Path) -> tuple[Path, Path]:
    int_dir = tmp_path / "INT_DIR"
    obs_dir = tmp_path / "OBS_DIR"
    int_dir.mkdir()
    obs_dir.mkdir()
    return int_dir, obs_dir


def _write_session_file(root: Path, subject: str, session: str) -> Path:
    session_dir = root / subject / "accel" / session
    session_dir.mkdir(parents=True, exist_ok=True)
    file_path = session_dir / f"{subject}_{session}_accel.csv"
    file_path.write_text("data")
    return file_path


def _write_expected_csv(path: Path, header: list[str], row: list[str]) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerow(row)


def test_count_actual_sessions_ignores_accel_all(study_dirs: tuple[Path, Path]) -> None:
    int_dir, obs_dir = study_dirs

    _write_session_file(int_dir, "sub-0001", "ses-1")
    _write_session_file(int_dir, "sub-0002", "ses-1")

    all_path = int_dir / "sub-0001" / "accel" / "all" / "ses-1"
    all_path.mkdir(parents=True, exist_ok=True)
    (all_path / "sub-0001_ses-1_accel.csv").write_text("data")

    _write_session_file(obs_dir, "sub-0003", "ses-2")

    counts = dsmc_counts.count_actual_sessions(int_dir, obs_dir)

    assert counts["ses-1"] == 2
    assert counts["ses-2"] == 1


def test_count_actual_sessions_logs_pattern_mismatches(
    study_dirs: tuple[Path, Path], caplog: pytest.LogCaptureFixture
) -> None:
    int_dir, obs_dir = study_dirs

    bad_path = int_dir / "sub-0001" / "accel" / "ses-1"
    bad_path.mkdir(parents=True, exist_ok=True)
    (bad_path / "sub-0001_ses-2_accel.csv").write_text("data")

    caplog.set_level(logging.WARNING)
    counts = dsmc_counts.count_actual_sessions(int_dir, obs_dir)

    assert counts == {}
    assert "mismatched" in caplog.text


def test_parse_expected_counts_single_row(tmp_path: Path) -> None:
    expected_csv = tmp_path / "expected.csv"
    _write_expected_csv(expected_csv, ["ses-1", "ses-2"], ["10", "5"])

    expected = dsmc_counts.parse_expected_counts(expected_csv)

    assert expected == {"ses-1": 10, "ses-2": 5}


def test_parse_expected_counts_skips_malformed_and_negative(
    tmp_path: Path, caplog: pytest.LogCaptureFixture
) -> None:
    expected_csv = tmp_path / "expected.csv"
    _write_expected_csv(expected_csv, ["ses-1", "ses-2", "ses-3"], ["10", "-1", "foo"])

    caplog.set_level(logging.WARNING)
    expected = dsmc_counts.parse_expected_counts(expected_csv)

    assert expected == {"ses-1": 10}
    assert "negative" in caplog.text
    assert "non-numeric" in caplog.text


def test_build_report_handles_missing_or_zero_expected() -> None:
    actual_counts = {"ses-1": 4, "ses-2": 2}
    expected_counts = {"ses-1": 0}

    rows = dsmc_counts.build_report(actual_counts, expected_counts)

    rows_by_session = {row["session"]: row for row in rows}
    assert rows_by_session["ses-1"]["expected_count"] == 0
    assert rows_by_session["ses-1"]["proportion"] == ""
    assert rows_by_session["ses-2"]["expected_count"] == ""
    assert rows_by_session["ses-2"]["proportion"] == ""


def test_cli_invocation_writes_output(
    study_dirs: tuple[Path, Path], tmp_path: Path
) -> None:
    int_dir, obs_dir = study_dirs
    _write_session_file(int_dir, "sub-0001", "ses-1")

    expected_csv = tmp_path / "expected.csv"
    _write_expected_csv(expected_csv, ["ses-1"], ["2"])

    out_csv = tmp_path / "output.csv"
    exit_code = dsmc_counts.main(
        [
            "--int-dir",
            str(int_dir),
            "--obs-dir",
            str(obs_dir),
            "--expected",
            str(expected_csv),
            "--out",
            str(out_csv),
        ]
    )

    assert exit_code == 0
    assert out_csv.exists()
    contents = out_csv.read_text().splitlines()
    assert contents[0] == "session,actual_count,expected_count,proportion"
    assert "ses-1" in contents[1]
