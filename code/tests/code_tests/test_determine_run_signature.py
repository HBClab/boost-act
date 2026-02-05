import datetime as dt
import os
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
    save._signature_tsv_path = lambda: str(tmp_path / "logs" / "session_fingerprint.tsv")
    return save


def _write_file(path: Path, content: str, mtime: int) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    os.utime(path, (mtime, mtime))
    return path


def test_determine_run_reuses_signature_session(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8001"
    fixed_mtime = 1_700_000_000

    _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-2" / f"sub-{subject_id}_ses-2_accel.csv",
        "header\nrow\n",
        fixed_mtime,
    )
    _write_file(Path(save.RDSS_DIR) / "match.csv", "header\nrow\n", fixed_mtime)

    matches = {
        subject_id: [
            {"filename": "match.csv", "date": dt.datetime(2024, 1, 1)},
        ]
    }

    updated = save._determine_run(matches)
    record = updated[subject_id][0]
    assert record["run"] == 2
    assert record["pending_gap_fill"] is False
    assert record["proposed_rank"] == 1


def test_determine_run_reorders_when_signature_matches_different_session(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8002"
    fixed_mtime = 1_700_000_111

    _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-2" / f"sub-{subject_id}_ses-2_accel.csv",
        "sig\nrow\n",
        fixed_mtime,
    )
    _write_file(Path(save.RDSS_DIR) / "sig.csv", "sig\nrow\n", fixed_mtime)
    _write_file(Path(save.RDSS_DIR) / "other.csv", "other\nrow\n", fixed_mtime + 1)

    matches = {
        subject_id: [
            {"filename": "sig.csv", "date": dt.datetime(2024, 1, 1)},
            {"filename": "other.csv", "date": dt.datetime(2024, 1, 2)},
        ]
    }

    updated = save._determine_run(matches)
    matched = next(record for record in updated[subject_id] if record["filename"] == "sig.csv")
    pending = next(record for record in updated[subject_id] if record["filename"] == "other.csv")

    assert matched["proposed_rank"] == 1
    assert matched["run"] == 2
    assert matched["pending_gap_fill"] is False
    assert pending["pending_gap_fill"] is False
    assert pending["run"] == 1


def test_determine_run_marks_unmatched_pending(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8003"
    _write_file(Path(save.RDSS_DIR) / "new.csv", "new\nrow\n", 1_700_000_222)

    matches = {
        subject_id: [
            {"filename": "new.csv", "date": dt.datetime(2024, 1, 3)},
        ]
    }

    updated = save._determine_run(matches)
    record = updated[subject_id][0]
    assert record["pending_gap_fill"] is False
    assert record["proposed_rank"] == 1
    assert record["run"] == 1


def test_determine_run_reassigns_on_tsv_conflict(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8004"
    _write_file(Path(save.RDSS_DIR) / "new.csv", "new\nrow\n", 1_700_000_333)

    save._append_signature_tsv(
        [
            {
                "subject_id": subject_id,
                "study": "int",
                "proposed_rank": "1",
                "final_rank": "1",
                "signature_match": "exact",
                "action": "reuse",
                "rdss_filename": "prior.csv",
                "source": "tsv",
            }
        ]
    )

    matches = {
        subject_id: [
            {"filename": "new.csv", "date": dt.datetime(2024, 1, 1)},
        ]
    }

    updated = save._determine_run(matches)
    record = updated[subject_id][0]
    assert record["run"] == 1
    assert record["pending_gap_fill"] is False
    assert record["action"] == "reassign_conflict"
    assert save.session_renames == [
        {
            "subject_id": subject_id,
            "study": "int",
            "from_session": 1,
            "to_session": 2,
        }
    ]


def test_determine_run_gap_fill_assigns_smallest_free_sessions(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8005"
    fixed_mtime = 1_700_000_444

    _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-1" / f"sub-{subject_id}_ses-1_accel.csv",
        "one\nrow\n",
        fixed_mtime,
    )
    _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-3" / f"sub-{subject_id}_ses-3_accel.csv",
        "three\nrow\n",
        fixed_mtime + 1,
    )
    _write_file(Path(save.RDSS_DIR) / "first.csv", "first\nrow\n", fixed_mtime + 2)
    _write_file(Path(save.RDSS_DIR) / "second.csv", "second\nrow\n", fixed_mtime + 3)

    matches = {
        subject_id: [
            {"filename": "first.csv", "date": dt.datetime(2024, 1, 1)},
            {"filename": "second.csv", "date": dt.datetime(2024, 1, 2)},
        ]
    }

    updated = save._determine_run(matches)
    runs = [record["run"] for record in updated[subject_id]]
    assert runs == [2, 4]


def test_determine_run_logs_signature_rows_for_mixed_actions(tmp_path: Path):
    save = _make_save(tmp_path)
    subject_id = "8010"
    fixed_mtime = 1_700_000_555

    _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-3" / f"sub-{subject_id}_ses-3_accel.csv",
        "sig\nrow\n",
        fixed_mtime,
    )
    _write_file(Path(save.RDSS_DIR) / "incoming.csv", "incoming\nrow\n", fixed_mtime + 1)
    _write_file(Path(save.RDSS_DIR) / "sig.csv", "sig\nrow\n", fixed_mtime)
    _write_file(Path(save.RDSS_DIR) / "fresh.csv", "fresh\nrow\n", fixed_mtime + 2)

    save._append_signature_tsv(
        [
            {
                "subject_id": subject_id,
                "study": "int",
                "proposed_rank": "1",
                "final_rank": "1",
                "signature_match": "exact",
                "action": "reuse",
                "rdss_filename": "prior.csv",
                "source": "tsv",
            }
        ]
    )

    matches = {
        subject_id: [
            {"filename": "incoming.csv", "date": dt.datetime(2024, 1, 1)},
            {"filename": "sig.csv", "date": dt.datetime(2024, 1, 2)},
            {"filename": "fresh.csv", "date": dt.datetime(2024, 1, 3)},
        ]
    }

    save._determine_run(matches)
    rows = save._load_signature_tsv()
    logged = {
        row["rdss_filename"]: row
        for row in rows
        if row.get("subject_id") == subject_id
        and row.get("rdss_filename") in {"incoming.csv", "sig.csv", "fresh.csv"}
    }

    assert logged["incoming.csv"]["action"] == "reassign_conflict"
    assert logged["incoming.csv"]["final_rank"] == "1"
    assert logged["sig.csv"]["action"] == "reuse"
    assert logged["sig.csv"]["signature_match"] == "exact"
    assert logged["fresh.csv"]["action"] == "assign_new"
    assert logged["fresh.csv"]["final_rank"] == "4"


