import pandas as pd
import os
import requests
import sys
from io import StringIO
from datetime import datetime, timedelta


'''
This script is designed to create a sleep log file for the group analysis of accelerometer data.
It reads the individual participant files by first matching labID with studyID, then builds path to individual files on the RDSS
Aggregates the sleep data by participant and session (with _accel suffix) and saves it to a CSV file.
'''

token = 'DE4E2DB72778DACA9B8848574107D2F5'
INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
rdss_dir = '/Volumes/VossLab/Repositories/Accelerometer_Data/Sleep'

def compare_ids(rdss_dir, token, daysago=350):
    """
    Pulls all files from RDSS
    Pulls the list from RedCap
    Compares IDs and returns a dictionary with two keys:
        - 'matches': normal matches mapping boost_id to a list of dicts (filename, labID, date)
        - 'duplicates': a list of dictionaries each with lab_id, boost_id, filenames (list), and dates (list)
    """
    # Retrieve the RedCap report and duplicates from report
    report, report_duplicates = _return_report(token)
    # Retrieve the full RDSS file list and duplicate files merged with duplicates from report
    rdss, file_duplicates = _rdss_file_list(report_duplicates)

    # Initialize the result dictionary for normal (non-duplicate) matches
    result = {}

    # Iterate over the rows in the cleaned RedCap report
    for _, row in report.iterrows():
        boost_id = str(row['boost_id'])
        lab_id = str(row['lab_id'])
        
        # Find matching files in the RDSS list
        rdss_matches = rdss[rdss['ID'] == lab_id]
        if not rdss_matches.empty:
            if boost_id not in result:
                result[boost_id] = []
            for _, match_row in rdss_matches.iterrows():
                result[boost_id].append({
                    'filename': match_row['filename'],
                    'labID': lab_id,
                    'date': match_row['Date']
                })
    
    # Process duplicates into the desired structure.
    duplicates_dict = []
    if not file_duplicates.empty:
        # Group by lab_id and boost_id; each group represents one duplicate combination.
        grouped = file_duplicates.groupby(['lab_id', 'boost_id'])
        for (lab_id, boost_id), group in grouped:
            duplicates_dict.append({
                'lab_id': lab_id,
                'boost_id': boost_id,
                'filenames': group['filename'].tolist(),
                'dates': group['Date'].tolist()
            })
    else:
        print("Found no duplicates.")

    return {'matches': result, 'duplicates': duplicates_dict}

def _return_report(token):
    """
    pulls the id report from the rdss via redcap api.
    reads the report as a dataframe.
    checks for boost_ids that are associated with multiple lab_ids, logs a critical error,
    and removes these rows from the dataframe.
    separates duplicate rows (based on any column) from the cleaned data.
    
    returns:
        df_cleaned: dataframe with duplicates removed and problematic boost_ids excluded
        duplicate_rows: dataframe of duplicate rows
    """
    url = 'https://redcap.icts.uiowa.edu/redcap/api/'
    data = {
        'token': token,
        'content': 'report',
        'report_id': 43327,
        'format': 'csv'
    }
    r = requests.post(url, data=data)
    if r.status_code != 200:
        print(f"error! status code is {r.status_code}")
        sys.exit(1)
    
    df = pd.read_csv(StringIO(r.text))
    
    # identify boost_ids associated with multiple lab_ids.
    boost_id_counts = df.groupby('boost_id')['lab_id'].nunique()
    problematic_boost_ids = boost_id_counts[boost_id_counts > 1].index.tolist()
    
    if problematic_boost_ids:
        print(f"found boost_id(s) with multiple lab_ids: {', '.join(map(str, problematic_boost_ids))}. "
                        "these entries will be removed from processing.")
        df = df[~df['boost_id'].isin(problematic_boost_ids)]
    
    # identify and separate duplicate rows based on any column.
    duplicate_rows = df[df.duplicated(keep=False)]
    df_cleaned = df.drop_duplicates(keep=False)
    
    if not duplicate_rows.empty:
        print(f"duplicate rows found:\n{duplicate_rows}")
    
    return df_cleaned, duplicate_rows

