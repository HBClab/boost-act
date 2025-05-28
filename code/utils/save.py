import os
import shutil
from utils.comparison_utils import ID_COMPARISONS


class Save:

    def __init__(self, intdir, obsdir, rdssdir, daysago=None):
        results = ID_COMPARISONS('../mnt', daysago).compare_ids()
        self.matches = results['matches']
        self.dupes = results['duplicates']
        print(f"Type of Dupes: {type(self.dupes)}")
        self.INT_DIR = intdir
        self.OBS_DIR = obsdir
        self.RDSS_DIR = rdssdir

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
        return matches

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
                        shutil.copy(source_path, destination_path)
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
                        shutil.copy(source_path, destination_path)
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
            if boost_id_int < 8000:
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
            subject_folder_obs = f"sub-{obs_boost_id}"
            obs_session1_path = os.path.join(self.OBS_DIR, subject_folder_obs, "accel",
                                            f"sub-{obs_boost_id}_ses-1_accel.csv")
            
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
                # All remaining files become interventional (run numbers start at 2).
                for idx, (fname, fdate) in enumerate(combined[1:], start=1):
                    subject_folder_int = f"sub-{int_boost_id}"
                    int_file_path = os.path.join(self.INT_DIR, subject_folder_int, "accel",
                                                f"sub-{int_boost_id}_ses-{idx}_accel.csv")
                    new_entries.append({
                        'filename': fname,
                        'labID': lab_id,
                        'date': fdate,
                        'study': 'int',
                        'run': idx,
                        'file_path': int_file_path,
                        'subject_id': int_boost_id
                    })
            else:
                # OBS session 1 exists; assign all duplicate files as interventional.
                for idx, (fname, fdate) in enumerate(combined, start=1):
                    subject_folder_int = f"sub-{int_boost_id}"
                    int_file_path = os.path.join(self.INT_DIR, subject_folder_int, "accel",
                                                f"sub-{int_boost_id}_ses-{idx}_accel.csv")
                    new_entries.append({
                        'filename': fname,
                        'labID': lab_id,
                        'date': fdate,
                        'study': 'int',
                        'run': idx,
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


