import os
import shutil
from utils.comparison_utils import ID_COMPARISONS


class Save:

    def __init__(self, intdir, obsdir, rdssdir):
        self.matches = ID_COMPARISONS('../mnt').compare_ids()
        self.INT_DIR = intdir
        self.OBS_DIR = obsdir
        self.RDSS_DIR = rdssdir

    def save(self):
        matches = self._determine_run(matches=self.matches)
        matches = self._determine_study(matches=matches)
        matches = self._determine_location(matches=matches)
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
        - If boost_id > 8000, 'study' = 'int'

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
                    file_path = f"{study_dir}/{subject_folder}/accel/{filename}"

                    # Append file path to record
                    record['file_path'] = file_path

            except TypeError as e:
                print(f"Skipping subject {subject_id} due to error: {e}")
                continue  # Skip this subject and move to the next one

        return matches