def _rdss_file_list(duplicates, daysago=None):
    """
    extracts the first string before the space and the date from filenames ending with .csv
    in the specified folder and stores them in a dataframe.
    
    Also, merges the file list with duplicate report entries based on lab_id.
    
    Returns:
        df: DataFrame of all file entries
        merged_df: DataFrame of file entries that match duplicate lab_ids from the report
    """
    extracted_data = []

    # Loop through all files in the rdss_dir folder.
    for filename in os.listdir(rdss_dir):
        if filename.endswith('.csv'):
            try:
                # Handle both old and new filename formats
                if '_' in filename and filename.endswith('.csv'):
                    # New format: 1288_4-26-2025_Sleep.csv
                    parts = filename.replace('.csv', '').split('_')
                    if len(parts) >= 3:
                        base_name = parts[0]  # lab_id
                        date_part = parts[1]  # date
                        extracted_data.append({'ID': base_name, 'Date': date_part, 'filename': filename})
                    else:
                        print(f"Skipping file with unexpected format: {filename}")
                else:
                    try:
                        base_name = filename.split(' ')[0]  # Extract lab_id (old format)
                        date_part = filename.split('(')[1].split(')')[0]  # Extract date (old format)
                        extracted_data.append({'ID': base_name, 'Date': date_part, 'filename': filename})
                    except IndexError:
                        print(f"Skipping file with unexpected format: {filename}")
            except IndexError:
                print(f"Skipping file with unexpected format: {filename}")

    df = pd.DataFrame(extracted_data)

    if not df.empty:
        df['Date'] = pd.to_datetime(df['Date'], errors='coerce')

        if daysago:
            cutoff_date = datetime.today() - timedelta(days=daysago)
            df = df[df['Date'] >= cutoff_date]  # Filter files within the last `daysago` days
        else:
            df = df[df['Date'] >= '2024-08-05']  # Filter out rows before the threshold date

    # Filter the file list to only include rows where ID is in the duplicate report (if any)
    if not duplicates.empty:
        matched_df = df[df['ID'].isin(duplicates['lab_id'])]
        # Merge with the duplicates to bring in boost_id information from the report
        merged_df = matched_df.merge(duplicates, left_on='ID', right_on='lab_id')
    else:
        merged_df = pd.DataFrame()

    return df, merged_df

matches = compare_ids(rdss_dir, token, daysago=None)
# Print the matches and duplicates for verification
print("Matches:")
for boost_id, files in matches['matches'].items():
    print(f"Boost ID: {boost_id}")
    for file_info in files:
        print(f"  - {file_info['filename']} (Lab ID: {file_info['labID']}, Date: {file_info['date']})")
print("\nDuplicates:")
for dup in matches['duplicates']:
    print(f"Lab ID: {dup['lab_id']}, Boost ID: {dup['boost_id']}")
    print(f"  Filenames: {', '.join(dup['filenames'])}")
    print(f"  Dates: {', '.join(map(str, dup['dates']))}")
# The above code is a complete script that compares IDs from RDSS and RedCap, identifies matches and duplicates, and prints the results.

'''
Below we create the sessions, where if the same subject ID has multiple files, we will create a session for each file ordered by date.
this will now be stored as a dataframe with the columns:
    # 'subject_id', 'session_id', 'filename', 'date'
    # where subject_id is 'sub-<subject_id>', session_id is 'ses-<session_number>', filename is the file name with full path, and date is the date of the file.
'''
def create_sessions(matches):
    """
    Create sessions from the matches dictionary.
    
    Args:
        matches (dict): Dictionary containing matches with boost_id as keys and list of file info as values.
    
    Returns:
        pd.DataFrame: DataFrame with columns 'subject_id', 'session_id', 'filename', 'date'.
    """
    sessions = []
    
    for boost_id, files in matches['matches'].items():
        subject_id = f'sub-{boost_id}'
        for i, file_info in enumerate(files):
            session_id = f'ses-{i + 1}'  # Session number starts from 1
            sessions.append({
                'subject_id': subject_id,
                'session_id': session_id,
                'filename': os.path.join(rdss_dir, file_info['filename']),
                'date': file_info['date']
            })
    
    return pd.DataFrame(sessions)

# Create sessions from the Matches
sessions_df = create_sessions(matches)
# Print the sessions DataFrame for verification
print("\nSessions DataFrame:")
print(sessions_df)


'''
Iterate through the files in the sessions file list and build the sleep log file. Files are have the format:

Sleep Algorithm,In Bed Date,In Bed Time,Out Bed Date,Out Bed Time,Onset Date,Onset Time,Latency,Total Counts,Efficiency,Total Minutes in Bed,Total Sleep Time (TST),Wake After Sleep Onset (WASO),Number of Awakenings,Average Awakening Length,Movement Index,Fragmentation Index,Sleep Fragmentation Index
Cole-Kripke,4/12/2023,12:00 AM,4/12/2023,6:00 AM,4/12/2023,12:00 AM,0,34862,84.44,360,304,56,10,5.6,8.889,10,18.889
Cole-Kripke,4/12/2023,11:09 PM,4/13/2023,7:00 AM,4/12/2023,11:19 PM,10,54263,87.05,471,410,51,13,3.92,12.951,7.692,20.643

They need to have the following format:
ID	D1_date	D1_wakeup	D1_inbed	D1_nap_start	D1_nap_end	D1_nonwear1_off	D1_nonwear1_on	D2_date	…
123	2015-03-30	09:00:00	22:00:00	11:15:00	11:45:00	13:35:00	14:10:00	31/03/2015	…
567	2015-04-20	08:30:00	23:15:00	

where ID should be sub-{subject_id}_ses-{session_id}_accel and D1_date is the first date of the file, D1_wakeup is the first wakeup time, D1_inbed is the second in-bed time (skipping the first in-bed time). Naps and non-wear will be skipped for now.
complete for all dates in the file

'''

