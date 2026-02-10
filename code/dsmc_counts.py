"""DSMC session counts report utility.

Standalone module (not wired into the main pipeline) that scans intervention and
observational datasets to count available session files, optionally compares
against expected counts, and writes a CSV report.
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional

LOGGER = logging.getLogger(__name__)

SESSION_DIR_RE = re.compile(r"^ses-\d+$")
ACCEL_FILENAME_RE = re.compile(r"^sub-(\d+)_ses-(\d+)_accel\.csv$")


def configure_logging(log_file: str | None = None) -> None:
    """Configure logging to match the style used in code/main.py."""
    if logging.getLogger().handlers:
        return

    log_file = log_file or os.getenv("LOG_FILE")
    handlers: List[logging.Handler] = []
    if log_file:
        log_dir = os.path.dirname(log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        handlers.append(logging.FileHandler(log_file))
    else:
        handlers.append(logging.StreamHandler())

    logging.basicConfig(
        level=logging.INFO,
        format="[%(levelname)s] %(message)s",
        handlers=handlers,
    )


def _session_sort_key(session_id: str) -> tuple[int, str]:
    match = re.match(r"^ses-(\d+)$", session_id)
    if match:
        return (int(match.group(1)), session_id)
    return (sys.maxsize, session_id)


def _extract_session_info(file_path: Path) -> Optional[tuple[str, str]]:
    parts = file_path.parts
    if "accel" not in parts:
        LOGGER.warning("Skipping file outside accel tree: %s", file_path)
        return None

    accel_index = parts.index("accel")
    if accel_index + 1 >= len(parts):
        LOGGER.warning("Skipping file with incomplete accel path: %s", file_path)
        return None

    if parts[accel_index + 1] == "all":
        LOGGER.info("Skipping accel/all path: %s", file_path)
        return None

    session_dir = parts[accel_index + 1]
    if not SESSION_DIR_RE.match(session_dir):
        LOGGER.warning("Skipping file with unexpected session directory: %s", file_path)
        return None

    if accel_index == 0:
        LOGGER.warning("Skipping file without subject directory: %s", file_path)
        return None

    subject_dir = parts[accel_index - 1]
    if not subject_dir.startswith("sub-"):
        LOGGER.warning("Skipping file without subject directory: %s", file_path)
        return None

    match = ACCEL_FILENAME_RE.match(file_path.name)
    if not match:
        LOGGER.warning("Skipping file with unexpected name: %s", file_path)
        return None

    subject_from_file = f"sub-{match.group(1)}"
    session_from_file = f"ses-{match.group(2)}"
    if subject_from_file != subject_dir or session_from_file != session_dir:
        LOGGER.warning(
            "Skipping file with mismatched subject/session (dir=%s/%s, file=%s): %s",
            subject_dir,
            session_dir,
            file_path.name,
            file_path,
        )
        return None

    return subject_from_file, session_from_file


def count_actual_sessions(int_dir: Path, obs_dir: Path) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for root in (int_dir, obs_dir):
        if not root.exists():
            raise FileNotFoundError(f"Directory not found: {root}")
        for file_path in root.rglob("*_accel.csv"):
            info = _extract_session_info(file_path)
            if not info:
                continue
            _, session_id = info
            counts[session_id] = counts.get(session_id, 0) + 1
    return counts


def parse_expected_counts(expected_csv: Optional[Path]) -> Dict[str, int]:
    if expected_csv is None:
        return {}
    if not expected_csv.exists():
        raise FileNotFoundError(f"Expected counts CSV not found: {expected_csv}")

    with expected_csv.open(newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            LOGGER.warning("Expected counts CSV has no headers: %s", expected_csv)
            return {}

        try:
            row = next(reader)
        except StopIteration:
            LOGGER.warning("Expected counts CSV has no rows: %s", expected_csv)
            return {}

        extra_rows = list(reader)
        if extra_rows:
            LOGGER.warning(
                "Expected counts CSV has more than one row; extra rows ignored: %s",
                expected_csv,
            )

        expected: Dict[str, int] = {}
        for header in reader.fieldnames:
            if header is None:
                continue
            header = header.strip()
            if not SESSION_DIR_RE.match(header):
                LOGGER.warning(
                    "Skipping malformed expected header %r in %s",
                    header,
                    expected_csv,
                )
                continue

            raw_value = row.get(header, "")
            if raw_value is None or str(raw_value).strip() == "":
                LOGGER.warning(
                    "Missing expected count for %s in %s", header, expected_csv
                )
                continue

            try:
                value = int(str(raw_value).strip())
            except ValueError:
                LOGGER.warning(
                    "Skipping non-numeric expected count for %s: %r",
                    header,
                    raw_value,
                )
                continue

            if value < 0:
                LOGGER.warning(
                    "Skipping negative expected count for %s: %r", header, raw_value
                )
                continue

            expected[header] = value

    return expected


def build_report(
    actual_counts: Dict[str, int], expected_counts: Dict[str, int]
) -> List[Dict[str, str | int]]:
    sessions = sorted(
        set(actual_counts) | set(expected_counts), key=_session_sort_key
    )
    rows: List[Dict[str, str | int]] = []

    for session in sessions:
        actual = actual_counts.get(session)
        expected = expected_counts.get(session)

        if actual is None:
            LOGGER.warning("Missing actual count for session %s", session)
            actual_value = 0
        else:
            actual_value = actual

        if expected is None:
            LOGGER.warning("Missing expected count for session %s", session)

        proportion = ""
        if expected is not None and expected > 0:
            proportion = f"{actual_value / expected:.4f}"

        rows.append(
            {
                "session": session,
                "actual_count": actual_value,
                "expected_count": expected if expected is not None else "",
                "proportion": proportion,
            }
        )

    return rows


def write_report(rows: Iterable[Dict[str, str | int]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["session", "actual_count", "expected_count", "proportion"],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def run_report(
    expected_csv: Optional[Path], int_dir: Path, obs_dir: Path, out_path: Path
) -> Path:
    expected_counts = parse_expected_counts(expected_csv)
    actual_counts = count_actual_sessions(int_dir, obs_dir)
    rows = build_report(actual_counts, expected_counts)
    write_report(rows, out_path)
    LOGGER.info("Wrote DSMC session counts report to %s", out_path)
    return out_path


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate DSMC session counts without running the main pipeline."
    )
    parser.add_argument(
        "--expected",
        help="Absolute path to expected counts CSV (optional).",
        default=None,
    )
    parser.add_argument("--int-dir", required=True, help="Absolute path to INT_DIR")
    parser.add_argument("--obs-dir", required=True, help="Absolute path to OBS_DIR")
    parser.add_argument(
        "--out",
        default=str(Path.cwd() / "dsmc_session_counts.csv"),
        help="Output CSV path (default: ./dsmc_session_counts.csv)",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    configure_logging()

    try:
        run_report(
            Path(args.expected) if args.expected else None,
            Path(args.int_dir),
            Path(args.obs_dir),
            Path(args.out),
        )
    except Exception as exc:  # pragma: no cover - defensive logging
        LOGGER.error("Failed to generate DSMC session counts: %s", exc)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