def test_determine_run_end_to_end_dry_slice(tmp_path: Path):
    save = _make_save(tmp_path)
    save.symlink = False
    subject_id = "8011"
    fixed_mtime = 1_700_000_666

    existing_sig = _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-2" / f"sub-{subject_id}_ses-2_accel.csv",
        "sig\nrow\n",
        fixed_mtime,
    )
    existing_prior = _write_file(
        Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-1" / f"sub-{subject_id}_ses-1_accel.csv",
        "prior\nrow\n",
        fixed_mtime - 1,
    )

    _write_file(Path(save.RDSS_DIR) / "incoming.csv", "incoming\nrow\n", fixed_mtime + 1)
    _write_file(Path(save.RDSS_DIR) / "sig.csv", "sig\nrow\n", fixed_mtime)
    _write_file(Path(save.RDSS_DIR) / "fresh.csv", "fresh\nrow\n", fixed_mtime + 2)

    save._append_signature_tsv(
        [
            {
                "subject_id": subject_id,
                "study": "int",
                "proposed_rank": "1",
                "final_rank": "1",
                "signature_match": "exact",
                "action": "reuse",
                "rdss_filename": "prior.csv",
                "source": "tsv",
            }
        ]
    )

    matches = {
        subject_id: [
            {"filename": "incoming.csv", "date": dt.datetime(2024, 1, 1)},
            {"filename": "sig.csv", "date": dt.datetime(2024, 1, 2)},
            {"filename": "fresh.csv", "date": dt.datetime(2024, 1, 3)},
        ]
    }

    updated = save._determine_run(matches)
    updated = save._determine_study(updated)
    updated = save._determine_location(updated)
    save._move_files(updated)

    assert existing_sig.exists()
    assert existing_prior.exists()

    renamed_prior = Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-3" / f"sub-{subject_id}_ses-3_accel.csv"
    assert renamed_prior.exists()

    incoming_path = Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-1" / f"sub-{subject_id}_ses-1_accel.csv"
    fresh_path = Path(save.INT_DIR) / f"sub-{subject_id}" / "accel" / "ses-4" / f"sub-{subject_id}_ses-4_accel.csv"
    assert incoming_path.exists()
    assert fresh_path.exists()

    rows = save._load_signature_tsv()
    logged = {
        row["rdss_filename"]: row
        for row in rows
        if row.get("subject_id") == subject_id
        and row.get("rdss_filename") in {"incoming.csv", "sig.csv", "fresh.csv"}
    }
    assert logged["incoming.csv"]["action"] == "reassign_conflict"
    assert logged["incoming.csv"]["final_rank"] == "1"
    assert logged["sig.csv"]["action"] == "reuse"
    assert logged["sig.csv"]["final_rank"] == "2"
    assert logged["fresh.csv"]["action"] == "assign_new"
    assert logged["fresh.csv"]["final_rank"] == "4"
