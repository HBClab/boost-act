from __future__ import annotations

from datetime import datetime
import logging
import os

from act.utils.save import Save


def _make_save_with_manifest(path: str):
    save = Save.__new__(Save)
    save.manifest_path = path
    save.manifest = {}
    save.logger = logging.getLogger("act.utils.save")
    return save


def _set_study_roots(save, tmp_path):
    save.INT_DIR = str(tmp_path / "int")
    save.OBS_DIR = str(tmp_path / "obs")
    save.RDSS_DIR = str(tmp_path / "rdss")
    save.symlink = False


def test_load_manifest_missing_file_returns_empty(tmp_path, caplog):
    manifest_path = tmp_path / "res" / "missing-data.json"
    save = _make_save_with_manifest(str(manifest_path))

    with caplog.at_level(logging.WARNING):
        loaded = save._load_manifest(str(manifest_path))

    assert loaded == {}
    assert "Manifest file not found" in caplog.text


def test_load_manifest_roundtrip(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    save.manifest = {
        "8001": [
            {
                "filename": "1101 (2025-01-01)RAW.csv",
                "labID": "1101",
                "date": "2025-01-01",
                "run": 1,
            }
        ]
    }

    saved_payload = save._save_manifest(str(manifest_path))
    loaded_payload = save._load_manifest(str(manifest_path))

    assert saved_payload == save.manifest
    assert loaded_payload == save.manifest


def test_exact_duplicate_key_noop(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))

    existing_records = [
        {
            "filename": "1101 (2025-01-01)RAW.csv",
            "labID": "1101",
            "date": "2025-01-01",
            "run": 1,
        }
    ]
    incoming_records = [
        {
            "filename": "1101 (2025-01-01)RAW.csv",
            "labID": "1101",
            "date": datetime(2025, 1, 1, 12, 30, 0),
            "run": 99,
        }
    ]

    merged = save._reindex_subject_records(existing_records, incoming_records)

    assert len(merged) == 1
    assert merged[0]["labID"] == "1101"
    assert merged[0]["filename"] == "1101 (2025-01-01)RAW.csv"
    assert merged[0]["date"] == "2025-01-01"
    assert merged[0]["run"] == 1


def test_idempotent_rerun_no_session_drift(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))

    existing_records = [
        {
            "filename": "1101 (2025-01-01)RAW.csv",
            "labID": "1101",
            "date": "2025-01-01",
            "run": 1,
        },
        {
            "filename": "1101 (2025-01-02)RAW.csv",
            "labID": "1101",
            "date": "2025-01-02",
            "run": 2,
        },
    ]
    incoming_records = [
        {
            "filename": "1101 (2025-01-01)RAW.csv",
            "labID": "1101",
            "date": "2025-01-01T00:00:00",
            "run": 100,
        },
        {
            "filename": "1101 (2025-01-02)RAW.csv",
            "labID": "1101",
            "date": datetime(2025, 1, 2, 0, 0, 0),
            "run": 200,
        },
    ]

    first_pass = save._reindex_subject_records(existing_records, incoming_records)
    second_pass = save._reindex_subject_records(first_pass, incoming_records)

    assert first_pass == second_pass
    assert len(second_pass) == 2
    assert [record["run"] for record in second_pass] == [1, 2]
    assert [record["date"] for record in second_pass] == ["2025-01-01", "2025-01-02"]


def test_same_date_conflict_warns_and_skips_subject(tmp_path, caplog):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    matches = {
        "8001": [
            {
                "filename": "1101 (2025-01-01)RAW.csv",
                "labID": "1101",
                "date": "2025-01-01",
            },
            {
                "filename": "1102 (2025-01-01)RAW.csv",
                "labID": "1102",
                "date": "2025-01-01T08:00:00",
            },
        ]
    }

    with caplog.at_level(logging.WARNING):
        result = save._determine_run(matches)

    assert result["8001"] == []
    assert "skip_tie_date subject=8001" in caplog.text


