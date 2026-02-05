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
    save.INT_DIR = str(tmp_path / "int")
    save.OBS_DIR = str(tmp_path / "obs")
    save.RDSS_DIR = str(tmp_path / "rdss")
    return save


def test_load_signature_tsv_missing_file_returns_empty(tmp_path: Path):
    save = _make_save(tmp_path)
    missing = tmp_path / "logs" / "session_fingerprint.tsv"

    rows = save._load_signature_tsv(tsv_path=str(missing))

    assert rows == []


def test_signature_tsv_round_trip_preserves_columns(tmp_path: Path):
    save = _make_save(tmp_path)
    tsv_path = tmp_path / "logs" / "session_fingerprint.tsv"
    rows = [
        {
            "subject_id": "8001",
            "study": "int",
            "proposed_rank": "1",
            "final_rank": "2",
            "signature_match": "none",
            "action": "assign_new",
            "rdss_filename": "file_a.csv",
            "source": "fs",
        },
        {
            "subject_id": "7002",
            "study": "obs",
            "proposed_rank": "1",
            "final_rank": "1",
            "signature_match": "exact",
            "action": "reuse",
            "rdss_filename": "file_b.csv",
            "source": "tsv",
        },
    ]

    save._append_signature_tsv(rows, tsv_path=str(tsv_path))
    loaded = save._load_signature_tsv(tsv_path=str(tsv_path))

    assert loaded == rows
