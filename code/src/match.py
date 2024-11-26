import os
import requests
import pandas as pd
import argparse
import shutil
import sys
from io import StringIO

INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/bids'
OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/'

def parse_args():
    argparser = argparse.ArgumentParser(description='Match files to REDCap')
    argparser.add_argument('--indir', type=str, help='Directory of files')
    argparser.add_argument('--txt', type=str, help='Text file to save files')
    argparser.add_argument('--token', type=str, help='REDCap API token')
    return argparser.parse_args()


def save_files(dir, txt):
    data = os.listdir(dir)

    for file in data:
        with open(txt, 'r') as f:
            if file not in f.read():
                with open(txt, 'a') as f:
                    f.write(file + '\n')
        f.close()
    return txt

def get_files(dir):
    data = os.listdir(dir)
    return data

def compare(files, txt):
    need = []
    with open(txt, 'r') as f:
        data = f.read().splitlines()
    f.close()
    for file in files:
        if file not in data:
            need.append(file)
    return need

def parse_files(list):
    df = pd.DataFrame(columns=['labid', 'file'])
    tmp = []
    for file in list:
        if file.endswith('.csv'):
            labid = file.split(' ')[0]
            tmp = [labid, file]
            df.loc[len(df)] = tmp
            tmp = []
    return df


def get_list(token):
    url = 'https://redcap.icts.uiowa.edu/redcap/api/'
    data = {
        'token': token,
        'content': 'report',
        'report_id': 43327,
        'format': 'csv'
    }
    r = requests.post(url, data=data)
    if r.status_code != 200:
        print(f"Error! Status code is {r.status_code}")
        sys.exit(1)
    df = pd.read_csv(StringIO(r.text))
    return df


def compare_ids(files, list):
    """
    Compare IDs between two DataFrames and log matched and unmatched entries.
    Args:
        files (pd.DataFrame): DataFrame containing 'labid' and 'file' columns.
        list (pd.DataFrame): DataFrame containing 'lab_id' and 'boost_id' columns.
    Returns:
        pd.DataFrame: Matched rows with columns 'lab_id', 'raw_file', and 'subject_id'.
    """
    # Ensure both columns are of the same type before merging
    files['labid'] = files['labid'].astype(str)
    list['lab_id'] = list['lab_id'].astype(str)
    # Merge files and list dataframes with validation
    matched = pd.merge(
        files,
        list,
        left_on='labid',
        right_on='lab_id',
        how='inner',
        validate='many_to_one'
    )
    
    # Rename columns to match the desired output
    matched = matched[['lab_id', 'file', 'boost_id']].rename(columns={'file': 'raw_file', 'boost_id': 'subject_id'})
    
    # Identify unmatched files and subs
    unmatched_files = files[~files['labid'].isin(matched['lab_id'])]
    unmatched_subs = list[~list['lab_id'].isin(matched['lab_id'])]
    
    # Log matched IDs
    print("Matched IDs:")
    print(f"- Total Matched: {len(matched)}")
    print(f"- Matched Lab IDs: {', '.join(matched['lab_id'].unique())}")
    
    # Log unmatched files
    if not unmatched_files.empty:
        print("Unmatched Files:")
        print(unmatched_files[['labid', 'file']].to_string(index=False))
    else:
        print("No unmatched files found.")
    
    # Log unmatched subs
    if not unmatched_subs.empty:
        print("Unmatched Subs:")
        print(unmatched_subs[['lab_id', 'boost_id']].to_string(index=False))
    else:
        print("No unmatched subs found.")
    
    return matched


def add_sub_to_sublist(matched):
    with open('./code/resources/sublist.txt', 'r') as f:
        data = f.read().splitlines()

        for index, row in matched.iterrows():
            if row['subject_id'] not in data:
                with open('./code/resources/sublist.txt', 'a') as f:
                    f.write(row['subject_id'] + '\n')

        f.close()

    return None


