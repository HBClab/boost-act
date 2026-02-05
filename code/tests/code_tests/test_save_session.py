import datetime as dt
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    # Assumption: repository root is three levels above this file; append so stdlib modules (like 'code') stay ahead.
    sys.path.append(str(PROJECT_ROOT))

import importlib
import types

# Combine the stdlib `code` module with the project's `code/` package so we can import submodules
# without breaking tooling that expects pdb's InteractiveConsole, etc.
stdlib_code = importlib.import_module("code")
project_code_path = PROJECT_ROOT / "code"
merged_code = types.ModuleType("code")
merged_code.__dict__.update(stdlib_code.__dict__)
merged_code.__path__ = [str(project_code_path)]
sys.modules["code"] = merged_code

import pytest

from code.utils.save import Save


def _make_save(tmp_path: Path) -> Save:
    """
    Construct a Save instance without invoking its __init__, wiring in temp directories.
    """
    save = Save.__new__(Save)  # Bypass __init__ to avoid RDSS/network side effects.
    int_dir = tmp_path / "int"
    obs_dir = tmp_path / "obs"
    rdss_dir = tmp_path / "rdss"
    for directory in (int_dir, obs_dir, rdss_dir):
        directory.mkdir(parents=True, exist_ok=True)

    save.INT_DIR = str(int_dir)
    save.OBS_DIR = str(obs_dir)
    save.RDSS_DIR = str(rdss_dir)
    save.matches = {}
    save.dupes = []
    save.symlink = False
    save.session_renames = []
    return save


def _touch_session_file(root: Path, subject_id: str, session: int) -> Path:
    """
    Create a canonical session file for the given subject/session pair.
    """
    file_path = (
        root
        / f"sub-{subject_id}"
        / "accel"
        / f"ses-{session}"
        / f"sub-{subject_id}_ses-{session}_accel.csv"
    )
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.touch()
    return file_path


def test_determine_location_appends_after_existing_sessions(tmp_path: Path):
    save = _make_save(tmp_path)
    existing = _touch_session_file(Path(save.INT_DIR), "8001", 1)
    assert existing.exists()

    matches = {
        "8001": [
            {"study": "int", "run": 1, "date": dt.datetime(2024, 1, 1), "filename": "first.gt3x"},
            {"study": "int", "run": 2, "date": dt.datetime(2024, 1, 2), "filename": "second.gt3x"},
        ]
    }

    updated = save._determine_location(matches)
    sessions = {record["run"] for record in updated["8001"]}
    # determine_location should respect the provided run values.
    assert sessions == {1, 2}
    for record in updated["8001"]:
        assert record["file_path"].endswith(f"ses-{record['run']}/sub-8001_ses-{record['run']}_accel.csv")


def test_determine_location_reuses_missing_session_numbers(tmp_path: Path):
    save = _make_save(tmp_path)
    # Pre-create session 2 only; session 1 should be reassigned to the first new run.
    _touch_session_file(Path(save.INT_DIR), "8002", 2)

    matches = {
        "8002": [
            {"study": "int", "run": 1, "date": dt.datetime(2024, 2, 1), "filename": "gap.gt3x"},
        ]
    }

    updated = save._determine_location(matches)
    record = updated["8002"][0]
    assert record["run"] == 1  # Smallest available session should be reused.
    assert record["file_path"].endswith("ses-1/sub-8002_ses-1_accel.csv")


def test_duplicate_merge_respects_existing_sessions(tmp_path: Path):
    save = _make_save(tmp_path)
    # Existing observational session 1 is missing; interventional already has session 1.
    _touch_session_file(Path(save.INT_DIR), "8100", 1)

    duplicates = [
        {
            "lab_id": "LAB-1",
            "boost_id": "7005",
            "filenames": ["obs_raw.gt3x"],
            "dates": [dt.datetime(2024, 3, 1)],
        },
        {
            "lab_id": "LAB-1",
            "boost_id": "8100",
            "filenames": ["int_first.gt3x", "int_second.gt3x"],
            "dates": [dt.datetime(2024, 3, 2), dt.datetime(2024, 3, 3)],
        },
    ]

    merged = save._handle_and_merge_duplicates(duplicates)

    obs_records = merged["7005"]
    int_records = merged["8100"]

    assert len(obs_records) == 1
    assert obs_records[0]["run"] == 1
    assert obs_records[0]["file_path"].endswith("ses-1/sub-7005_ses-1_accel.csv")

    # Interventional subject already had session 1; ensure we keep appending.
    runs = sorted(record["run"] for record in int_records)
    assert runs == [2, 3]
    for record in int_records:
        assert record["file_path"].endswith(f"ses-{record['run']}/sub-8100_ses-{record['run']}_accel.csv")


def test_duplicate_merge_when_observational_session_exists(tmp_path: Path):
    save = _make_save(tmp_path)
    # Pre-create both observational and interventional sessions to force all new files into INT.
    _touch_session_file(Path(save.OBS_DIR), "7006", 1)
    _touch_session_file(Path(save.INT_DIR), "8200", 1)

    duplicates = [
        {
            "lab_id": "LAB-2",
            "boost_id": "7006",
            "filenames": ["existing_obs.gt3x"],
            "dates": [dt.datetime(2024, 4, 1)],
        },
        {
            "lab_id": "LAB-2",
            "boost_id": "8200",
            "filenames": ["int_new.gt3x"],
            "dates": [dt.datetime(2024, 4, 2)],
        },
    ]

    merged = save._handle_and_merge_duplicates(duplicates)

    # No new observational records should be added because ses-1 exists.
    assert "7006" not in merged or not merged["7006"]

    int_records = merged["8200"]
    assert len(int_records) == 2
    runs = sorted(record["run"] for record in int_records)
    # Existing INT session 1 should push the new runs to sessions 2 and 3.
    assert runs == [2, 3]
    for record in int_records:
        assert record["file_path"].endswith(f"ses-{record['run']}/sub-8200_ses-{record['run']}_accel.csv")


def test_move_files_applies_session_renames_before_copy(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8009"

    existing = _touch_session_file(Path(save.INT_DIR), subject_id, 1)
    rdss_file = Path(save.RDSS_DIR) / "new.csv"
    rdss_file.write_text("new\nrow\n")

    save.session_renames = [
        {
            "subject_id": subject_id,
            "study": "int",
            "from_session": 1,
            "to_session": 2,
        }
    ]

    matches = {
        subject_id: [
            {
                "study": "int",
                "run": 1,
                "date": dt.datetime(2024, 5, 1),
                "filename": "new.csv",
                "file_path": save._session_file_path("int", subject_id, 1),
            }
        ]
    }

    save._move_files(matches)

    assert Path(save._session_file_path("int", subject_id, 2)).exists()
    assert Path(save._session_file_path("int", subject_id, 1)).exists()
