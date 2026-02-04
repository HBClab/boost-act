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


def _write_lines(path: Path, lines):
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def test_peek_signature_changes_when_head_differs(tmp_path: Path):
    file_a = tmp_path / "a.csv"
    file_b = tmp_path / "b.csv"
    lines = [f"line-{idx}" for idx in range(1, 11)]
    _write_lines(file_a, lines)

    lines_b = list(lines)
    lines_b[-1] = "line-10-different"
    _write_lines(file_b, lines_b)

    sig_a = Save._peek_signature(str(file_a), n_lines=10)
    sig_b = Save._peek_signature(str(file_b), n_lines=10)

    assert sig_a != sig_b


def test_peek_signature_handles_short_files(tmp_path: Path):
    short_file = tmp_path / "short.csv"
    _write_lines(short_file, ["alpha", "beta", "gamma"])

    sig = Save._peek_signature(str(short_file), n_lines=10)

    assert isinstance(sig, str)
    assert sig


def test_peek_signature_ignores_encoding_errors(tmp_path: Path):
    bad_file = tmp_path / "bad.csv"
    bad_file.write_bytes(b"ok\n\xff\xfe\nend\n")

    sig = Save._peek_signature(str(bad_file), n_lines=10)

    assert isinstance(sig, str)
    assert sig


def test_signature_key_edge_cases():
    assert Save._signature_key({}) == (None, None, None)
    assert Save._signature_key({"size_bytes": 0}) == (0, None, None)
    assert Save._signature_key({"mtime": 0}) == (None, 0, None)
    assert Save._signature_key({"head_hash": ""}) == (None, None, "")
    assert Save._signature_key({"size_bytes": 123, "mtime": 456, "head_hash": "abc"}) == (123, 456, "abc")
    assert Save._signature_key({"size_bytes": 1, "mtime": 2, "head_hash": "x", "extra": "y"}) == (1, 2, "x")
