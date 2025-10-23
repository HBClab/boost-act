"""
Project package namespace that also exposes the stdlib `code` helpers so modules
like `pdb` continue to work when this package shadows Python's builtin `code`.
"""

from __future__ import annotations

import importlib.util
import sys
import sysconfig
from pathlib import Path


def _load_stdlib_code() -> object:
    """Load the standard-library `code` module without triggering recursive imports."""
    stdlib_dir = Path(sysconfig.get_path("stdlib"))
    stdlib_code = stdlib_dir / "code.py"
    if not stdlib_code.exists():
        raise RuntimeError(f"Unable to locate stdlib code.py at {stdlib_code}")

    spec = importlib.util.spec_from_file_location("_stdlib_code", stdlib_code)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


_STDLIB_CODE = _load_stdlib_code()

# Register the stdlib module under an internal name so it can be reused.
sys.modules.setdefault("_stdlib_code", _STDLIB_CODE)

# Re-export stdlib attributes that our package doesn't define so callers such
# as pdb can access InteractiveConsole, compile_command, etc.
for _attr in dir(_STDLIB_CODE):
    if _attr.startswith("_") or _attr in globals():
        continue
    globals()[_attr] = getattr(_STDLIB_CODE, _attr)

del _attr
