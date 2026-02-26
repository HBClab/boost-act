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
