import os
import shutil
import logging

import pytest

from act.utils.save import Save


def _make_save(temp_study_roots):
    save = Save.__new__(Save)
    save.INT_DIR = os.fspath(temp_study_roots["int"])
    save.OBS_DIR = os.fspath(temp_study_roots["obs"])
    save.RDSS_DIR = os.fspath(temp_study_roots["rdss"])
    save.symlink = False
    save.matches = {}
    save.dupes = []
    save.manifest = {}
    save.logger = logging.getLogger("act.utils.save")
    return save


@pytest.mark.parametrize(
    "subject_id,expected_study,edge_case",
    [
        ("8001", "int", "duplicate_date"),
        ("7001", "obs", "duplicate_date"),
        ("8002", "int", "noop_existing"),
        ("7002", "obs", "noop_existing"),
    ],
)
def test_save_edge_cases_matrix(
    temp_study_roots, subject_id, expected_study, edge_case
):
    save = _make_save(temp_study_roots)

    matches = {
        subject_id: [
            {
                "filename": "1001 (2025-01-01)RAW.csv",
                "labID": "1001",
                "date": "2025-01-01",
            },
            {
                "filename": "1002 (2025-01-01)RAW.csv",
                "labID": "1002",
                "date": "2025-01-01" if edge_case == "duplicate_date" else "2025-01-02",
            },
        ]
    }

    save._determine_run(matches)

    if edge_case == "duplicate_date":
        assert matches[subject_id] == []
        save._determine_study(matches)
        save._determine_location(matches)
        assert matches[subject_id] == []
        return

    save._determine_study(matches)
    save._determine_location(matches)

    runs = [record["run"] for record in matches[subject_id]]
    studies = {record["study"] for record in matches[subject_id]}
    paths = [record["file_path"] for record in matches[subject_id]]

    assert runs == [1, 2]
    assert studies == {expected_study}
    assert any("/ses-1/" in path for path in paths)
    assert any("/ses-2/" in path for path in paths)

    root = os.fspath(temp_study_roots[expected_study])
    for path in paths:
        assert path.startswith(root)
        assert os.path.basename(path).startswith(f"sub-{subject_id}_ses-")
        assert path.endswith("_accel.csv")

    # Re-running run assignment should be deterministic.
    save._determine_run(matches)
    assert [record["run"] for record in matches[subject_id]] == [1, 2]

    if edge_case == "noop_existing":
        first_record = matches[subject_id][0]
        source = os.path.join(save.RDSS_DIR, first_record["filename"])
        destination = first_record["file_path"]
        os.makedirs(os.path.dirname(source), exist_ok=True)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        with open(source, "w", encoding="utf-8") as handle:
            handle.write("new")
        with open(destination, "w", encoding="utf-8") as handle:
            handle.write("existing")

        save._move_files({subject_id: [first_record]})

        with open(destination, "r", encoding="utf-8") as handle:
            assert handle.read() == "existing"


def test_move_files_partial_copy_failure_continues(temp_study_roots, monkeypatch):
    save = _make_save(temp_study_roots)
    subject_id = "8009"
    first_name = "2001 (2025-02-01)RAW.csv"
    second_name = "2002 (2025-02-02)RAW.csv"

    first_source = os.path.join(save.RDSS_DIR, first_name)
    second_source = os.path.join(save.RDSS_DIR, second_name)
    os.makedirs(save.RDSS_DIR, exist_ok=True)
    with open(first_source, "w", encoding="utf-8") as handle:
        handle.write("first")
    with open(second_source, "w", encoding="utf-8") as handle:
        handle.write("second")

    first_dest = os.path.join(
        save.INT_DIR,
        f"sub-{subject_id}",
        "accel",
        "ses-1",
        f"sub-{subject_id}_ses-1_accel.csv",
    )
    second_dest = os.path.join(
        save.INT_DIR,
        f"sub-{subject_id}",
        "accel",
        "ses-2",
        f"sub-{subject_id}_ses-2_accel.csv",
    )

    matches = {
        subject_id: [
            {"filename": first_name, "file_path": first_dest},
            {"filename": second_name, "file_path": second_dest},
        ]
    }

    original_copy = shutil.copy

    def flaky_copy(src, dst):
        if src == first_source:
            raise OSError("simulated copy failure")
        return original_copy(src, dst)

    monkeypatch.setattr("act.utils.save.shutil.copy", flaky_copy)

    save._move_files(matches)

    assert not os.path.exists(first_dest)
    assert os.path.exists(second_dest)
    with open(second_dest, "r", encoding="utf-8") as handle:
        assert handle.read() == "second"


@pytest.mark.parametrize(
    "subject_id,study_key",
    [
        ("8003", "int"),
        ("7003", "obs"),
    ],
)
def test_manifest_driven_run_stability(temp_study_roots, subject_id, study_key):
    save = _make_save(temp_study_roots)
    save.manifest = {
        subject_id: [
            {
                "filename": "3001 (2025-04-01)RAW.csv",
                "labID": "3001",
                "date": "2025-04-01",
                "run": 1,
                "study": study_key,
            },
            {
                "filename": "3002 (2025-04-02)RAW.csv",
                "labID": "3002",
                "date": "2025-04-02",
                "run": 2,
                "study": study_key,
            },
        ]
    }

    incoming = {
        subject_id: [
            {
                "filename": "3002 (2025-04-02)RAW.csv",
                "labID": "3002",
                "date": "2025-04-02",
            }
        ]
    }

    first = save._determine_run(incoming)
    second = save._determine_run(incoming)

    assert first[subject_id][0]["run"] == 2
    assert second[subject_id][0]["run"] == 2

    save._determine_study(first)
    save._determine_location(first)

    target_root = os.fspath(temp_study_roots[study_key])
    assert first[subject_id][0]["file_path"].startswith(target_root)
    assert "/ses-2/" in first[subject_id][0]["file_path"]


@pytest.mark.parametrize(
    "subject_id,study_key",
    [
        ("8004", "int"),
        ("7004", "obs"),
    ],
)
def test_manifest_gap_shift_backfill_assigns_dense_session(
    temp_study_roots,
    subject_id,
    study_key,
):
    save = _make_save(temp_study_roots)
    save.manifest = {
        subject_id: [
            {
                "filename": "4001 (2025-05-01)RAW.csv",
                "labID": "4001",
                "date": "2025-05-01",
                "run": 1,
                "study": study_key,
            },
            {
                "filename": "4002 (2025-05-03)RAW.csv",
                "labID": "4002",
                "date": "2025-05-03",
                "run": 3,
                "study": study_key,
            },
        ]
    }

    incoming = {
        subject_id: [
            {
                "filename": "4003 (2025-05-02)RAW.csv",
                "labID": "4003",
                "date": "2025-05-02",
            }
        ]
    }

    result = save._determine_run(incoming)

    assert result[subject_id][0]["run"] == 2

    save._determine_study(result)
    save._determine_location(result)

    target_root = os.fspath(temp_study_roots[study_key])
    path = result[subject_id][0]["file_path"]
    assert path.startswith(target_root)
    assert "/ses-2/" in path
