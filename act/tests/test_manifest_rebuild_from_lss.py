from __future__ import annotations

import logging

import pytest

from act.utils.save import Save


def _make_save_for_lss(tmp_path):
    save = Save.__new__(Save)
    save.logger = logging.getLogger("act.utils.save")
    save.INT_DIR = str(tmp_path / "int")
    save.OBS_DIR = str(tmp_path / "obs")
    save.RDSS_DIR = str(tmp_path / "rdss")
    save.token = "test-token"
    save.daysago = 1
    return save


def _touch(path, contents="x"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")


def test_discover_lss_sessions_derives_subject_study_and_run(tmp_path):
    save = _make_save_for_lss(tmp_path)

    _touch(
        tmp_path
        / "int"
        / "sub-8001"
        / "accel"
        / "ses-2"
        / "sub-8001_ses-2_accel.csv"
    )
    _touch(
        tmp_path
        / "int"
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    _touch(
        tmp_path
        / "obs"
        / "sub-7001"
        / "accel"
        / "ses-1"
        / "sub-7001_ses-1_accel.csv"
    )

    discovered, conflicts = save.discover_lss_sessions()

    assert conflicts == {}
    assert set(discovered.keys()) == {"8001", "7001"}

    int_records = discovered["8001"]
    assert [record["run"] for record in int_records] == [1, 2]
    assert [record["study"] for record in int_records] == ["int", "int"]
    assert [record["subject_id"] for record in int_records] == ["8001", "8001"]

    obs_records = discovered["7001"]
    assert len(obs_records) == 1
    assert obs_records[0]["run"] == 1
    assert obs_records[0]["study"] == "obs"
    assert obs_records[0]["subject_id"] == "7001"


def test_discover_lss_sessions_flags_multi_csv_session_conflict(tmp_path):
    save = _make_save_for_lss(tmp_path)

    session_dir = tmp_path / "int" / "sub-8002" / "accel" / "ses-1"
    _touch(session_dir / "sub-8002_ses-1_accel.csv")
    _touch(session_dir / "sub-8002_ses-1_alt_accel.csv")

    discovered, conflicts = save.discover_lss_sessions()

    assert discovered == {}
    assert "8002" in conflicts
    assert len(conflicts["8002"]) == 1
    assert "multiple accel csv candidates" in conflicts["8002"][0]


def test_resolve_subject_lab_mapping_success(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    monkeypatch.setattr(
        save,
        "_fetch_redcap_subject_lab_rows",
        lambda: [
            {"boost_id": 8001, "lab_id": 1201},
            {"boost_id": "7001", "lab_id": "2201"},
        ],
    )

    mapping = save.resolve_subject_lab_mapping(["8001", "7001"])

    assert mapping == {"7001": "2201", "8001": "1201"}


def test_resolve_subject_lab_mapping_missing_subject_strict_error(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    monkeypatch.setattr(
        save,
        "_fetch_redcap_subject_lab_rows",
        lambda: [{"boost_id": 8001, "lab_id": 1201}],
    )

    with pytest.raises(ValueError) as exc:
        save.resolve_subject_lab_mapping(["8001", "9999"])

    assert "Missing RedCap subject->lab mappings" in str(exc.value)
    assert "9999" in str(exc.value)


def test_resolve_rdss_session_metadata_success(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    discovered = {
        "8001": [
            {"subject_id": "8001", "study": "int", "run": 1},
            {"subject_id": "8001", "study": "int", "run": 2},
        ]
    }
    subject_to_lab = {"8001": "1201"}

    monkeypatch.setattr(
        save,
        "_list_rdss_metadata_rows",
        lambda: [
            {"filename": "1201 (2025-03-01)RAW.csv", "labID": "1201", "date": "2025-03-01"},
            {"filename": "1201 (2025-03-02)RAW.csv", "labID": "1201", "date": "2025-03-02"},
        ],
    )

    resolved = save.resolve_rdss_session_metadata(discovered, subject_to_lab)

    assert list(resolved.keys()) == ["8001"]
    assert [row["run"] for row in resolved["8001"]] == [1, 2]
    assert [row["filename"] for row in resolved["8001"]] == [
        "1201 (2025-03-01)RAW.csv",
        "1201 (2025-03-02)RAW.csv",
    ]
    assert [row["labID"] for row in resolved["8001"]] == ["1201", "1201"]
    assert [row["date"] for row in resolved["8001"]] == ["2025-03-01", "2025-03-02"]


def test_resolve_rdss_session_metadata_strict_failure_when_unresolved(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    discovered = {
        "8001": [
            {"subject_id": "8001", "study": "int", "run": 1},
            {"subject_id": "8001", "study": "int", "run": 2},
        ]
    }
    subject_to_lab = {"8001": "1201"}

    monkeypatch.setattr(
        save,
        "_list_rdss_metadata_rows",
        lambda: [
            {"filename": "1201 (2025-03-01)RAW.csv", "labID": "1201", "date": "2025-03-01"},
        ],
    )

    with pytest.raises(ValueError) as exc:
        save.resolve_rdss_session_metadata(discovered, subject_to_lab)

    message = str(exc.value)
    assert "Unresolved RDSS metadata" in message
    assert "subject=8001 run=2 labID=1201" in message


def test_rebuild_manifest_payload_from_lss_deterministic_output(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    monkeypatch.setattr(
        save,
        "discover_lss_sessions",
        lambda: (
            {
                "8001": [
                    {
                        "subject_id": "8001",
                        "study": "int",
                        "run": 2,
                        "file_path": "/lss/int/sub-8001/accel/ses-2/sub-8001_ses-2_accel.csv",
                    },
                    {
                        "subject_id": "8001",
                        "study": "int",
                        "run": 1,
                        "file_path": "/lss/int/sub-8001/accel/ses-1/sub-8001_ses-1_accel.csv",
                    },
                ],
                "7001": [
                    {
                        "subject_id": "7001",
                        "study": "obs",
                        "run": 1,
                        "file_path": "/lss/obs/sub-7001/accel/ses-1/sub-7001_ses-1_accel.csv",
                    }
                ],
            },
            {},
        ),
    )
    monkeypatch.setattr(
        save,
        "_fetch_redcap_subject_lab_rows",
        lambda: [
            {"boost_id": "7001", "lab_id": "2201"},
            {"boost_id": "8001", "lab_id": "1201"},
        ],
    )
    monkeypatch.setattr(
        save,
        "_list_rdss_metadata_rows",
        lambda: [
            {"filename": "2201 (2025-02-10)RAW.csv", "labID": "2201", "date": "2025-02-10"},
            {"filename": "1201 (2025-03-02)RAW.csv", "labID": "1201", "date": "2025-03-02"},
            {"filename": "1201 (2025-03-01)RAW.csv", "labID": "1201", "date": "2025-03-01"},
        ],
    )

    payload = save.rebuild_manifest_payload_from_lss()

    assert list(payload.keys()) == ["7001", "8001"]
    assert [record["run"] for record in payload["8001"]] == [1, 2]
    assert [record["filename"] for record in payload["8001"]] == [
        "1201 (2025-03-01)RAW.csv",
        "1201 (2025-03-02)RAW.csv",
    ]
    assert payload["8001"][0]["file_path"].endswith("ses-1/sub-8001_ses-1_accel.csv")
    assert payload["8001"][1]["file_path"].endswith("ses-2/sub-8001_ses-2_accel.csv")


def test_rebuild_manifest_payload_from_lss_aggregates_strict_errors(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)

    monkeypatch.setattr(
        save,
        "discover_lss_sessions",
        lambda: (
            {
                "8001": [
                    {
                        "subject_id": "8001",
                        "study": "int",
                        "run": 1,
                        "file_path": "/lss/int/sub-8001/accel/ses-1/sub-8001_ses-1_accel.csv",
                    }
                ],
                "8002": [
                    {
                        "subject_id": "8002",
                        "study": "int",
                        "run": 2,
                        "file_path": "/lss/int/sub-8002/accel/ses-2/sub-8002_ses-2_accel.csv",
                    }
                ],
                "7001": [
                    {
                        "subject_id": "7001",
                        "study": "obs",
                        "run": 1,
                        "file_path": "/lss/obs/sub-7001/accel/ses-1/sub-7001_ses-1_accel.csv",
                    }
                ],
            },
            {"7001": ["multiple accel csv candidates in /lss/obs/sub-7001/accel/ses-1"]},
        ),
    )
    monkeypatch.setattr(
        save,
        "_fetch_redcap_subject_lab_rows",
        lambda: [{"boost_id": "8001", "lab_id": "1201"}],
    )
    monkeypatch.setattr(
        save,
        "_list_rdss_metadata_rows",
        lambda: [{"filename": "1201 (2025-03-01)RAW.csv", "labID": "1201", "date": "2025-03-01"}],
    )

    with pytest.raises(ValueError) as exc:
        save.rebuild_manifest_payload_from_lss()

    message = str(exc.value)
    assert "Manifest rebuild failed due to strict conflict(s)" in message
    assert "subject=7001:" in message
    assert "multiple accel csv candidates" in message
    assert "subject=8002:" in message
    assert "missing RedCap subject->lab mapping" in message


def test_atomic_manifest_write_preserves_existing_manifest_on_failure(tmp_path, monkeypatch):
    save = _make_save_for_lss(tmp_path)
    manifest_path = tmp_path / "res" / "data.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text('{"existing": [{"run": 1}]}', encoding="utf-8")

    original_contents = manifest_path.read_text(encoding="utf-8")

    def fail_replace(src, dst):
        raise OSError("simulated replace failure")

    monkeypatch.setattr("act.utils.save.os.replace", fail_replace)

    with pytest.raises(OSError):
        save._atomic_write_manifest(
            {"new": [{"run": 1}]},
            str(manifest_path),
        )

    assert manifest_path.read_text(encoding="utf-8") == original_contents
