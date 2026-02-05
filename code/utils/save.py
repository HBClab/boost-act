import errno
import hashlib
import logging
import os
import shutil
import csv
from code.utils.comparison_utils import ID_COMPARISONS


logger = logging.getLogger(__name__)
class Save:
    SIGNATURE_TSV_COLUMNS = (
        "subject_id",
        "study",
        "proposed_rank",
        "final_rank",
        "signature_match",
        "action",
        "rdss_filename",
        "source",
    )

    def __init__(self, intdir, obsdir, rdssdir, token, daysago=None, symlink=True):
        if not rdssdir:
            raise ValueError("RDSS directory is not configured for this system; cannot ingest files.")

        results = ID_COMPARISONS(rdss_dir=rdssdir, token=token, daysago=daysago).compare_ids()
        self.matches = results['matches']
        self.matches.pop('6022, 7143', None)
        self.matches.pop('7178, 8066', None)
        self.matches.pop('8057, 7219', None)

        logger.debug("matches from save.py: \n", self.matches)
        self.dupes = results['duplicates']
        logger.info(f"Type of Dupes: {type(self.dupes)}")
        self.INT_DIR = intdir
        self.OBS_DIR = obsdir
        self.RDSS_DIR = rdssdir
        self.symlink = symlink
        self.session_renames = []

    def save(self):
        # First, process the base matches.
        matches = self._determine_run(matches=self.matches)
        matches = self._determine_study(matches=matches)
        matches = self._determine_location(matches=matches)
        
        # If duplicates exist, process and merge them.
        if not len(self.dupes) == 0:
            matches = self._handle_and_merge_duplicates(self.dupes)

        # Move the files based on the final matches.
        self._move_files(matches=matches)
        return self._prepare_for_json(matches)

    def _move_files_test(self, matches):
        """
        Moves only one file per study category ('int' and 'obs') from RDSS_DIR to the determined file_path.
        If the destination file already exists, it skips the move.
        """
        selected_files = {'int': None, 'obs': None}

        for subject_id, records in matches.items():
            for record in records:
                study = record.get('study')
                if study in selected_files and selected_files[study] is None:
                    selected_files[study] = record  # Store first occurrence

                # Stop once we have one file per category
                if all(selected_files.values()):
                    break
            if all(selected_files.values()):
                break

        for study, record in selected_files.items():
            if record:
                source_path = os.path.join(self.RDSS_DIR, record['filename'])
                destination_path = record['file_path']

                if not os.path.exists(source_path):
                    logger.info(f"Source file not found: {source_path}. Skipping.")
                    continue

                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    logger.info(f"File already exists at destination: {destination_path}. Skipping.")
                else:
                    try:
                        shutil.copy(source_path, destination_path)
                        logger.info(f"Copied {source_path} -> {destination_path}")
                    except Exception as e:
                        logger.info(f"Error moving {source_path} to {destination_path}: {e}")
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
        if getattr(self, "session_renames", None):
            self._apply_session_renames(self.session_renames)
            self.session_renames = []

        for subject_id, records in matches.items():
            for record in records:
                source_path = os.path.join(self.RDSS_DIR, record['filename'])
                destination_path = record['file_path']

                if not os.path.exists(source_path):
                    logger.info(f"Source file not found: {source_path}. Skipping.")
                    continue

                # Ensure the destination directory exists
                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    logger.info(f"File already exists at destination: {destination_path}. Skipping.")
                    if self.symlink:
                        self._refresh_subject_symlinks(destination_path)
                    continue

                try:
                    shutil.copy(source_path, destination_path)
                    logger.info(f"Moved {source_path} -> {destination_path}")
                except Exception as e:
                    logger.info(f"Error moving {source_path} to {destination_path}: {e}")
                    continue

                if self.symlink:
                    self._refresh_subject_symlinks(destination_path)

    def _session_file_path(self, study, subject_id, session):
        """
        Build the canonical session CSV path for a subject.
        """
        study_dir = self.INT_DIR if study == "int" else self.OBS_DIR
        filename = f"sub-{subject_id}_ses-{session}_accel.csv"
        return os.path.join(study_dir, f"sub-{subject_id}", "accel", f"ses-{session}", filename)

    def _apply_session_renames(self, renames):
        """
        Apply planned session renames before copying new files.
        """
        for item in sorted(renames, key=lambda x: x["to_session"], reverse=True):
            study = item["study"]
            subject_id = item["subject_id"]
            from_session = item["from_session"]
            to_session = item["to_session"]

            source_path = self._session_file_path(study, subject_id, from_session)
            dest_path = self._session_file_path(study, subject_id, to_session)

            if not os.path.exists(source_path):
                logger.warning("Expected session file missing for rename: %s", source_path)
                continue

            if os.path.exists(dest_path):
                logger.warning("Destination already exists for rename: %s", dest_path)
                continue

            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            shutil.move(source_path, dest_path)

            source_dir = os.path.dirname(source_path)
            try:
                if not os.listdir(source_dir):
                    os.rmdir(source_dir)
            except OSError:
                pass

            if self.symlink:
                self._refresh_subject_symlinks(dest_path)

    @staticmethod
    def _infer_study(subject_id):
        try:
            boost_id_int = int(subject_id)
        except (TypeError, ValueError):
            return None
        if 6000 < boost_id_int < 8000:
            return "obs"
        if boost_id_int >= 8000:
            return "int"
        return None

    @staticmethod
    def _peek_signature(path, n_lines=8):
        """
        Return a hash of the first n_lines of a text file, ignoring decode errors.
        """
        hasher = hashlib.sha256()
        with open(path, "r", errors="ignore") as handle:
            for _ in range(n_lines):
                line = handle.readline()
                if not line:
                    break
                hasher.update(line.encode("utf-8"))
        return hasher.hexdigest()

    @staticmethod
    def _signature_key(meta):
        """
        Build a stable signature tuple from a metadata dict.
        """
        return (meta.get("size_bytes"), meta.get("mtime"), meta.get("head_hash"))

    def _build_signature_maps(self):
        """
        Scan INT_DIR/OBS_DIR for existing session CSVs and return signature maps.

        Returns:
            tuple: (subject_session_sig, subject_sig_session)
                subject_session_sig[subject_id][session] = signature
                subject_sig_session[subject_id][signature] = session
        """
        subject_session_sig = {}
        subject_sig_session = {}

        for base_dir in (self.INT_DIR, self.OBS_DIR):
            if not base_dir or not os.path.isdir(base_dir):
                continue

            for root, _, files in os.walk(base_dir):
                for name in files:
                    if not name.lower().endswith(".csv"):
                        continue

                    full_path = os.path.join(root, name)
                    try:
                        stats = os.stat(full_path)
                    except OSError:
                        continue

                    subject_id = None
                    session = None
                    for part in root.split(os.sep):
                        if part.startswith("sub-"):
                            subject_id = part.replace("sub-", "", 1)
                        if part.startswith("ses-"):
                            try:
                                session = int(part.replace("ses-", "", 1))
                            except ValueError:
                                session = None

                    if not subject_id or session is None:
                        continue

                    meta = {
                        "size_bytes": stats.st_size,
                        "mtime": stats.st_mtime,
                        "head_hash": self._peek_signature(full_path),
                    }
                    signature = self._signature_key(meta)

                    subject_session_sig.setdefault(subject_id, {})[session] = signature
                    subject_sig_session.setdefault(subject_id, {})[signature] = session

        return subject_session_sig, subject_sig_session

    def _signature_tsv_path(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        return os.path.join(repo_root, "logs", "session_fingerprint.tsv")

    def _load_signature_tsv(self, tsv_path=None):
        path = tsv_path or self._signature_tsv_path()
        if not os.path.exists(path):
            return []

        with open(path, "r", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if reader.fieldnames is None:
                return []
            return list(reader)

    def _append_signature_tsv(self, rows, tsv_path=None):
        if not rows:
            return

        path = tsv_path or self._signature_tsv_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_header = not os.path.exists(path) or os.path.getsize(path) == 0

        with open(path, "a", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=self.SIGNATURE_TSV_COLUMNS,
                delimiter="\t",
                extrasaction="ignore",
            )
            if write_header:
                writer.writeheader()
            writer.writerows(rows)

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
            target_dir = all_dir if rel_dir in ("", ".") else os.path.join(all_dir, rel_dir)
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
        Adds run metadata to matches by batching per subject and reconciling signatures.

        Logic:
        - Sort each subject's records by date to assign proposed_rank.
        - If a record's signature matches an existing session (filesystem or TSV), pin run to that session.
        - Unmatched records are marked pending_gap_fill for later gap allocation.

        Args:
            matches (dict): Dictionary with keys as boost_ids and values as lists of dictionaries
                            containing 'filename', 'labID', 'date', and optionally other keys.

        Returns:
            dict: Updated matches dictionary with the 'run' key added to each entry.
        """
        subject_session_sig, subject_sig_session = self._build_signature_maps()
        tsv_rows = self._load_signature_tsv()
        tsv_by_subject_filename = {}
        tsv_by_subject_rank = {}
        for row in tsv_rows:
            subject_id = row.get("subject_id")
            filename = row.get("rdss_filename")
            final_rank = row.get("final_rank")
            if not subject_id or not filename or not final_rank:
                continue
            try:
                final_rank = int(final_rank)
            except (TypeError, ValueError):
                continue
            tsv_by_subject_filename.setdefault(subject_id, {})[filename] = final_rank
            tsv_by_subject_rank.setdefault(subject_id, {})[final_rank] = {
                "filename": filename,
                "study": row.get("study") or self._infer_study(subject_id),
            }

        audit_rows = []

        for boost_id, match_list in matches.items():
            # Sort the match_list by date in ascending order
            match_list.sort(key=lambda x: x['date'])
            pinned_sessions = set()
            tsv_reserved = set(tsv_by_subject_rank.get(boost_id, {}).keys())
            existing_sessions = set(subject_session_sig.get(boost_id, {}).keys())
            if not hasattr(self, "session_renames"):
                self.session_renames = []

            # Assign a proposed rank and attempt to reuse existing sessions based on signatures.
            for idx, match in enumerate(match_list, start=1):
                match["proposed_rank"] = idx
                signature = None
                rdss_path = os.path.join(self.RDSS_DIR, match.get("filename", ""))
                try:
                    stats = os.stat(rdss_path)
                    signature = self._signature_key(
                        {
                            "size_bytes": stats.st_size,
                            "mtime": stats.st_mtime,
                            "head_hash": self._peek_signature(rdss_path),
                        }
                    )
                except (FileNotFoundError, OSError):
                    signature = None

                reused_session = None
                if signature is not None:
                    reused_session = subject_sig_session.get(boost_id, {}).get(signature)

                if reused_session is None:
                    reused_session = tsv_by_subject_filename.get(boost_id, {}).get(match.get("filename"))

                if reused_session is not None:
                    match["run"] = int(reused_session)
                    match["pending_gap_fill"] = False
                    match["signature_match"] = "exact"
                    pinned_sessions.add(int(reused_session))
                    match["action"] = "reuse"
                    match["source"] = "fs" if signature is not None else "tsv"
                else:
                    match["run"] = None
                    match["pending_gap_fill"] = True
                    match["signature_match"] = "none"
                    match["action"] = "assign_new"
                    match["source"] = None

            # Assign provisional runs to unmatched records when the proposed slot is free.
            for match in match_list:
                if not match.get("pending_gap_fill"):
                    continue
                proposed = match.get("proposed_rank")
                if proposed in tsv_reserved:
                    existing_entry = tsv_by_subject_rank.get(boost_id, {}).get(proposed)
                    existing_name = None
                    existing_study = None
                    if existing_entry:
                        existing_name = existing_entry.get("filename")
                        existing_study = existing_entry.get("study")

                    if existing_name and existing_name != match.get("filename"):
                        candidate = 1
                        while candidate in pinned_sessions or candidate in tsv_reserved:
                            candidate += 1

                        if existing_study:
                            self.session_renames.append(
                                {
                                    "subject_id": boost_id,
                                    "study": existing_study,
                                    "from_session": proposed,
                                    "to_session": candidate,
                                }
                            )

                        tsv_reserved.remove(proposed)
                        tsv_reserved.add(candidate)

                        match["run"] = proposed
                        match["pending_gap_fill"] = False
                        match["action"] = "reassign_conflict"
                        match["source"] = "tsv"
                        pinned_sessions.add(proposed)
                        continue

            # Gap-fill any remaining pending records with the smallest free sessions.
            pending = [m for m in match_list if m.get("pending_gap_fill")]
            if pending:
                pending.sort(key=lambda x: x.get("proposed_rank") or 0)
                assigned = {m.get("run") for m in match_list if m.get("run")}
                candidate = 1
                for match in pending:
                    while candidate in assigned or candidate in pinned_sessions or candidate in tsv_reserved or candidate in existing_sessions:
                        candidate += 1
                    match["run"] = candidate
                    match["pending_gap_fill"] = False
                    match["action"] = match.get("action") or "assign_new"
                    assigned.add(candidate)
                    candidate += 1

            inferred_study = self._infer_study(boost_id)
            for match in match_list:
                audit_rows.append(
                    {
                        "subject_id": boost_id,
                        "study": match.get("study") or inferred_study,
                        "proposed_rank": match.get("proposed_rank"),
                        "final_rank": match.get("run"),
                        "signature_match": match.get("signature_match"),
                        "action": match.get("action"),
                        "rdss_filename": match.get("filename"),
                        "source": match.get("source"),
                    }
                )

        self._append_signature_tsv(audit_rows)
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
                study = 'obs'
            elif boost_id_int >= 8000:
                study = 'int'
            else:
                study = None  # Or a default value if needed

            # Append the study type to each match dictionary
            for match in match_list:
                match['study'] = study

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
                    if record['study'] is None:
                        raise TypeError(f"study is None for {subject_id}")

                    study_dir = self.INT_DIR if record['study'].lower() == 'int' else self.OBS_DIR
                    subject_folder = f"sub-{subject_id}"
                    session = record['run']  # 'run' is synonymous with 'session' or 'set'
                    filename = f"sub-{subject_id}_ses-{session}_accel.csv"

                    # Construct full path
                    file_path = f"{study_dir}/{subject_folder}/accel/ses-{session}/{filename}"

                    # Append file path to record
                    record['file_path'] = file_path

            except TypeError as e:
                print(f"Skipping subject {subject_id} due to error: {e}")
                continue  # Skip this subject and move to the next one

        return matches


    def _prepare_for_json(self, matches):
        """Convert non-serializable values (e.g., pandas Timestamps) to strings."""
        for records in matches.values():
            for record in records:
                date_value = record.get('date')
                if date_value is None or isinstance(date_value, str):
                    continue
                if hasattr(date_value, "isoformat"):
                    record['date'] = date_value.isoformat()
                else:
                    record['date'] = str(date_value)
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
        subject_session_sig, _ = self._build_signature_maps()
        # Group duplicates by lab_id.
        grouped = {}
        for dup in duplicates:
            lab_id = dup['lab_id']
            grouped.setdefault(lab_id, []).append(dup)
        
        # Process each group.
        for lab_id, dup_list in grouped.items():
            # Identify the observational and interventional entries.
            obs_entry = None
            int_entry = None
            for entry in dup_list:
                try:
                    boost_val = int(entry['boost_id'])
                except ValueError:
                    raise ValueError(f"Invalid boost_id in duplicates for lab_id {lab_id}: {entry['boost_id']}")
                if boost_val < 8000:
                    obs_entry = entry
                elif boost_val >= 8000:
                    int_entry = entry

            if obs_entry is None:
                raise ValueError(f"Missing observational study ID (boost_id < 8000) for lab_id {lab_id}.")
            if int_entry is None:
                raise ValueError(f"Missing interventional study ID (boost_id >= 8000) for lab_id {lab_id}.")

            # Combine filenames and dates from both entries.
            combined = []
            for fname, fdate in zip(obs_entry['filenames'], obs_entry['dates']):
                combined.append((fname, fdate))
            for fname, fdate in zip(int_entry['filenames'], int_entry['dates']):
                combined.append((fname, fdate))
            # Sort by date (assuming dates are comparable)
            combined.sort(key=lambda x: x[1])
            
            # Determine subject IDs from the entries.
            obs_boost_id = str(obs_entry['boost_id'])
            int_boost_id = str(int_entry['boost_id'])
            
            # Build the expected OBS session 1 path.
            obs_session1_path = self._session_file_path("obs", obs_boost_id, 1)
            existing_int_sessions = set(subject_session_sig.get(int_boost_id, {}).keys())
            
            new_entries = []
            if not os.path.exists(obs_session1_path):
                # OBS session 1 does not exist.
                # The first (oldest) file becomes observational.
                first_fname, first_date = combined[0]
                new_entries.append({
                    'filename': first_fname,
                    'labID': lab_id,
                    'date': first_date,
                    'study': 'obs',
                    'run': 1,
                    'file_path': obs_session1_path,
                    'subject_id': obs_boost_id
                })
                # All remaining files become interventional in the next free sessions.
                candidate = 1
                for fname, fdate in combined[1:]:
                    while candidate in existing_int_sessions:
                        candidate += 1
                    int_file_path = self._session_file_path("int", int_boost_id, candidate)
                    new_entries.append({
                        'filename': fname,
                        'labID': lab_id,
                        'date': fdate,
                        'study': 'int',
                        'run': candidate,
                        'file_path': int_file_path,
                        'subject_id': int_boost_id
                    })
                    existing_int_sessions.add(candidate)
                    candidate += 1
            else:
                # OBS session 1 exists; assign all duplicate files as interventional.
                candidate = 1
                for fname, fdate in combined:
                    while candidate in existing_int_sessions:
                        candidate += 1
                    int_file_path = self._session_file_path("int", int_boost_id, candidate)
                    new_entries.append({
                        'filename': fname,
                        'labID': lab_id,
                        'date': fdate,
                        'study': 'int',
                        'run': candidate,
                        'file_path': int_file_path,
                        'subject_id': int_boost_id
                    })
                    existing_int_sessions.add(candidate)
                    candidate += 1
            
            # Merge the processed duplicate entries into the main matches dictionary.
            for entry in new_entries:
                subject_key = entry['subject_id']
                if subject_key in self.matches:
                    self.matches[subject_key].append(entry)
                else:
                    self.matches[subject_key] = [entry]
        
        return self.matches
