import importlib
import json
import runpy
import sys
import types

import pytest


def _install_module(monkeypatch, name, module):
    monkeypatch.setitem(sys.modules, name, module)


def _ensure_package(monkeypatch, name):
    package = sys.modules.get(name)
    if package is None:
        package = types.ModuleType(name)
        _install_module(monkeypatch, name, package)
    return package


def test_pipeline_smoke_mocked_dependencies(tmp_path, monkeypatch):
    save_state = {"init_kwargs": None, "remove_calls": []}
    gg_state = {"init_kwargs": None, "ran": False}

    class FakeSave:
        def __init__(self, **kwargs):
            save_state["init_kwargs"] = kwargs

        def save(self):
            return {"8001": [{"filename": "1001 (2025-01-01)RAW.csv"}]}

        @staticmethod
        def remove_symlink_directories(study_dirs):
            save_state["remove_calls"].append(study_dirs)

    class FakeGG:
        def __init__(self, **kwargs):
            gg_state["init_kwargs"] = kwargs

        def run_gg(self):
            gg_state["ran"] = True

    code_pkg = _ensure_package(monkeypatch, "code")
    utils_pkg = _ensure_package(monkeypatch, "act.utils")
    core_pkg = _ensure_package(monkeypatch, "act.core")

    save_mod = types.ModuleType("act.utils.save")
    save_mod.Save = FakeSave
    gg_mod = types.ModuleType("act.core.gg")
    gg_mod.GG = FakeGG

    utils_pkg.save = save_mod
    core_pkg.gg = gg_mod
    code_pkg.utils = utils_pkg
    code_pkg.core = core_pkg

    _install_module(monkeypatch, "act.utils.save", save_mod)
    _install_module(monkeypatch, "act.core.gg", gg_mod)

    pipe_mod = importlib.import_module("act.utils.pipe")
    pipe_mod = importlib.reload(pipe_mod)
    monkeypatch.chdir(tmp_path)
    pipe_mod.Pipe._SYSTEM_PATHS["local"] = {
        "INT_DIR": str(tmp_path / "int"),
        "OBS_DIR": str(tmp_path / "obs"),
        "RDSS_DIR": str(tmp_path / "rdss"),
    }

    pipe = pipe_mod.Pipe(token="token", daysago=1, system="local")
    pipe.run_pipe()

    written_manifest = tmp_path / "res" / "data.json"
    assert written_manifest.exists()
    payload = json.loads(written_manifest.read_text(encoding="utf-8"))
    assert payload == {"8001": [{"filename": "1001 (2025-01-01)RAW.csv"}]}

    assert save_state["init_kwargs"]["symlink"] is False
    assert save_state["init_kwargs"]["token"] == "token"
    assert gg_state["ran"] is True
    assert gg_state["init_kwargs"]["matched"] == payload
    assert save_state["remove_calls"] == [
        [str(tmp_path / "int"), str(tmp_path / "obs")]
    ]


def test_pipeline_manifest_only_skips_ggir(tmp_path, monkeypatch):
    save_state = {"init_kwargs": None, "remove_calls": []}
    gg_state = {"ran": False}

    class FakeSave:
        def __init__(self, **kwargs):
            save_state["init_kwargs"] = kwargs

        def save(self):
            return {"8001": [{"filename": "1001 (2025-01-01)RAW.csv"}]}

        @staticmethod
        def remove_symlink_directories(study_dirs):
            save_state["remove_calls"].append(study_dirs)

    class FakeGG:
        def __init__(self, **kwargs):
            pass

        def run_gg(self):
            gg_state["ran"] = True

    code_pkg = _ensure_package(monkeypatch, "code")
    utils_pkg = _ensure_package(monkeypatch, "act.utils")
    core_pkg = _ensure_package(monkeypatch, "act.core")

    save_mod = types.ModuleType("act.utils.save")
    save_mod.Save = FakeSave
    gg_mod = types.ModuleType("act.core.gg")
    gg_mod.GG = FakeGG

    utils_pkg.save = save_mod
    core_pkg.gg = gg_mod
    code_pkg.utils = utils_pkg
    code_pkg.core = core_pkg

    _install_module(monkeypatch, "act.utils.save", save_mod)
    _install_module(monkeypatch, "act.core.gg", gg_mod)

    pipe_mod = importlib.import_module("act.utils.pipe")
    pipe_mod = importlib.reload(pipe_mod)
    monkeypatch.chdir(tmp_path)
    pipe_mod.Pipe._SYSTEM_PATHS["local"] = {
        "INT_DIR": str(tmp_path / "int"),
        "OBS_DIR": str(tmp_path / "obs"),
        "RDSS_DIR": str(tmp_path / "rdss"),
    }

    pipe = pipe_mod.Pipe(
        token="token", daysago=1, system="local", rebuild_manifest_only=True
    )
    pipe.run_pipe()

    written_manifest = tmp_path / "res" / "data.json"
    assert written_manifest.exists()
    assert gg_state["ran"] is False
    assert save_state["remove_calls"] == [
        [str(tmp_path / "int"), str(tmp_path / "obs")]
    ]


