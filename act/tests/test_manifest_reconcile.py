from __future__ import annotations

import logging

from act.utils.save import Save


def _make_save(tmp_path):
    save = Save.__new__(Save)
    save.logger = logging.getLogger("act.utils.save")
    save.INT_DIR = str(tmp_path / "int")
    save.OBS_DIR = str(tmp_path / "obs")
    save.RDSS_DIR = str(tmp_path / "rdss")
    save.manifest_path = str(tmp_path / "res" / "data.json")
    save.symlink = False
    save.manifest = {}
    return save


def _write(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")


def test_reconcile_manifest_repairs_mismatched_destination(tmp_path):
    save = _make_save(tmp_path)
    source_path = tmp_path / "rdss" / "1201 (2025-03-01)RAW.csv"
    destination_path = (
        tmp_path
        / "int"
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    _write(source_path, "canonical-data")
    _write(destination_path, "stale-data")

    save.manifest = {
        "8001": [
            {
                "filename": source_path.name,
                "labID": "1201",
                "date": "2025-03-01",
                "run": 1,
                "study": "int",
                "file_path": str(destination_path),
            }
        ]
    }
    save._save_manifest(str(save.manifest_path))

    report = save.reconcile_manifest()

    assert report["total_records"] == 1
    assert report["mismatched"] == 1
    assert report["repaired"] == 1
    assert report["errors"] == []
    assert destination_path.read_text(encoding="utf-8") == "canonical-data"


def test_reconcile_manifest_reports_missing_source(tmp_path):
    save = _make_save(tmp_path)
    destination_path = (
        tmp_path
        / "int"
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    _write(destination_path, "present-data")

    save.manifest = {
        "8001": [
            {
                "filename": "missing.csv",
                "labID": "1201",
                "date": "2025-03-01",
                "run": 1,
                "study": "int",
                "file_path": str(destination_path),
            }
        ]
    }
    save._save_manifest(str(save.manifest_path))

    report = save.reconcile_manifest()

    assert report["missing_source"] == 1
    assert report["errors"] == [
        "subject=8001 run=1 source="
        + str(tmp_path / "rdss" / "missing.csv")
        + f" destination={destination_path} error=missing_source"
    ]


def test_reconcile_manifest_reports_ambiguous_session_directory(tmp_path):
    save = _make_save(tmp_path)
    source_path = tmp_path / "rdss" / "1201 (2025-03-01)RAW.csv"
    session_dir = tmp_path / "int" / "sub-8001" / "accel" / "ses-1"
    destination_path = session_dir / "sub-8001_ses-1_accel.csv"
    alternate_path = session_dir / "sub-8001_ses-1_alt_accel.csv"
    _write(source_path, "canonical-data")
    _write(destination_path, "stale-data")
    _write(alternate_path, "other-data")

    save.manifest = {
        "8001": [
            {
                "filename": source_path.name,
                "labID": "1201",
                "date": "2025-03-01",
                "run": 1,
                "study": "int",
                "file_path": str(destination_path),
            }
        ]
    }
    save._save_manifest(str(save.manifest_path))

    report = save.reconcile_manifest()

    assert report["ambiguous_dest"] == 1
    assert len(report["errors"]) == 1
    assert "multiple accel csv candidates" in report["errors"][0]


def test_copy_subject_record_fails_on_destination_identity_mismatch(tmp_path):
    save = _make_save(tmp_path)
    source_path = tmp_path / "rdss" / "1201 (2025-03-01)RAW.csv"
    destination_path = (
        tmp_path
        / "int"
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    _write(source_path, "canonical-data")
    _write(destination_path, "wrong-data")

    record = {
        "subject_id": "8001",
        "filename": source_path.name,
        "run": 1,
        "file_path": str(destination_path),
    }

    try:
        save._copy_subject_record(record)
    except ValueError as exc:
        message = str(exc)
    else:
        raise AssertionError("Expected identity mismatch failure")

    assert "Destination identity mismatch" in message


def test_apply_two_phase_renames_fails_on_ambiguous_source_session(tmp_path):
    save = _make_save(tmp_path)
    subject_id = "8001"
    session_dir = tmp_path / "int" / "sub-8001" / "accel" / "ses-1"
    target_dir = tmp_path / "int" / "sub-8001" / "accel" / "ses-2"
    _write(session_dir / "sub-8001_ses-1_accel.csv", "a")
    _write(session_dir / "sub-8001_ses-1_alt_accel.csv", "b")
    target_dir.mkdir(parents=True, exist_ok=True)

    rename_plan = {
        "subject_id": subject_id,
        "study": "int",
        "moves": [
            {
                "record_key": ("1201", "2025-03-01", "1201 (2025-03-01)RAW.csv"),
                "old_run": 1,
                "new_run": 2,
                "old_dir": str(session_dir),
                "new_dir": str(target_dir),
                "old_file": str(session_dir / "sub-8001_ses-1_accel.csv"),
                "new_file": str(target_dir / "sub-8001_ses-2_accel.csv"),
            }
        ],
    }

    try:
        save._apply_two_phase_renames(rename_plan)
    except ValueError as exc:
        message = str(exc)
    else:
        raise AssertionError("Expected ambiguous session failure")

    assert "multiple accel csv candidates" in message
