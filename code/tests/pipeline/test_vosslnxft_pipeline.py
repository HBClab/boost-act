import os
import sys
from pathlib import Path

repo_root = Path(__file__).resolve().parents[4]
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

import pytest

from code.core.gg import GG
from code.utils.group import Group
from code.utils.pipe import Pipe
from code.utils.save import Save


@pytest.fixture
def fake_vosslnxft_paths(tmp_path, monkeypatch):
    """Provide isolated filesystem mounts for the vosslnxft system."""
    original = dict(Pipe._SYSTEM_PATHS["vosslnxft"])

    int_dir = tmp_path / "act-int-final-test-1"
    obs_dir = tmp_path / "act-obs-test"
    rdss_dir = tmp_path / "rdss"

    for path in (int_dir, obs_dir, rdss_dir):
        path.mkdir(parents=True, exist_ok=True)

    # Ensure derivatives directories exist so Group() can list them.
    (int_dir / "derivatives" / "GGIR-3.2.6").mkdir(parents=True, exist_ok=True)
    (obs_dir / "derivatives" / "GGIR-3.2.6").mkdir(parents=True, exist_ok=True)

    monkeypatch.setitem(
        Pipe._SYSTEM_PATHS,
        "vosslnxft",
        {
            "INT_DIR": str(int_dir),
            "OBS_DIR": str(obs_dir),
            "RDSS_DIR": str(rdss_dir),
        },
    )

    yield {
        "INT_DIR": str(int_dir),
        "OBS_DIR": str(obs_dir),
        "RDSS_DIR": str(rdss_dir),
    }

    monkeypatch.setitem(Pipe._SYSTEM_PATHS, "vosslnxft", original)


def test_move_files_copies_into_final_test_root(tmp_path, fake_vosslnxft_paths):
    """Save._move_files should copy artefacts into the vosslnxft intervention root."""
    save = Save.__new__(Save)
    save.RDSS_DIR = fake_vosslnxft_paths["RDSS_DIR"]
    save.INT_DIR = fake_vosslnxft_paths["INT_DIR"]
    save.OBS_DIR = fake_vosslnxft_paths["OBS_DIR"]

    rdss_file = Path(fake_vosslnxft_paths["RDSS_DIR"]) / "sub-8001-run1.csv"
    rdss_file.write_text("synthetic-data", encoding="utf-8")

    destination = (
        Path(fake_vosslnxft_paths["INT_DIR"])
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    matches = {
        "8001": [
            {
                "filename": rdss_file.name,
                "file_path": str(destination),
            }
        ]
    }

    save._move_files(matches)

    assert destination.exists(), "Expected file to be copied into new intervention root"
    assert destination.read_text(encoding="utf-8") == "synthetic-data"


def test_determine_location_builds_final_test_paths(fake_vosslnxft_paths):
    """Save._determine_location should target the new derivatives roots when configured for vosslnxft."""
    save = Save.__new__(Save)
    save.INT_DIR = fake_vosslnxft_paths["INT_DIR"]
    save.OBS_DIR = fake_vosslnxft_paths["OBS_DIR"]

    matches = {
        "8001": [
            {"study": "int", "run": 1},
        ],
        "7050": [
            {"study": "obs", "run": 2},
        ],
    }

    save._determine_location(matches)

    expected_int_path = (
        Path(fake_vosslnxft_paths["INT_DIR"])
        / "sub-8001"
        / "accel"
        / "ses-1"
        / "sub-8001_ses-1_accel.csv"
    )
    expected_obs_path = (
        Path(fake_vosslnxft_paths["OBS_DIR"])
        / "sub-7050"
        / "accel"
        / "ses-2"
        / "sub-7050_ses-2_accel.csv"
    )

    assert matches["8001"][0]["file_path"] == str(expected_int_path)
    assert matches["7050"][0]["file_path"] == str(expected_obs_path)


def test_gg_derivative_path_for_final_test(fake_vosslnxft_paths):
    """GG should point at the unified derivatives directory."""
    gg = GG(
        matched={},
        intdir=fake_vosslnxft_paths["INT_DIR"],
        obsdir=fake_vosslnxft_paths["OBS_DIR"],
        system="vosslnxft",
    )

    assert gg.DERIVATIVES == "derivatives/GGIR-3.2.6/"
    assert gg.INTDIR == fake_vosslnxft_paths["INT_DIR"] + "/"
    assert gg.OBSDIR == fake_vosslnxft_paths["OBS_DIR"] + "/"


def test_group_paths_point_to_final_test_derivatives(fake_vosslnxft_paths):
    """Group plotting logic should scan the new derivatives folders."""
    group = Group(system="vosslnxft")

    expected_obs = os.path.join(
        fake_vosslnxft_paths["OBS_DIR"], "derivatives", "GGIR-3.2.6"
    )
    expected_int = os.path.join(
        fake_vosslnxft_paths["INT_DIR"], "derivatives", "GGIR-3.2.6"
    )

    assert expected_obs in group.paths
    assert expected_int in group.paths
