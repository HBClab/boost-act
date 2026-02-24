from __future__ import annotations

from datetime import datetime
import logging

from act.utils.save import Save


def _make_save_with_manifest(path: str):
    save = Save.__new__(Save)
    save.manifest_path = path
    save.manifest = {}
    save.logger = logging.getLogger("act.utils.save")
    return save


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
