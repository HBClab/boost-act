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

from code.utils.save import Save


def _make_save(tmp_path: Path) -> Save:
    save = Save.__new__(Save)
    int_dir = tmp_path / "int"
    obs_dir = tmp_path / "obs"
    rdss_dir = tmp_path / "rdss"
    for directory in (int_dir, obs_dir, rdss_dir):
        directory.mkdir(parents=True, exist_ok=True)
    save.INT_DIR = str(int_dir)
    save.OBS_DIR = str(obs_dir)
    save.RDSS_DIR = str(rdss_dir)
    return save


def _write_session_file(root: Path, subject_id: str, session: int, lines):
    file_path = (
        root
        / f"sub-{subject_id}"
        / "accel"
        / f"ses-{session}"
        / f"sub-{subject_id}_ses-{session}_accel.csv"
    )
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return file_path


def test_build_signature_maps_tracks_sessions_and_ignores_non_csv(tmp_path: Path):
    save = _make_save(tmp_path)

    _write_session_file(Path(save.INT_DIR), "8001", 1, ["a", "b", "c"])
    _write_session_file(Path(save.INT_DIR), "8001", 2, ["d", "e", "f"])
    _write_session_file(Path(save.OBS_DIR), "7002", 1, ["x", "y", "z"])

    non_csv = Path(save.INT_DIR) / "sub-8001" / "accel" / "ses-1" / "note.txt"
    non_csv.write_text("ignore", encoding="utf-8")

    subject_session_sig, subject_sig_session = save._build_signature_maps()

    assert set(subject_session_sig.keys()) == {"8001", "7002"}
    assert set(subject_session_sig["8001"].keys()) == {1, 2}
    assert set(subject_session_sig["7002"].keys()) == {1}

    sig_8001_s1 = subject_session_sig["8001"][1]
    sig_8001_s2 = subject_session_sig["8001"][2]
    sig_7002_s1 = subject_session_sig["7002"][1]

    assert sig_8001_s1 != sig_8001_s2
    assert subject_sig_session["8001"][sig_8001_s1] == 1
    assert subject_sig_session["8001"][sig_8001_s2] == 2
    assert subject_sig_session["7002"][sig_7002_s1] == 1
