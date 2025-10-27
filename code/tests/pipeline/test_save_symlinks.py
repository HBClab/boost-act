import os
from pathlib import Path

import pytest

from code.utils.save import Save


def _build_subject_accel(tmp_path: Path, study_root: str, subject_id: str):
    base_dir = tmp_path / study_root
    subject_accel_dir = base_dir / f"sub-{subject_id}" / "accel"
    session_one = subject_accel_dir / "ses-1"
    session_two_nested = subject_accel_dir / "ses-2" / "nested"

    session_one.mkdir(parents=True, exist_ok=True)
    session_two_nested.mkdir(parents=True, exist_ok=True)

    csv_one = session_one / f"sub-{subject_id}_ses-1_accel.csv"
    csv_two = session_two_nested / f"sub-{subject_id}_ses-2_accel.csv"
    csv_three = session_two_nested / f"sub-{subject_id}_ses-2_accel-extra.csv"

    csv_one.write_text("run-1", encoding="utf-8")
    csv_two.write_text("run-2", encoding="utf-8")
    csv_three.write_text("run-2-extra", encoding="utf-8")

    return base_dir, subject_accel_dir, [csv_one, csv_two, csv_three]


@pytest.mark.parametrize(
    ("study_root", "subject_id"),
    (("int-study", "8001"), ("obs-study", "7050")),
)
def test_refresh_subject_symlinks_creates_subject_all_directory(tmp_path, study_root, subject_id):
    _, subject_accel_dir, csv_paths = _build_subject_accel(tmp_path, study_root, subject_id)

    saver = Save.__new__(Save)
    saver._refresh_subject_symlinks(str(csv_paths[0]))

    all_dir = subject_accel_dir / "all"
    assert all_dir.is_dir(), "Expected per-subject accel/all directory to be created"

    expected_rel_paths = {os.path.relpath(str(path), str(subject_accel_dir)) for path in csv_paths}

    for relative in expected_rel_paths:
        symlink_path = all_dir / relative
        assert symlink_path.is_symlink(), f"Missing symlink for {relative}"
        assert os.path.samefile(symlink_path, subject_accel_dir / relative)

    assert not (all_dir / "all").exists(), "Symlink tree should not duplicate itself recursively"


def test_remove_symlink_directories_cleans_up_subject_symlinks(tmp_path):
    int_base, int_accel_dir, int_csvs = _build_subject_accel(tmp_path, "int-study", "8001")
    obs_base, obs_accel_dir, obs_csvs = _build_subject_accel(tmp_path, "obs-study", "7050")

    saver = Save.__new__(Save)
    for csv_path in int_csvs + obs_csvs:
        saver._refresh_subject_symlinks(str(csv_path))

    assert (int_accel_dir / "all").exists()
    assert (obs_accel_dir / "all").exists()

    Save.remove_symlink_directories([str(int_base), str(obs_base)])

    assert not (int_accel_dir / "all").exists()
    assert not (obs_accel_dir / "all").exists()

    for csv_path in int_csvs + obs_csvs:
        assert csv_path.exists(), "Cleanup should leave original CSV artefacts in place"
