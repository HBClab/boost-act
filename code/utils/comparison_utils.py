import os
import sys
import logging
import pandas as pd
import requests
from datetime import datetime, timedelta
from io import StringIO

class ID_COMPARISONS:
    
    def __init__(self, mnt_dir, token, daysago=None) -> None:
       self.token = token
       self.mnt_dir = mnt_dir
       self.INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
       self.OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
       self.daysago = None
       logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

    def compare_ids(self):
        """
        Pulls all files from RDSS
        Pulls the list from RedCap
        Compares IDs and returns a dictionary with two keys:
          - 'matches': normal matches mapping boost_id to a list of dicts (filename, labID, date)
          - 'duplicates': a list of dictionaries each with lab_id, boost_id, filenames (list), and dates (list)
        """
        # Retrieve the RedCap report and duplicates from report
        report, report_duplicates = self._return_report()
        # Retrieve the full RDSS file list and duplicate files merged with duplicates from report
        rdss, file_duplicates = self._rdss_file_list(report_duplicates, self.daysago)

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
            logging.info("Found no duplicates.")

        return {'matches': result, 'duplicates': duplicates_dict}

    def _return_report(self):
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
            'token': self.token,
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
            logging.critical(f"found boost_id(s) with multiple lab_ids: {', '.join(map(str, problematic_boost_ids))}. "
                            "these entries will be removed from processing.")
            df = df[~df['boost_id'].isin(problematic_boost_ids)]
            print(df)
        
        # identify and separate duplicate rows based on any column.
        duplicate_rows = df[df.duplicated(keep=False)]
        df_cleaned = df.drop_duplicates(keep=False)
        
        if not duplicate_rows.empty:
            logging.info(f"duplicate rows found:\n{duplicate_rows}")
        
        return df_cleaned, duplicate_rows

    def _rdss_file_list(self, duplicates, daysago=None):
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
        rdss_dir = os.path.join('/mnt/nfs/rdss/vosslab/Repositories/Accelerometer_Data')
        for filename in os.listdir(rdss_dir):
            print(filename)
            if filename.endswith('.csv'):
                try:
                    base_name = filename.split(' ')[0]  # Extract lab_id
                    date_part = filename.split('(')[1].split(')')[0]  # Extract date
                    extracted_data.append({'ID': base_name, 'Date': date_part, 'filename': filename})
                except IndexError:
                    print(f"Skipping file with unexpected format: {filename}")

        df = pd.DataFrame(extracted_data)
        print(f"EXTRACTED: {extracted_data}")

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
        print(f"MERGED: {merged_df}")
        

        return df, merged_df


# REPORT EXAMPLE
"""  lab_id  boost_id
0     1023      8022
1     1043      7062
2     1093      6011
3     1097      6012
4     1098      6013
..     ...       ...
90    1192      7058
91    1193      7059
"""


# RDSS EXAMPLE
"""        ID        Date                  filename
0     1005  2022-05-10  1005 (2022-05-10)RAW.csv
1     1023  2022-04-30  1023 (2022-04-30)RAW.csv
2     1027  2022-04-26  1027 (2022-04-26)RAW.csv
3     1016  2022-03-23  1016 (2022-03-23)RAW.csv
4      994  2022-05-13   994 (2022-05-13)RAW.csv
...    ...         ...                       ...
1152   584  2018-09-15   584 (2018-09-15)RAW.csv
1153   584  2018-10-16   584 (2018-10-16)RAW.csv"""

# TOKEN FOR REFERENCE



