import os
import re
import shutil
from code.utils.comparison_utils import ID_COMPARISONS


SESSION_DIR_PATTERN = re.compile(r"^ses-(\d+)$")
SESSION_FILE_PATTERN = re.compile(r"^sub-[^_]+_ses-(\d+)_accel\.csv$")


class Save:

    def __init__(self, intdir, obsdir, rdssdir, token, daysago=None):
        if not rdssdir:
            raise ValueError("RDSS directory is not configured for this system; cannot ingest files.")

        results = ID_COMPARISONS(rdss_dir=rdssdir, token=token, daysago=daysago).compare_ids()
        self.matches = results['matches']
        self.matches.pop('6022, 7143', None)
        self.matches.pop('7178, 8066', None)
        self.matches.pop('8057, 7219', None)
        print(self.matches)
        self.dupes = results['duplicates']
        print(f"Type of Dupes: {type(self.dupes)}")
        self.INT_DIR = intdir
        self.OBS_DIR = obsdir
        self.RDSS_DIR = rdssdir

    def _list_existing_sessions(self, study_dir, subject_id):
        """
        Inspect the destination directory for an existing subject and collect any session numbers already present.

        Returns:
            set[int]: Session identifiers detected for the subject/study combination.
        """
        subject_accel_dir = os.path.join(study_dir, f"sub-{subject_id}", "accel")
        sessions = set()

        if not os.path.isdir(subject_accel_dir):
            return sessions

        try:
            for entry in os.listdir(subject_accel_dir):
                entry_path = os.path.join(subject_accel_dir, entry)

                # Match folders such as "ses-1"
                folder_match = SESSION_DIR_PATTERN.match(entry)
                if folder_match:
                    sessions.add(int(folder_match.group(1)))
                    continue

                # Match files that may have been written directly into the accel directory
                if os.path.isfile(entry_path):
                    file_match = SESSION_FILE_PATTERN.match(entry)
                    if file_match:
                        sessions.add(int(file_match.group(1)))
                        continue

                # Defensive: also inspect files inside unexpected sub-directories
                if os.path.isdir(entry_path):
                    try:
                        for nested in os.listdir(entry_path):
                            nested_match = SESSION_FILE_PATTERN.match(nested)
                            if nested_match:
                                sessions.add(int(nested_match.group(1)))
                    except OSError:
                        # If we cannot read the nested directory, skip it; we only need best-effort insight.
                        continue
        except OSError:
            # If we cannot inspect the directory (permissions, race conditions), treat as no existing sessions.
            return sessions

        return sessions

    def _next_available_session(self, used_sessions):
        """
        Determine the smallest positive session number that is not already in use.

        Args:
            used_sessions (set[int]): Sessions already present on disk or assigned in the current batch.

        Returns:
            int: The session number to assign next.
        """
        session = 1
        while session in used_sessions:
            session += 1
        return session

    def _build_destination_path(self, study_dir, subject_id, session):
        """
        Construct the canonical destination path for a given subject/session pair.
        """
        filename = f"sub-{subject_id}_ses-{session}_accel.csv"
        return os.path.join(
            study_dir,
            f"sub-{subject_id}",
            "accel",
            f"ses-{session}",
            filename,
        )

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
                    print(f"Source file not found: {source_path}. Skipping.")
                    continue

                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    print(f"File already exists at destination: {destination_path}. Skipping.")
                else:
                    try:
                        shutil.copyfile(source_path, destination_path)
                        print(f"Copied {source_path} -> {destination_path}")
                    except Exception as e:
                        print(f"Error moving {source_path} to {destination_path}: {e}")

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
                source_path = os.path.join(self.RDSS_DIR, record['filename'])
                destination_path = record['file_path']

                if not os.path.exists(source_path):
                    print(f"Source file not found: {source_path}. Skipping.")
                    continue

                # Ensure the destination directory exists
                destination_dir = os.path.dirname(destination_path)
                os.makedirs(destination_dir, exist_ok=True)

                if os.path.exists(destination_path):
                    print(f"File already exists at destination: {destination_path}. Skipping.")
                else:
                    try:
                        shutil.copyfile(source_path, destination_path)
                        print(f"Moved {source_path} -> {destination_path}")
                    except Exception as e:
                        print(f"Error moving {source_path} to {destination_path}: {e}")

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
        for boost_id, match_list in matches.items():
            # Sort the match_list by date in ascending order
            match_list.sort(key=lambda x: x['date'])

            # Assign a 'run' value to each entry based on its position in the sorted list
            for idx, match in enumerate(match_list, start=1):
                match['run'] = idx

        return matches

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
        session_cache = {}
        for subject_id, records in matches.items():
            try:
                # Sort by the original chronological run so we preserve ordering when assigning new sessions.
                for record in sorted(records, key=lambda r: r.get('run', 0)):
                    study = record.get('study')
                    if study is None:
                        raise TypeError(f"study is None for {subject_id}")

                    if not isinstance(study, str):
                        raise TypeError(f"study must be a string for {subject_id}")

                    study_lower = study.lower()
                    if study_lower == 'int':
                        study_dir = self.INT_DIR
                    elif study_lower == 'obs':
                        study_dir = self.OBS_DIR
                    else:
                        raise TypeError(f"Unexpected study value '{study}' for {subject_id}")

                    cache_key = (study_dir, subject_id)
                    if cache_key not in session_cache:
                        session_cache[cache_key] = self._list_existing_sessions(study_dir, subject_id)

                    used_sessions = session_cache[cache_key]
                    # Assumption: sessions are numbered with the smallest available positive integer,
                    # so gaps left by deleted runs will be reused before new numbers are appended.
                    session = self._next_available_session(used_sessions)
                    used_sessions.add(session)

                    # Keep run aligned with the session assigned on disk to avoid downstream confusion.
                    record['run'] = session
                    record['file_path'] = self._build_destination_path(study_dir, subject_id, session)

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


    def _handle_and_merge_duplicates(self, duplicates):
        """
        Processes duplicate entries and merges them into the main matches dictionary.
        
        For each lab_id group in the duplicates (each group is expected to contain two entries: 
        one with a boost_id < 8000 for the observational study and one with a boost_id >= 8000 for 
        the interventional study):
        
        1. Combine the filenames and dates from both entries and sort them chronologically.
        2. Inspect existing sessions on disk for both studies to avoid overwriting prior outputs.
        3. If the observational session-1 location is still free, assign the earliest file to the observational
            study using the next available session number for that subject. All remaining files are assigned to the
            interventional study, again using the next free session numbers to maintain continuity.
            If observational session-1 already exists, every file is treated as interventional.
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
            
            # Look up existing sessions so we can append without clobbering previously saved runs.
            obs_existing_sessions = self._list_existing_sessions(self.OBS_DIR, obs_boost_id)
            int_existing_sessions = self._list_existing_sessions(self.INT_DIR, int_boost_id)
            obs_session1_path = self._build_destination_path(self.OBS_DIR, obs_boost_id, 1)
            obs_session1_exists = os.path.exists(obs_session1_path) or 1 in obs_existing_sessions
            
            new_entries = []
            remaining_for_int = combined
            if not obs_session1_exists and combined:
                # OBS session 1 does not exist.
                # The first (oldest) file becomes observational.
                first_fname, first_date = combined[0]
                obs_session = self._next_available_session(obs_existing_sessions)
                obs_existing_sessions.add(obs_session)
                obs_file_path = self._build_destination_path(self.OBS_DIR, obs_boost_id, obs_session)
                new_entries.append({
                    'filename': first_fname,
                    'labID': lab_id,
                    'date': first_date,
                    'study': 'obs',
                    'run': obs_session,
                    'file_path': obs_file_path,
                    'subject_id': obs_boost_id
                })
                remaining_for_int = combined[1:]
            else:
                # OBS session 1 exists; assign all duplicate files as interventional.
                remaining_for_int = combined

            for fname, fdate in remaining_for_int:
                # Maintain the same "fill the earliest gap" assumption when allocating interventional sessions.
                int_session = self._next_available_session(int_existing_sessions)
                int_existing_sessions.add(int_session)
                int_file_path = self._build_destination_path(self.INT_DIR, int_boost_id, int_session)
                new_entries.append({
                    'filename': fname,
                    'labID': lab_id,
                    'date': fdate,
                    'study': 'int',
                    'run': int_session,
                    'file_path': int_file_path,
                    'subject_id': int_boost_id
                })
            
            # Merge the processed duplicate entries into the main matches dictionary.
            for entry in new_entries:
                subject_key = entry['subject_id']
                if subject_key in self.matches:
                    self.matches[subject_key].append(entry)
                else:
                    self.matches[subject_key] = [entry]
        
        return self.matches