def evaluate_run(matched):
    for index, row in matched.iterrows():
        max_session = -1  # Initialize with a low value
        outdir = ''
        if row['subject_id'] < 7000:
            outdir = OBS_DIR
        else:
            outdir = INT_DIR
        subject_dir = os.path.join(outdir, f"sub-{str(row['subject_id'])}", 'accel')  # Convert subject_id to string

        # Ensure the subject directory exists
        if os.path.exists(subject_dir):
            for contents in os.listdir(subject_dir):
                parts = contents.split('-')
                if len(parts) == 3 and parts[0] ==  'sub':
                    session_number = int(parts[-1]).replace('.csv', '')
                    if session_number > max_session:
                        max_session = session_number

        # Update the DataFrame with the maximum session found
        matched.loc[index, 'session'] = 'ses-accel-' + str(max_session) if max_session != -1 else 'ses-accel-1'

    return matched


import os
import shutil
import re

def save_n_rename_files(matched, dir):
    outputs = []
    for index, row in matched.iterrows():
        # Use regex to extract the year from the file name
        match = re.search(r'\((\d{4})-\d{2}-\d{2}\)', row['raw_file'])

        if row['subject_id']<7000:
            outdir = OBS_DIR
        else:
            outdir = INT_DIR

        if match:
            year = int(match.group(1))
        else:
            print(f"Could not extract year from file name: {row['raw_file']}")
            continue
        
        # Skip if the year is less than 2024
        if year < 2024:
            continue
        # Construct the output directory path
        output_dir = os.path.join(outdir, f"sub-{str(row['subject_id'])}", 'accel')
        
        # Create the output directory if it doesn't exist
        #os.makedirs(output_dir, exist_ok=True)
        
        # Construct the source and destination file paths
        src = os.path.join(dir, row['raw_file'])
        dest = os.path.join(output_dir, f"sub-{row['subject_id']}_{row['session']}.csv")
        
        print('source: ',  src, ' ', 'destination: ', dest)
        
        # Copy the file to the destination
        #shutil.copy(src, dest)
        outputs.append(dest)

    return outputs

def GGIR(matched):
    import subprocess
    os.system('R') #start R term

    if isinstance(matched, list):
        for item in matched:
            if os.path.exists(item):
                try:
                    result = subprocess.run(
                           [f"Rscript code/src/accel.R --project_dir {item.split('/')[:-1]} --project_deriv_dir {item.split('/')[:-1]}/derivatives --files {item} --verbose TRUE"], 
                            check=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE
                            )
                    print(f"Command output: {result.stdout.decode().strip()}")
                except subprocess.CalledProcessError as e:
                    print(f"Command failed with exit status: {e.returncode}")
                    print(f"Error output: {e.stderr.decode().strip()}")

    elif isinstance(matched, pd.DataFrame):
        for index, row in matched.iterrows():
            # Use regex to extract the year from the file name
            match = re.search(r'\((\d{4})-\d{2}-\d{2}\)', row['raw_file'])
            if row['subject_id']<7000:
                outdir = os.path.join(OBS_DIR, 'derivatives', 'GGIR-3.1.4', f"sub-{row['subject_id']}")
            else:
                outdir = os.path.join(INT_DIR, 'derivatives', 'GGIR-3.1.4', f"sub-{row['subject_id']}")
            try:
                result = subprocess.run(
                        [f"Rscript code/src/accel.R --project_dir {outdir} --project_deriv_dir {outdir}/derivatives --files {row['raw_file']} --verbose TRUE"],
                        check=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE
                        )
                print(f"Command output: {result.stdout.decode().strip()}")

            except subprocess.CalledProcessError as e:
               print(f"Command failed with exit status: {e.returncode}")
               print(f"Error output: {e.stderr.decode().strip()}") 
            os.system(f"Rscript code/src/accel.R --project_dir {outdir} --project_deriv_dir {outdir}/derivatives --files {row['raw_file']} --verbose TRUE")
    os.system('q()')
    return None


def main():
    args = parse_args()
    files = get_files(args.indir)
    need = compare(files, args.txt)
    df = parse_files(need)
    run_list = get_list(args.token)
    matched = compare_ids(df, run_list)
    add_sub_to_sublist(matched)
    matched = evaluate_run(matched)
    save_n_rename_files(matched, args.indir)



if __name__ == '__main__':
    main()