def create_sleep_log(sessions_df):
    """
    Create a sleep log file from the sessions DataFrame.
    
    Args:
        sessions_df (pd.DataFrame): DataFrame with columns 'subject_id', 'session_id', 'filename', 'date'.
    
    Returns:
        pd.DataFrame: DataFrame with sleep log entries in wide format.
    """
    # List to store the final entries (one per subject/session)
    final_entries = []
    
    for _, row in sessions_df.iterrows():
        subject_id = row['subject_id']
        session_id = row['session_id']
        filename = row['filename']
        
        try:
            # Skip first 5 rows and first column
            sleep_data = pd.read_csv(filename, skiprows=5, usecols=lambda x: x != 'Unnamed: 0')
            if sleep_data.empty:
                print(f"No data found in file {filename}. Skipping.")
                continue
            
            # Create a base entry for this subject/session
            entry = {'ID': f'{subject_id}_{session_id}_accel'}
            
            # Convert In Bed Date to datetime for sorting
            sleep_data['In_Bed_Date_DT'] = pd.to_datetime(sleep_data['In Bed Date'], format='%m/%d/%Y', errors='coerce')
            sleep_data = sleep_data.sort_values('In_Bed_Date_DT')  # Sort by date
            
            # Group by date and keep only the last entry for each date
            date_groups = {}
            for _, data in sleep_data.iterrows():
                in_bed_date_str = data['In Bed Date']
                date_key = pd.to_datetime(in_bed_date_str, format='%m/%d/%Y').strftime('%Y-%m-%d')
                date_groups[date_key] = data
            
            # Process each day's data
            for day_num, (date_key, data) in enumerate(sorted(date_groups.items()), 1):
                day_prefix = f'D{day_num}_'
                
                # Extract date and time information
                in_bed_date = pd.to_datetime(data['In Bed Date'], format='%m/%d/%Y').strftime('%Y-%m-%d')
                in_bed_time = pd.to_datetime(data['In Bed Time'], format='%I:%M %p').strftime('%H:%M:%S')
                out_bed_date = pd.to_datetime(data['Out Bed Date'], format='%m/%d/%Y').strftime('%Y-%m-%d')
                out_bed_time = pd.to_datetime(data['Out Bed Time'], format='%I:%M %p').strftime('%H:%M:%S')
                
                # Store only date and time information for this day
                entry[f'{day_prefix}date'] = in_bed_date
                entry[f'{day_prefix}inbed'] = in_bed_time
                entry[f'{day_prefix}wakeup'] = out_bed_time
            
            final_entries.append(entry)
            
        except Exception as e:
            print(f"Error processing file {filename}: {e}")
    
    return pd.DataFrame(final_entries)


# Create the sleep log dataframe
sleep_log_df = create_sleep_log(sessions_df)
# Print the sleep log DataFrame for verification
print("\nSleep Log DataFrame:")
print(sleep_log_df)



'''
Split the dataframes into two parst, intervention and observational
where if subject ID starts with sub-7*, it is an observational study subject, otherwise it is an intervention study subject.
then clean up the dataframes by removing any extra columns that are unused

'''

def split_and_clean_dataframes(sleep_log_df):
    """
    Split the sleep log DataFrame into intervention and observational study DataFrames,
    and clean up by removing unused columns.
    
    Args:
        sleep_log_df (pd.DataFrame): DataFrame with sleep log entries.
    
    Returns:
        tuple: Two DataFrames, one for intervention study and one for observational study.
    """
    # Split the DataFrame based on subject ID
    obs_df = sleep_log_df[sleep_log_df['ID'].str.startswith('sub-7')]
    # Intervention study DataFrame contains all other subjects (doesn't start with sub-7 or sub-6)
    int_df = sleep_log_df[~sleep_log_df['ID'].str.startswith('sub-7')]
    int_df = int_df[~int_df['ID'].str.startswith('sub-6')]
    # Clean up by removing unused columns (if any)
    int_df = int_df.reset_index(drop=True)
    obs_df = obs_df.reset_index(drop=True)
    
    return int_df, obs_df

# Split and clean the DataFrames
int_df, obs_df = split_and_clean_dataframes(sleep_log_df)
# Print the intervention and observational DataFrames for verification
print("\nIntervention Study DataFrame:")
print(int_df.head())
print("\nObservational Study DataFrame:")
print(obs_df.head())

# save the DataFrames to CSV files
int_df.to_csv(os.path.join(INT_DIR, 'sleep_log_intervention.csv'), index=False)
obs_df.to_csv(os.path.join(OBS_DIR, 'sleep_log_observational.csv'), index=False)