def test_new_subject_defaults_to_run_one(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    _set_study_roots(save, tmp_path)
    save.manifest = {}

    matches = {
        "8001": [
            {
                "filename": "2101 (2025-03-01)RAW.csv",
                "labID": "2101",
                "date": "2025-03-01",
            }
        ]
    }

    result = save._determine_run(matches)
    assert result["8001"][0]["run"] == 1

    save._determine_study(result)
    save._determine_location(result)
    assert "/ses-1/" in result["8001"][0]["file_path"]


def test_later_date_appends_next_run(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    _set_study_roots(save, tmp_path)
    save.manifest = {
        "8001": [
            {
                "filename": "2101 (2025-03-01)RAW.csv",
                "labID": "2101",
                "date": "2025-03-01",
                "run": 1,
            },
            {
                "filename": "2101 (2025-03-02)RAW.csv",
                "labID": "2101",
                "date": "2025-03-02",
                "run": 2,
            },
        ]
    }

    matches = {
        "8001": [
            {
                "filename": "2101 (2025-03-03)RAW.csv",
                "labID": "2101",
                "date": "2025-03-03",
            }
        ]
    }

    result = save._determine_run(matches)
    assert result["8001"][0]["run"] == 3

    save._determine_study(result)
    save._determine_location(result)
    assert "/ses-3/" in result["8001"][0]["file_path"]


def test_earlier_date_backfill_reindexes_and_shifts_runs(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    _set_study_roots(save, tmp_path)
    save.manifest = {
        "8001": [
            {
                "filename": "2101 (2025-03-02)RAW.csv",
                "labID": "2101",
                "date": "2025-03-02",
                "run": 1,
            },
            {
                "filename": "2101 (2025-03-03)RAW.csv",
                "labID": "2101",
                "date": "2025-03-03",
                "run": 2,
            },
        ]
    }

    matches = {
        "8001": [
            {
                "filename": "2101 (2025-03-01)RAW.csv",
                "labID": "2101",
                "date": "2025-03-01",
            }
        ]
    }

    result = save._determine_run(matches)
    assert result["8001"][0]["run"] == 1

    save._determine_study(result)
    save._determine_location(result)
    assert "/ses-1/" in result["8001"][0]["file_path"]


def test_two_phase_rename_avoids_collision(tmp_path):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    _set_study_roots(save, tmp_path)

    subject_id = "8001"
    study = "int"

    ses1_dir = os.path.join(save.INT_DIR, f"sub-{subject_id}", "accel", "ses-1")
    ses2_dir = os.path.join(save.INT_DIR, f"sub-{subject_id}", "accel", "ses-2")
    os.makedirs(ses1_dir, exist_ok=True)
    os.makedirs(ses2_dir, exist_ok=True)

    ses1_file = os.path.join(ses1_dir, f"sub-{subject_id}_ses-1_accel.csv")
    ses2_file = os.path.join(ses2_dir, f"sub-{subject_id}_ses-2_accel.csv")
    with open(ses1_file, "w", encoding="utf-8") as handle:
        handle.write("record-a")
    with open(ses2_file, "w", encoding="utf-8") as handle:
        handle.write("record-b")

    old_records = [
        {
            "filename": "2101 (2025-03-01)RAW.csv",
            "labID": "2101",
            "date": "2025-03-01",
            "run": 1,
        },
        {
            "filename": "2101 (2025-03-02)RAW.csv",
            "labID": "2101",
            "date": "2025-03-02",
            "run": 2,
        },
    ]
    new_records = [
        {
            "filename": "2101 (2025-03-01)RAW.csv",
            "labID": "2101",
            "date": "2025-03-01",
            "run": 2,
        },
        {
            "filename": "2101 (2025-03-02)RAW.csv",
            "labID": "2101",
            "date": "2025-03-02",
            "run": 1,
        },
    ]

    rename_plan = save._plan_subject_renames(
        subject_id=subject_id,
        study=study,
        old_records=old_records,
        new_records=new_records,
    )

    assert len(rename_plan["moves"]) == 2

    save._apply_two_phase_renames(rename_plan)

    new_ses1_file = os.path.join(
        save.INT_DIR,
        f"sub-{subject_id}",
        "accel",
        "ses-1",
        f"sub-{subject_id}_ses-1_accel.csv",
    )
    new_ses2_file = os.path.join(
        save.INT_DIR,
        f"sub-{subject_id}",
        "accel",
        "ses-2",
        f"sub-{subject_id}_ses-2_accel.csv",
    )

    assert os.path.exists(new_ses1_file)
    assert os.path.exists(new_ses2_file)

    with open(new_ses1_file, "r", encoding="utf-8") as handle:
        ses1_content = handle.read()
    with open(new_ses2_file, "r", encoding="utf-8") as handle:
        ses2_content = handle.read()

    assert ses1_content == "record-b"
    assert ses2_content == "record-a"

    accel_dir = os.path.join(save.INT_DIR, f"sub-{subject_id}", "accel")
    assert not any(name.startswith(".tmp-") for name in os.listdir(accel_dir))


def test_subject_failure_does_not_mutate_manifest(tmp_path, monkeypatch, caplog):
    manifest_path = tmp_path / "res" / "data.json"
    save = _make_save_with_manifest(str(manifest_path))
    _set_study_roots(save, tmp_path)

    subject_id = "8001"
    original_manifest = {
        "8001": [
            {
                "filename": "2101 (2025-03-02)RAW.csv",
                "labID": "2101",
                "date": "2025-03-02",
                "run": 1,
                "study": "int",
            },
            {
                "filename": "2101 (2025-03-03)RAW.csv",
                "labID": "2101",
                "date": "2025-03-03",
                "run": 2,
                "study": "int",
            },
        ]
    }
    save.manifest = {
        key: [dict(record) for record in value]
        for key, value in original_manifest.items()
    }

    incoming_records = [
        {
            "filename": "2101 (2025-03-01)RAW.csv",
            "labID": "2101",
            "date": "2025-03-01",
            "run": 1,
            "study": "int",
            "file_path": os.path.join(
                save.INT_DIR,
                f"sub-{subject_id}",
                "accel",
                "ses-1",
                f"sub-{subject_id}_ses-1_accel.csv",
            ),
        }
    ]

    def raise_rename_failure(_rename_plan):
        raise OSError("simulated rename failure")

    monkeypatch.setattr(save, "_apply_two_phase_renames", raise_rename_failure)

    with caplog.at_level(logging.WARNING):
        result = save._process_subject_transaction(subject_id, incoming_records)

    assert result == []
    assert save.manifest == original_manifest
    assert "rename_failed" in caplog.text
