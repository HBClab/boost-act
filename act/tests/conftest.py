from __future__ import annotations

from pathlib import Path

import pytest


@pytest.fixture
def temp_study_roots(tmp_path: Path) -> dict[str, Path]:
    """Create local-only roots used by filesystem-facing tests."""
    roots = {
        "int": tmp_path / "act-int-test",
        "obs": tmp_path / "act-obs-test",
        "rdss": tmp_path / "rdss",
    }
    for root in roots.values():
        root.mkdir(parents=True, exist_ok=True)
    return roots


@pytest.fixture
def accel_filename_factory():
    """Build deterministic accel filenames with project naming conventions."""

    def _factory(subject_id: str | int, session: int) -> str:
        subject = str(subject_id)
        return f"sub-{subject}_ses-{session}_accel.csv"

    return _factory


@pytest.fixture
def accel_path_factory(temp_study_roots: dict[str, Path], accel_filename_factory):
    """Build deterministic file paths for both supported study types."""

    def _factory(study: str, subject_id: str | int, session: int) -> Path:
        study_key = study.lower()
        if study_key not in {"int", "obs"}:
            raise ValueError(f"Unknown study type: {study}")

        subject = str(subject_id)
        filename = accel_filename_factory(subject, session)
        return (
            temp_study_roots[study_key]
            / f"sub-{subject}"
            / "accel"
            / f"ses-{session}"
            / filename
        )

    return _factory


@pytest.fixture
def signature_known_good() -> dict[str, list[dict[str, str]]]:
    """Signature fixture where report and RDSS file IDs fully align."""
    report_rows = [
        {"lab_id": "1101", "boost_id": "8001"},
        {"lab_id": "1102", "boost_id": "7012"},
    ]
    rdss_files = [
        {
            "ID": "1101",
            "filename": "1101 (2025-01-01)RAW.csv",
            "Date": "2025-01-01",
        },
        {
            "ID": "1102",
            "filename": "1102 (2025-01-02)RAW.csv",
            "Date": "2025-01-02",
        },
    ]
    return {"report_rows": report_rows, "rdss_files": rdss_files}


@pytest.fixture
def signature_mismatch() -> dict[str, list[dict[str, str]]]:
    """Signature fixture where one report ID is intentionally unmatched."""
    report_rows = [
        {"lab_id": "1201", "boost_id": "8009"},
        {"lab_id": "1202", "boost_id": "7050"},
    ]
    rdss_files = [
        {
            "ID": "1201",
            "filename": "1201 (2025-01-11)RAW.csv",
            "Date": "2025-01-11",
        },
        {
            "ID": "9999",
            "filename": "9999 (2025-01-12)RAW.csv",
            "Date": "2025-01-12",
        },
    ]
    return {"report_rows": report_rows, "rdss_files": rdss_files}
