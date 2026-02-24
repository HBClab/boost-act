from __future__ import annotations

import importlib
import json
from pathlib import Path
import sys
import types

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

_comparison_utils = importlib.import_module("act.utils.comparison_utils")
_stdlib_code = importlib.import_module("code")
_code_utils = types.ModuleType("act.utils")
_code_utils.comparison_utils = _comparison_utils
_stdlib_act.utils = _code_utils
sys.modules["act.utils"] = _code_utils
sys.modules["act.utils.comparison_utils"] = _comparison_utils


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


@pytest.fixture
def manifest_factory(tmp_path: Path):
    """Seed and load manifest JSON payloads for tests."""

    def _factory(payload: dict[str, list[dict]] | None = None, relative_path: str = "res/data.json") -> Path:
        manifest_path = tmp_path / relative_path
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_payload = payload or {}
        manifest_path.write_text(
            json.dumps(manifest_payload, indent=2),
            encoding="utf-8",
        )
        return manifest_path

    return _factory


@pytest.fixture
def rdss_record_factory():
    """Build normalized incoming RDSS-like record dictionaries."""

    def _factory(
        lab_id: str,
        date_value: str,
        filename: str,
        **overrides,
    ) -> dict:
        record = {
            "labID": str(lab_id),
            "date": date_value,
            "filename": filename,
        }
        record.update(overrides)
        return record

    return _factory


@pytest.fixture
def subject_tree_factory(temp_study_roots: dict[str, Path], accel_filename_factory):
    """Create per-subject accel/ses-* trees and CSV fixtures under study roots."""

    def _factory(
        study: str,
        subject_id: str | int,
        sessions: dict[int, str],
    ) -> dict[int, Path]:
        study_key = study.lower()
        if study_key not in {"int", "obs"}:
            raise ValueError(f"Unknown study type: {study}")

        subject = str(subject_id)
        created = {}
        for session, content in sessions.items():
            session_dir = (
                temp_study_roots[study_key]
                / f"sub-{subject}"
                / "accel"
                / f"ses-{session}"
            )
            session_dir.mkdir(parents=True, exist_ok=True)
            file_path = session_dir / accel_filename_factory(subject, session)
            file_path.write_text(content, encoding="utf-8")
            created[int(session)] = file_path

        return created

    return _factory
