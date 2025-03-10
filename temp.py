
import os
import pandas as pd

# Base directory
base_dir = "/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/derivatives/GGIR-2.8.2-test"

def get_data(base_dir):
    # Initialize list to store data
    data = []

    # Loop through each folder in the directory
    for folder in os.listdir(base_dir):
        folder_path = os.path.join(base_dir, folder)

        if os.path.isdir(folder_path):  # Ensure it's a directory
            # Find the highest session number available
            available_sessions = [
                int(session.split('-')[-1]) for session in os.listdir(folder_path)
                if session.startswith("ses-") and os.path.isdir(os.path.join(folder_path, session))
            ]
            
            if available_sessions:
                max_session = f"ses-{max(available_sessions)}"
                csv_path = os.path.join(folder_path, max_session, "output_accel", "results", "part4_summary_sleep_cleaned.csv")

                # Check if the file exists
                if os.path.exists(csv_path):
                    try:
                        # Read all rows from the CSV file
                        df = pd.read_csv(csv_path, usecols=["filename", "calendar_date"])
                        
                        # Append data to the list
                        data.append(df)
                    
                    except Exception as e:
                        print(f"Error reading {csv_path}: {e}")

    # Combine all data into a single DataFrame
    if data:
        df_final = pd.concat(data, ignore_index=True)
        
        # Convert 'calendar_date' to YYYY-MM-DD format if it exists
        df_final["calendar_date"] = pd.to_datetime(df_final["calendar_date"], format="%d/%m/%Y").dt.strftime("%Y-%m-%d")
        
        # Apply lab ID function if it exists
        if 'add_lab_id' in globals():
            df_final = add_lab_id(df_final)
        
        return df_final
    else:
        return pd.DataFrame()  # Return an empty DataFrame if no data was found
    

    print("Data extraction complete. Saved as 'files_to_put_back.csv'.")

def add_lab_id(df):

    '''
    
    remove first four chars from path and store as subject ID

    pull redcap list (lab_id, boost_id)

    find matching subject IDs and add them to corresponding rows



    '''

    from io import StringIO
    import requests
    import sys
    url = 'https://redcap.icts.uiowa.edu/redcap/api/'
    data = {
        'token': 'DE4E2DB72778DACA9B8848574107D2F5',
        'content': 'report',
        'report_id': 43327,
        'format': 'csv'
    }
    r = requests.post(url, data=data)
    if r.status_code != 200:
        print(f"Error! Status code is {r.status_code}")
        sys.exit(1)
    
    l_s_list = pd.read_csv(StringIO(r.text))

    # Extract subject ID from filename
    df['boost_id'] = df['filename'].str.extract(r'sub-(\d+)_')[0].astype(int)

    # Merge with l_s_list on boost_id
    df = df.merge(l_s_list, on='boost_id', how='left')

    return df
 


def build_file_paths(df):
    """
    Takes a dataframe with columns 'filename', 'calendar_date', 'boost_id', and 'lab_id'.
    Builds new file paths with the format: 'lab_id (calendar_date)RAW.csv'.
    Adds 'opath' (original filepath) and 'npath' (new filepath) columns.
    
    Parameters:
    df (pd.DataFrame): Input dataframe with necessary columns.
    
    Returns:
    pd.DataFrame: DataFrame with added 'opath' and 'npath' columns.
    """
    df = df.copy()
    df['opath'] = df['filename']
    df['npath'] = df.apply(lambda row: f"{row['lab_id']} ({row['calendar_date']})RAW.csv", axis=1)
    return df




def update_and_copy_files(df):
    import shutil
    base_source_path = "/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test/"
    base_dest_path = "/Volumes/VossLab/Repositories/Accelerometer_Data/"
    
    new_file_paths = []
    source_file_paths = [] 
    for _, row in df.iterrows():
        subject_folder = f"sub-{row['boost_id']}"
        source_file_path = os.path.join(base_source_path, subject_folder, "accel", row['opath'])
        destination_file_path = os.path.join(base_dest_path, row['npath'])
        
        # Append new file path to list
        new_file_paths.append(destination_file_path)
        source_file_paths.append(source_file_path)
        
        # Ensure destination directory exists
        os.makedirs(os.path.dirname(destination_file_path), exist_ok=True)
        
        # Copy file
        if os.path.exists(source_file_path):
              print(f"copying file from {source_file_path} to {destination_file_path}")
              shutil.copy2(source_file_path, destination_file_path)
        else:
            print(f"Warning: Source file not found - {source_file_path}")
    
    # Append the new file paths to the dataframe
    #df['new_filepath'] = new_file_paths
    #df['source_file_path'] = source_file_paths   
    return df