def test_main_smoke_invokes_pipe_and_group(monkeypatch):
    call_state = {"pipe_args": None, "run_pipe": 0, "group_systems": []}

    class FakePipe:
        def __init__(self, token, daysago, system, rebuild_manifest_only=False):
            call_state["pipe_args"] = {
                "token": token,
                "daysago": daysago,
                "system": system,
                "rebuild_manifest_only": rebuild_manifest_only,
            }

        def run_pipe(self):
            call_state["run_pipe"] += 1

    class FakeGroup:
        def __init__(self, system):
            call_state["group_systems"].append(system)

        def plot_person(self):
            call_state["group_systems"].append("person")

        def plot_session(self):
            call_state["group_systems"].append("session")

    code_pkg = _ensure_package(monkeypatch, "code")
    utils_pkg = _ensure_package(monkeypatch, "act.utils")
    pipe_mod = types.ModuleType("act.utils.pipe")
    group_mod = types.ModuleType("act.utils.group")
    pipe_mod.Pipe = FakePipe
    group_mod.Group = FakeGroup
    utils_pkg.pipe = pipe_mod
    utils_pkg.group = group_mod
    code_pkg.utils = utils_pkg

    _install_module(monkeypatch, "act.utils.pipe", pipe_mod)
    _install_module(monkeypatch, "act.utils.group", group_mod)

    monkeypatch.setattr(
        sys,
        "argv",
        [
            "main.py",
            "--daysago",
            "2",
            "--token",
            "token-value",
            "--system",
            "local",
        ],
    )

    with pytest.raises(SystemExit) as exc:
        runpy.run_module("act.main", run_name="__main__")

    assert exc.value.code == 0

    assert call_state["pipe_args"] == {
        "token": "token-value",
        "daysago": 2,
        "system": "local",
        "rebuild_manifest_only": False,
    }
    assert call_state["run_pipe"] == 1
    assert call_state["group_systems"] == ["local", "person", "local", "session"]


def test_main_manifest_only_skips_plotting(monkeypatch):
    call_state = {"pipe_args": None, "run_pipe": 0, "group_inits": 0}

    class FakePipe:
        def __init__(self, token, daysago, system, rebuild_manifest_only=False):
            call_state["pipe_args"] = {
                "token": token,
                "daysago": daysago,
                "system": system,
                "rebuild_manifest_only": rebuild_manifest_only,
            }

        def run_pipe(self):
            call_state["run_pipe"] += 1

    class FakeGroup:
        def __init__(self, system):
            call_state["group_inits"] += 1

        def plot_person(self):
            raise AssertionError("plot_person should not run in manifest-only mode")

        def plot_session(self):
            raise AssertionError("plot_session should not run in manifest-only mode")

    code_pkg = _ensure_package(monkeypatch, "code")
    utils_pkg = _ensure_package(monkeypatch, "act.utils")
    pipe_mod = types.ModuleType("act.utils.pipe")
    group_mod = types.ModuleType("act.utils.group")
    pipe_mod.Pipe = FakePipe
    group_mod.Group = FakeGroup
    utils_pkg.pipe = pipe_mod
    utils_pkg.group = group_mod
    code_pkg.utils = utils_pkg

    _install_module(monkeypatch, "act.utils.pipe", pipe_mod)
    _install_module(monkeypatch, "act.utils.group", group_mod)

    monkeypatch.setattr(
        sys,
        "argv",
        [
            "main.py",
            "--daysago",
            "2",
            "--token",
            "token-value",
            "--system",
            "local",
            "--rebuild-manifest-only",
        ],
    )

    with pytest.raises(SystemExit) as exc:
        runpy.run_module("act.main", run_name="__main__")

    assert exc.value.code == 0
    assert call_state["pipe_args"] == {
        "token": "token-value",
        "daysago": 2,
        "system": "local",
        "rebuild_manifest_only": True,
    }
    assert call_state["run_pipe"] == 1
    assert call_state["group_inits"] == 0


def test_parse_args_valid_rebuild_manifest_only():
    main_mod = importlib.import_module("act.main")
    args = main_mod.build_parser().parse_args(
        [
            "--token",
            "abc123",
            "--daysago",
            "3",
            "--system",
            "vosslnx",
            "--rebuild-manifest-only",
        ]
    )

    assert args.token == "abc123"
    assert args.daysago == 3
    assert args.system == "vosslnx"
    assert args.rebuild_manifest_only is True


@pytest.mark.parametrize(
    "argv",
    [
        ["--token", "abc123", "--daysago", "3"],
        ["--token", "abc123", "--daysago", "-1", "--system", "local"],
        ["--token", "abc123", "--daysago", "three", "--system", "local"],
        ["--token", "", "--daysago", "3", "--system", "local"],
        ["--token", "abc123", "--daysago", "3", "--system", "unknown"],
    ],
)
def test_parse_args_invalid_invocations(argv):
    main_mod = importlib.import_module("act.main")
    parser = main_mod.build_parser()

    with pytest.raises(SystemExit) as exc:
        parser.parse_args(argv)

    assert exc.value.code == 2
