from core.gg import GG


# this function needs to read the LSS temp dirs and run GGIR on all files
INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'


def find_files():
    return None #return the files as a dictionary with correct metadata

# run the GGIR script using the GG class
def run_gg():
    return None



'''
EXAMPLE DICT -> CAN LEAVE VALUES FOR KEY 'filename' as string 'BLANK'
{
   "8022": "[{'filename': '1023 (2022-06-15)RAW.csv', 'labID': '1023', 'date': '2022-06-15', 'run': 1, 'study': 'int', 'file_path': '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sub-8022/accel/sub-8022_ses-1_accel.csv'}]",
   "8002": "[{'filename': '1124 (2024-11-07)RAW.csv', 'labID': '1124', 'date': '2024-11-07', 'run': 1, 'study': 'int', 'file_path': '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sub-8002/accel/sub-8002_ses-1_accel.csv'}]",
   "8018": "[{'filename': '1167 (2025-01-22)RAW.csv', 'labID': '1167', 'date': '2025-01-22', 'run': 1, 'study': 'int', 'file_path': '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/sub-8018/accel/sub-8018_ses-1_accel.csv'}]",
   "7043": "[{'filename': '1174 (2025-01-28)RAW.csv', 'labID': '1174', 'date': '2025-01-28', 'run': 1, 'study': 'obs', 'file_path': '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test/sub-7043/accel/sub-7043_ses-1_accel.csv'}]"
}
'''



import os
import re
import json
from collections import defaultdict

# Define your directory paths
INT_DIR = "/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test"
OBS_DIR = "/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test"

def extract_info_from_filename(filename):
    """
    Extracts labID and date from the filename pattern: '#### (YYYY-MM-DD)RAW.csv'
    """
    match = re.match(r"(\d+) \((\d{4}-\d{2}-\d{2})\)RAW\.csv", filename)
    if match:
        labID, date = match.groups()
        return labID, date
    return None, None

def find_csv_files(directory):
    """
    Recursively find all CSV files in the given directory.
    Returns a list of full file paths.
    """
    csv_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".csv"):
                csv_files.append(os.path.join(root, file))
    return csv_files

def recreate_matches(int_dir, obs_dir):
    """
    Searches through INT_DIR and OBS_DIR for CSV files and reconstructs the matches dictionary.
    """
    matches = defaultdict(list)

    # Search both directories
    for directory, study in [(int_dir, "int"), (obs_dir, "obs")]:
        for file_path in find_csv_files(directory):
            filename = os.path.basename(file_path)
            subject_match = re.search(r"sub-(\d+)", file_path)  # Extract subject ID
            if not subject_match:
                continue

            subject_id = subject_match.group(1)
            labID, date = extract_info_from_filename(filename)
            if not labID or not date:
                rdss=None  # Skip files that don't match expected pattern

            matches[subject_id].append({
                "filename": "BLANK",
                "labID": "blank",
                "date": "blank",
                "study": study,
                "file_path": file_path
            })

    # Assign 'run' values
    matches = _determine_run(matches)

    # Reconstruct file paths using the study type and session/run numbers
    matches = _determine_location(matches)

    return matches

# Helper functions reused from provided code
def _determine_run(matches):
    """Assigns 'run' values based on chronological order of entries per subject."""
    for subject_id, match_list in matches.items():
        match_list.sort(key=lambda x: x['date'])  # Sort by date
        for idx, match in enumerate(match_list, start=1):
            match['run'] = idx  # Assign run number
    return matches

def _determine_location(matches):
    """Reconstructs the expected file path based on study and run number."""
    for subject_id, records in matches.items():
        for record in records:
            study_dir = INT_DIR if record['study'].lower() == 'int' else OBS_DIR
            subject_folder = f"sub-{subject_id}"
            session = record['run']
            filename = f"sub-{subject_id}_ses-{session}_accel.csv"

            # Construct full path
            record['file_path'] = f"{study_dir}/{subject_folder}/accel/{filename}"

    return matches

# Execute function and print output as JSON
matches_dict = recreate_matches(INT_DIR, OBS_DIR)
print(json.dumps(matches_dict, indent=4))
GG(matches_dict, INT_DIR, OBS_DIR).run_gg()
