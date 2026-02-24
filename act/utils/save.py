import errno
import json
import logging
import os
import shutil
from datetime import date, datetime
from code.utils.comparison_utils import ID_COMPARISONS


class Save:
    logger = logging.getLogger(__name__)

    def __init__(
        self,
        intdir,
        obsdir,
        rdssdir,
        token,
        daysago=None,
        symlink=True,
        manifest_path="res/data.json",
    ):
        if not rdssdir:
            raise ValueError(
                "RDSS directory is not configured for this system; cannot ingest files."
            )

        results = ID_COMPARISONS(
            rdss_dir=rdssdir, token=token, daysago=daysago
        ).compare_ids()
        self.matches = results["matches"]
        self.matches.pop("6022, 7143", None)
        self.matches.pop("7178, 8066", None)
        self.matches.pop("8057, 7219", None)

        print(self.matches)
        self.dupes = results["duplicates"]
        print(f"Type of Dupes: {type(self.dupes)}")
        self.INT_DIR = intdir
        self.OBS_DIR = obsdir
        self.RDSS_DIR = rdssdir
        self.symlink = symlink
        self.manifest_path = manifest_path
        self.manifest = {}

    def save(self):
        self.manifest = self._load_manifest(
            getattr(self, "manifest_path", "res/data.json")
        )

        # First, process the base matches.
        matches = self._determine_run(matches=self.matches)
        matches = self._determine_study(matches=matches)
        matches = self._determine_location(matches=matches)

        # If duplicates exist, process and merge them.
        if not len(self.dupes) == 0:
            matches = self._handle_and_merge_duplicates(self.dupes)

        committed_matches = {}
        for subject_id, records in matches.items():
            committed_records = self._process_subject_transaction(subject_id, records)
            committed_matches[str(subject_id)] = committed_records

        return self._prepare_for_json(committed_matches)

    def _normalize_manifest_payload(self, payload):
        if not isinstance(payload, dict):
            self.logger.warning(
                "Manifest payload is not a dict; using empty fallback payload."
            )
            return {}

        normalized = {}
        for subject_id, records in payload.items():
            subject_key = str(subject_id)
            if not isinstance(records, list):
                self.logger.warning(
                    "Manifest subject %s payload is not a list; coercing to empty list.",
                    subject_key,
                )
                normalized[subject_key] = []
                continue

            normalized_records = []
            for record in records:
                if isinstance(record, dict):
                    normalized_records.append(dict(record))
                else:
                    self.logger.warning(
                        "Manifest subject %s contains non-dict record; skipping record.",
                        subject_key,
                    )

            normalized[subject_key] = normalized_records

        return normalized

    def _load_manifest(self, path):
        manifest_path = path or getattr(self, "manifest_path", "res/data.json")

        try:
            with open(manifest_path, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except FileNotFoundError:
            self.logger.warning(
                "Manifest file not found at %s; using empty fallback payload.",
                manifest_path,
            )
            return {}
        except (OSError, json.JSONDecodeError) as exc:
            self.logger.warning(
                "Unable to load manifest from %s (%s); using empty fallback payload.",
                manifest_path,
                exc,
            )
            return {}

        return self._normalize_manifest_payload(payload)

    def _save_manifest(self, path):
        manifest_path = path or getattr(self, "manifest_path", "res/data.json")
        payload = self._normalize_manifest_payload(getattr(self, "manifest", {}))
        payload = self._prepare_for_json(payload)

        os.makedirs(os.path.dirname(manifest_path) or ".", exist_ok=True)
        with open(manifest_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)

        return payload

    def _normalize_record_date_value(self, date_value):
        if date_value is None:
            return None

        if hasattr(date_value, "to_pydatetime"):
            try:
                date_value = date_value.to_pydatetime()
            except Exception:
                pass

        if isinstance(date_value, datetime):
            return date_value.date().isoformat()

        if isinstance(date_value, date):
            return date_value.isoformat()

        if isinstance(date_value, str):
            normalized = date_value.strip()
            if not normalized:
                return normalized

            parse_candidates = (normalized, normalized.replace("Z", "+00:00"))
            for candidate in parse_candidates:
                try:
                    parsed = datetime.fromisoformat(candidate)
                except ValueError:
                    continue
                return parsed.date().isoformat()

            return normalized

        if hasattr(date_value, "isoformat"):
            return date_value.isoformat()

        return str(date_value)

    def _reindex_subject_records(self, existing_records, incoming_records):
        merged_records = []
        seen_keys = set()

        for record_list in (existing_records or [], incoming_records or []):
            if not isinstance(record_list, list):
                continue

            for record in record_list:
                if not isinstance(record, dict):
                    continue

                normalized_record = dict(record)
                normalized_record["date"] = self._normalize_record_date_value(
                    normalized_record.get("date")
                )

                dedupe_key = (
                    str(normalized_record.get("labID", "")),
                    normalized_record.get("date"),
                    str(normalized_record.get("filename", "")),
                )

                if dedupe_key in seen_keys:
                    continue

                seen_keys.add(dedupe_key)
                merged_records.append(normalized_record)

        return merged_records

    def _subject_sort_key(self, record):
        normalized_date = self._normalize_record_date_value(record.get("date")) or ""
        filename = str(record.get("filename", ""))
        lab_id = str(record.get("labID", ""))
        return (normalized_date, filename, lab_id)

    def _detect_same_date_conflict(self, records):
        seen_dates = set()
        for record in records:
            normalized_date = self._normalize_record_date_value(record.get("date"))
            if normalized_date is None:
                continue
            if normalized_date in seen_dates:
                return True
            seen_dates.add(normalized_date)
        return False

    def _record_identity_key(self, record):
        return (
            str(record.get("labID", "")),
            self._normalize_record_date_value(record.get("date")),
            str(record.get("filename", "")),
        )

    def _subject_study_root(self, study):
        if (study or "").lower() == "int":
            return self.INT_DIR
        return self.OBS_DIR

    def _subject_session_paths(self, subject_id, study, run):
        subject_key = str(subject_id)
        session = int(run)
        study_root = self._subject_study_root(study)
        session_dir = os.path.join(
            study_root,
            f"sub-{subject_key}",
            "accel",
            f"ses-{session}",
        )
        session_file = os.path.join(
            session_dir,
            f"sub-{subject_key}_ses-{session}_accel.csv",
        )
        return session_dir, session_file

    def _infer_subject_study(self, subject_id, fallback_records=None):
        if fallback_records:
            for record in fallback_records:
                study = (record or {}).get("study")
                if study in {"int", "obs"}:
                    return study

        try:
            subject_val = int(subject_id)
        except (TypeError, ValueError):
            return "obs"

        if subject_val >= 8000:
            return "int"
        return "obs"

    def _copy_subject_record(self, record):
        source_path = os.path.join(self.RDSS_DIR, record["filename"])
        destination_path = record["file_path"]

        if not os.path.exists(source_path):
            print(f"Source file not found: {source_path}. Skipping.")
            return None

        destination_dir = os.path.dirname(destination_path)
        os.makedirs(destination_dir, exist_ok=True)

        if os.path.exists(destination_path):
            print(f"File already exists at destination: {destination_path}. Skipping.")
            if self.symlink:
                self._refresh_subject_symlinks(destination_path)
            return None

        shutil.copy(source_path, destination_path)
        if self.symlink:
            self._refresh_subject_symlinks(destination_path)
        return destination_path

    def _rollback_rename_plan(self, rename_plan):
        inverse_moves = []
        for move in reversed((rename_plan or {}).get("moves", [])):
            inverse_moves.append(
                {
                    "record_key": move.get("record_key"),
                    "old_run": move.get("new_run"),
                    "new_run": move.get("old_run"),
                    "old_dir": move.get("new_dir"),
                    "new_dir": move.get("old_dir"),
                    "old_file": move.get("new_file"),
                    "new_file": move.get("old_file"),
                }
            )

        inverse_plan = {
            "subject_id": (rename_plan or {}).get("subject_id"),
            "study": (rename_plan or {}).get("study"),
            "moves": inverse_moves,
        }

        if inverse_moves:
            self._apply_two_phase_renames(inverse_plan)

    def _process_subject_transaction(self, subject_id, incoming_records):
        subject_key = str(subject_id)
        incoming_records = incoming_records or []
        existing_records = [dict(record) for record in self.manifest.get(subject_key, [])]
        merged_records = self._reindex_subject_records(existing_records, incoming_records)

        if self._detect_same_date_conflict(merged_records):
            self.logger.warning("skip_tie_date subject=%s", subject_key)
            return []

        merged_records.sort(key=self._subject_sort_key)
        subject_study = self._infer_subject_study(subject_key, incoming_records)

        canonical_records = []
        canonical_lookup = {}
        for idx, record in enumerate(merged_records, start=1):
            canonical = dict(record)
            canonical["run"] = idx
            canonical["study"] = subject_study
            _, canonical_file = self._subject_session_paths(subject_key, subject_study, idx)
            canonical["file_path"] = canonical_file
            canonical_records.append(canonical)
            canonical_lookup[self._record_identity_key(canonical)] = canonical

        existing_keys = {
            self._record_identity_key(record)
            for record in existing_records
            if isinstance(record, dict)
        }
        incoming_keys = {
            self._record_identity_key(record)
            for record in incoming_records
            if isinstance(record, dict)
        }
        new_keys = incoming_keys - existing_keys

        old_dates = [
            self._normalize_record_date_value(record.get("date"))
            for record in existing_records
            if isinstance(record, dict)
        ]
        new_dates = [key[1] for key in new_keys if key[1] is not None]

        rename_plan = self._plan_subject_renames(
            subject_id=subject_key,
            study=subject_study,
            old_records=existing_records,
            new_records=canonical_records,
        )

        if not new_keys and not rename_plan["moves"]:
            self.logger.info("noop_duplicate subject=%s", subject_key)

        if new_keys and old_dates and new_dates:
            if min(new_dates) > max(old_dates):
                self.logger.info("append_latest subject=%s", subject_key)
            else:
                self.logger.info("backfill_reindex subject=%s", subject_key)

        applied_renames = False
        copied_paths = []
        try:
            self._apply_two_phase_renames(rename_plan)
            applied_renames = bool(rename_plan["moves"])

            for record_key in new_keys:
                canonical_record = canonical_lookup.get(record_key)
                if canonical_record is None:
                    continue
                copied_path = self._copy_subject_record(canonical_record)
                if copied_path:
                    copied_paths.append(copied_path)

            self.manifest[subject_key] = canonical_records

            committed_records = []
            for record in incoming_records:
                mapped = canonical_lookup.get(self._record_identity_key(record))
                if mapped is not None:
                    committed_records.append(dict(mapped))

            committed_records.sort(key=self._subject_sort_key)
            return committed_records
        except Exception as exc:
            self.logger.warning("rename_failed subject=%s error=%s", subject_key, exc)

            for copied_path in copied_paths:
                try:
                    if os.path.exists(copied_path):
                        os.remove(copied_path)
                except OSError:
                    pass

            if applied_renames:
                try:
                    self._rollback_rename_plan(rename_plan)
                except Exception as rollback_exc:
                    self.logger.warning(
                        "rename_failed subject=%s rollback_error=%s",
                        subject_key,
                        rollback_exc,
                    )

            return []

    def _plan_subject_renames(self, subject_id, study, old_records, new_records):
        old_by_key = {
            self._record_identity_key(record): record
            for record in (old_records or [])
            if isinstance(record, dict)
        }
        new_by_key = {
            self._record_identity_key(record): record
            for record in (new_records or [])
            if isinstance(record, dict)
        }

        rename_steps = []
        for record_key, old_record in old_by_key.items():
            new_record = new_by_key.get(record_key)
            if new_record is None:
                continue

            old_run = old_record.get("run")
            new_run = new_record.get("run")
            if old_run is None or new_run is None or int(old_run) == int(new_run):
                continue

            old_dir, old_file = self._subject_session_paths(subject_id, study, old_run)
            new_dir, new_file = self._subject_session_paths(subject_id, study, new_run)

            rename_steps.append(
                {
                    "record_key": record_key,
                    "old_run": int(old_run),
                    "new_run": int(new_run),
                    "old_dir": old_dir,
                    "new_dir": new_dir,
                    "old_file": old_file,
                    "new_file": new_file,
                }
            )

        return {
            "subject_id": str(subject_id),
            "study": (study or "").lower(),
            "moves": rename_steps,
        }

    def _apply_two_phase_renames(self, rename_plan):
        moves = (rename_plan or {}).get("moves", [])
        if not moves:
            return []

        temp_hops = []
        moved_to_temp = []
        moved_to_final = []

        try:
            for index, move in enumerate(moves, start=1):
                old_dir = move["old_dir"]
                if not os.path.exists(old_dir):
                    continue

                base_parent = os.path.dirname(old_dir)
                temp_dir = os.path.join(
                    base_parent,
                    f".tmp-{rename_plan.get('subject_id', 'subject')}-{index}-{move['old_run']}-to-{move['new_run']}",
                )
                while os.path.exists(temp_dir):
                    temp_dir = f"{temp_dir}-x"

                os.makedirs(os.path.dirname(temp_dir), exist_ok=True)
                os.rename(old_dir, temp_dir)

                hop = {
                    "temp_dir": temp_dir,
                    "old_dir": move["old_dir"],
                    "new_dir": move["new_dir"],
                    "old_file": move["old_file"],
                    "new_file": move["new_file"],
                }
                temp_hops.append(hop)
                moved_to_temp.append(hop)

            for hop in temp_hops:
                new_dir = hop["new_dir"]
                new_file = hop["new_file"]
                temp_dir = hop["temp_dir"]

                os.makedirs(os.path.dirname(new_dir), exist_ok=True)
                os.rename(temp_dir, new_dir)
                moved_to_final.append(hop)

                current_file = None
                for name in os.listdir(new_dir):
                    if name.lower().endswith("_accel.csv"):
                        current_file = os.path.join(new_dir, name)
                        break

                if current_file and current_file != new_file:
                    if os.path.exists(new_file):
                        os.remove(new_file)
                    os.rename(current_file, new_file)
        except Exception:
            for hop in reversed(moved_to_final):
                try:
                    if os.path.exists(hop["new_dir"]):
                        os.rename(hop["new_dir"], hop["old_dir"])
                    old_dir = hop["old_dir"]
                    old_file = hop["old_file"]
                    current_file = None
                    if os.path.isdir(old_dir):
                        for name in os.listdir(old_dir):
                            if name.lower().endswith("_accel.csv"):
                                current_file = os.path.join(old_dir, name)
                                break
                    if current_file and current_file != old_file:
                        if os.path.exists(old_file):
                            os.remove(old_file)
                        os.rename(current_file, old_file)
                except OSError:
                    pass

            for hop in reversed(moved_to_temp):
                try:
                    if os.path.exists(hop["temp_dir"]):
                        os.rename(hop["temp_dir"], hop["old_dir"])
                except OSError:
                    pass
            raise

        return temp_hops

    def _move_files_test(self, matches):
        """
        Moves only one file per study category ('int' and 'obs') from RDSS_DIR to the determined file_path.
        If the destination file already exists, it skips the move.
        """
        selected_files = {"int": None, "obs": None}

        for subject_id, records in matches.items():
            for record in records:
                study = record.get("study")
                if study in selected_files and selected_files[study] is None:
                    selected_files[study] = record  # Store first occurrence

                # Stop once we have one file per category
                if all(selected_files.values()):
                    break
            if all(selected_files.values()):
                break

        for study, record in selected_files.items():
            if record:
                source_path = os.path.join(self.RDSS_DIR, record["filename"])
                destination_path = record["file_path"]

                if not os.path.exists(source_path):
                    print(f"Source file not found: {source_path}. Skipping.")
                    continue

                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    print(
                        f"File already exists at destination: {destination_path}. Skipping."
                    )
                else:
                    try:
                        shutil.copy(source_path, destination_path)
                        print(f"Copied {source_path} -> {destination_path}")
                    except Exception as e:
                        print(f"Error moving {source_path} to {destination_path}: {e}")
                        continue
                if self.symlink:
                    self._refresh_subject_symlinks(destination_path)

    def _move_files(self, matches):
        """
        Moves files from RDSS_DIR to the determined file_path in the matches dictionary.
        If the destination file already exists, it skips the move.

        Args:
            matches (dict): Dictionary where keys are subject IDs, and values are lists of dicts
                            containing 'filename' and 'file_path'.

        Returns:
            None
        """
        for subject_id, records in matches.items():
            for record in records:
                source_path = os.path.join(self.RDSS_DIR, record["filename"])
                destination_path = record["file_path"]

                if not os.path.exists(source_path):
                    print(f"Source file not found: {source_path}. Skipping.")
                    continue

                # Ensure the destination directory exists
                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    print(
                        f"File already exists at destination: {destination_path}. Skipping."
                    )
                    if self.symlink:
                        self._refresh_subject_symlinks(destination_path)
                    continue

                try:
                    shutil.copy(source_path, destination_path)
                    print(f"Moved {source_path} -> {destination_path}")
                except Exception as e:
                    print(f"Error moving {source_path} to {destination_path}: {e}")
                    continue

                if self.symlink:
                    self._refresh_subject_symlinks(destination_path)

    def _refresh_subject_symlinks(self, csv_path):
        """
        Ensure sub-*/accel/all contains symlinks for every CSV under the accel tree.

        Args:
            csv_path (str): Absolute path to the CSV that was just copied or confirmed.
        """
        session_dir = os.path.dirname(csv_path)
        subject_accel_dir = os.path.dirname(session_dir)

        if not os.path.isdir(subject_accel_dir):
            return

        csv_records = []
        for root, dirs, files in os.walk(subject_accel_dir):
            dirs[:] = [d for d in dirs if d != "all"]

            for name in files:
                if not name.lower().endswith(".csv"):
                    continue
                full_path = os.path.join(root, name)
                rel_path = os.path.relpath(full_path, subject_accel_dir)
                csv_records.append((full_path, rel_path))

        all_dir = os.path.join(subject_accel_dir, "all")
        if os.path.exists(all_dir):
            shutil.rmtree(all_dir)

        os.makedirs(all_dir, exist_ok=True)

        use_symlinks = True
        for src, rel_path in csv_records:
            rel_dir = os.path.dirname(rel_path)
            target_dir = (
                all_dir if rel_dir in ("", ".") else os.path.join(all_dir, rel_dir)
            )
            os.makedirs(target_dir, exist_ok=True)
            link_path = os.path.join(target_dir, os.path.basename(rel_path))

            if use_symlinks:
                try:
                    os.symlink(src, link_path)
                    continue
                except FileExistsError:
                    os.unlink(link_path)
                    os.symlink(src, link_path)
                    continue
                except OSError as exc:
                    if exc.errno not in (errno.EOPNOTSUPP, errno.EPERM, errno.EACCES):
                        raise
                    use_symlinks = False
                    self.logger.warning(
                        "Symlinks are not supported in %s; copying CSVs into accel/all instead.",
                        subject_accel_dir,
                    )

            if os.path.exists(link_path):
                os.unlink(link_path)
            shutil.copy2(src, link_path)

    def _determine_run(self, matches):
        """
        Adds a 'run' key to the matches dictionary based on the chronological order of entries for each boost_id.

        Logic:
        - If a boost_id occurs multiple times in the matches list, assign a 'run' value in order of oldest to newest.
        The oldest entry is assigned 1, the next is 2, and so on.

        Args:
            matches (dict): Dictionary with keys as boost_ids and values as lists of dictionaries
                            containing 'filename', 'labID', 'date', and optionally other keys.

        Returns:
            dict: Updated matches dictionary with the 'run' key added to each entry.
        """
        print(f"Type of matches: {type(matches)}")  # Debugging line
        print(f"Value of matches: {matches}")  # Debugging line
        for boost_id, incoming_records in matches.items():
            subject_id = str(boost_id)
            existing_records = self.manifest.get(subject_id, [])
            merged_records = self._reindex_subject_records(
                existing_records=existing_records,
                incoming_records=incoming_records,
            )

            if self._detect_same_date_conflict(merged_records):
                self.logger.warning(
                    "skip_tie_date subject=%s",
                    subject_id,
                )
                matches[boost_id] = []
                continue

            merged_records.sort(key=self._subject_sort_key)
            run_lookup = {}
            for idx, record in enumerate(merged_records, start=1):
                record["run"] = idx
                dedupe_key = (
                    str(record.get("labID", "")),
                    self._normalize_record_date_value(record.get("date")),
                    str(record.get("filename", "")),
                )
                run_lookup[dedupe_key] = idx

            reconciled_records = []
            seen_incoming_keys = set()
            for record in incoming_records:
                if not isinstance(record, dict):
                    continue

                reconciled = dict(record)
                reconciled["date"] = self._normalize_record_date_value(
                    reconciled.get("date")
                )
                dedupe_key = (
                    str(reconciled.get("labID", "")),
                    reconciled.get("date"),
                    str(reconciled.get("filename", "")),
                )

                if dedupe_key in seen_incoming_keys:
                    continue
                seen_incoming_keys.add(dedupe_key)

                assigned_run = run_lookup.get(dedupe_key)
                if assigned_run is None:
                    continue

                reconciled["run"] = assigned_run
                reconciled_records.append(reconciled)

            reconciled_records.sort(key=self._subject_sort_key)
            matches[boost_id] = reconciled_records

        return matches

    # make sure this pushes??
    def _determine_study(self, matches):
        """
        Adds a 'study' key to the matches dictionary based on the boost_id.

        Logic:
        - If boost_id > 7000 and < 8000, 'study' = 'obs'
        - If boost_id >= 8000, 'study' = 'int'

        Args:
            matches (dict): Dictionary with keys as boost_ids and values as lists of dictionaries
                            containing 'filename', 'labID', and 'date'.

        Returns:
            dict: Updated matches dictionary with the 'study' key added to each entry.
        """
        for boost_id, match_list in matches.items():
            # Ensure boost_id is an integer for comparison
            try:
                boost_id_int = int(boost_id)
            except ValueError:
                raise ValueError(f"Invalid boost_id format: {boost_id}")

            # Determine the study type based on the boost_id
            if 6000 < boost_id_int < 8000:
                study = "obs"
            elif boost_id_int >= 8000:
                study = "int"
            else:
                study = None  # Or a default value if needed

            # Append the study type to each match dictionary
            for match in match_list:
                match["study"] = study

        return matches

    def _determine_location(self, matches):
        """
        STRUCTURE OF DIRECTORIES
        study folder (Intervention / Observation)
                |-> bids
                    |-> sub-####
                        |-> accel
                            |-> sub-####_ses-#_accel.csv
        """
        for subject_id, records in matches.items():
            try:
                for record in records:
                    if record["study"] is None:
                        raise TypeError(f"study is None for {subject_id}")

                    study_dir = (
                        self.INT_DIR
                        if record["study"].lower() == "int"
                        else self.OBS_DIR
                    )
                    subject_folder = f"sub-{subject_id}"
                    session = record[
                        "run"
                    ]  # 'run' is synonymous with 'session' or 'set'
                    filename = f"sub-{subject_id}_ses-{session}_accel.csv"

                    # Construct full path
                    file_path = (
                        f"{study_dir}/{subject_folder}/accel/ses-{session}/{filename}"
                    )

                    # Append file path to record
                    record["file_path"] = file_path

            except TypeError as e:
                print(f"Skipping subject {subject_id} due to error: {e}")
                continue  # Skip this subject and move to the next one

        return matches

    def _prepare_for_json(self, matches):
        """Convert non-serializable values (e.g., pandas Timestamps) to strings."""
        for records in matches.values():
            for record in records:
                date_value = record.get("date")
                if date_value is None or isinstance(date_value, str):
                    continue
                if hasattr(date_value, "isoformat"):
                    record["date"] = date_value.isoformat()
                else:
                    record["date"] = str(date_value)
        return matches

    @staticmethod
    def remove_symlink_directories(study_dirs):
        """
        Remove per-subject accel/all directories that only contain symlinks created during ingest.

        Args:
            study_dirs (Iterable[str]): Iterable of study root paths to inspect.
        """
        for base_dir in study_dirs:
            if not base_dir or not os.path.isdir(base_dir):
                continue

            try:
                subjects = os.listdir(base_dir)
            except OSError:
                continue

            for subject in subjects:
                accel_all_dir = os.path.join(base_dir, subject, "accel", "all")

                if os.path.islink(accel_all_dir):
                    try:
                        os.unlink(accel_all_dir)
                    except OSError as exc:
                        print(f"Unable to unlink {accel_all_dir}: {exc}")
                    continue

                if os.path.isdir(accel_all_dir):
                    try:
                        shutil.rmtree(accel_all_dir)
                    except OSError as exc:
                        print(f"Unable to remove directory {accel_all_dir}: {exc}")

    def _handle_and_merge_duplicates(self, duplicates):
        """
        Processes duplicate entries and merges them into the main matches dictionary.

        For each lab_id group in the duplicates (each group is expected to contain two entries:
        one with a boost_id < 8000 for the observational study and one with a boost_id >= 8000 for
        the interventional study):

        1. Combine the filenames and dates from both entries and sort them chronologically.
        2. Pre-build the expected observational study session-1 path:
                OBS_DIR/sub-<obs_boost_id>/accel/sub-<obs_boost_id>_ses-1_accel.csv
            (Here the subject folder is built using the observational study ID, which must be less than 8000.)
        3. If that OBS session-1 file does not exist:
                - Assign the earliest file (by date) as observational (study = 'obs', run = 1)
                using the obs boost_id.
                - Assign any remaining files as interventional (study = 'int') with run numbers
                starting at 1 and using the int boost_id.
            If the OBS session-1 file does exist:
                - Assign all files to the interventional study (study = 'int') with run numbers
                starting at 1, using the int boost_id.
        4. Merge these processed duplicate entries into the main matches dictionary. Each entry
            is stored under the key equal to its subject_id.

        If an expected observational (<8000) or interventional (>=8000) ID is missing for a group,
        an error is raised and processing is stopped.

        Args:
            duplicates (list): A list of dictionaries with keys 'lab_id', 'boost_id', 'filenames', and 'dates'
                            representing duplicate records.

        Returns:
            dict: The updated matches dictionary with processed duplicates merged in.
        """
        # Group duplicates by lab_id.
        grouped = {}
        for dup in duplicates:
            lab_id = dup["lab_id"]
            grouped.setdefault(lab_id, []).append(dup)

        # Process each group.
        for lab_id, dup_list in grouped.items():
            # Identify the observational and interventional entries.
            obs_entry = None
            int_entry = None
            for entry in dup_list:
                try:
                    boost_val = int(entry["boost_id"])
                except ValueError:
                    raise ValueError(
                        f"Invalid boost_id in duplicates for lab_id {lab_id}: {entry['boost_id']}"
                    )
                if boost_val < 8000:
                    obs_entry = entry
                elif boost_val >= 8000:
                    int_entry = entry

            if obs_entry is None:
                raise ValueError(
                    f"Missing observational study ID (boost_id < 8000) for lab_id {lab_id}."
                )
            if int_entry is None:
                raise ValueError(
                    f"Missing interventional study ID (boost_id >= 8000) for lab_id {lab_id}."
                )

            # Combine filenames and dates from both entries.
            combined = []
            for fname, fdate in zip(obs_entry["filenames"], obs_entry["dates"]):
                combined.append((fname, fdate))
            for fname, fdate in zip(int_entry["filenames"], int_entry["dates"]):
                combined.append((fname, fdate))
            # Sort by date (assuming dates are comparable)
            combined.sort(key=lambda x: x[1])

            # Determine subject IDs from the entries.
            obs_boost_id = str(obs_entry["boost_id"])
            int_boost_id = str(int_entry["boost_id"])

            # Build the expected OBS session 1 path.
            subject_folder_obs = f"sub-{obs_boost_id}"
            obs_session1_path = os.path.join(
                self.OBS_DIR,
                subject_folder_obs,
                "accel",
                f"sub-{obs_boost_id}_ses-1_accel.csv",
            )

            new_entries = []
            if not os.path.exists(obs_session1_path):
                # OBS session 1 does not exist.
                # The first (oldest) file becomes observational.
                first_fname, first_date = combined[0]
                new_entries.append(
                    {
                        "filename": first_fname,
                        "labID": lab_id,
                        "date": first_date,
                        "study": "obs",
                        "run": 1,
                        "file_path": obs_session1_path,
                        "subject_id": obs_boost_id,
                    }
                )
                # All remaining files become interventional (run numbers start at 2).
                for idx, (fname, fdate) in enumerate(combined[1:], start=1):
                    subject_folder_int = f"sub-{int_boost_id}"
                    int_file_path = os.path.join(
                        self.INT_DIR,
                        subject_folder_int,
                        "accel",
                        f"sub-{int_boost_id}_ses-{idx}_accel.csv",
                    )
                    new_entries.append(
                        {
                            "filename": fname,
                            "labID": lab_id,
                            "date": fdate,
                            "study": "int",
                            "run": idx,
                            "file_path": int_file_path,
                            "subject_id": int_boost_id,
                        }
                    )
            else:
                # OBS session 1 exists; assign all duplicate files as interventional.
                for idx, (fname, fdate) in enumerate(combined, start=1):
                    subject_folder_int = f"sub-{int_boost_id}"
                    int_file_path = os.path.join(
                        self.INT_DIR,
                        subject_folder_int,
                        "accel",
                        f"sub-{int_boost_id}_ses-{idx}_accel.csv",
                    )
                    new_entries.append(
                        {
                            "filename": fname,
                            "labID": lab_id,
                            "date": fdate,
                            "study": "int",
                            "run": idx,
                            "file_path": int_file_path,
                            "subject_id": int_boost_id,
                        }
                    )

            # Merge the processed duplicate entries into the main matches dictionary.
            for entry in new_entries:
                subject_key = entry["subject_id"]
                if subject_key in self.matches:
                    self.matches[subject_key].append(entry)
                else:
                    self.matches[subject_key] = [entry]

        return self.matches
