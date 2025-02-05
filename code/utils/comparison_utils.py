import os
import sys
import logging
import pandas as pd
import requests
from io import StringIO


class ID_COMPARISONS:

    def __init__(self, mnt_dir) -> None:
       self.token = 'DE4E2DB72778DACA9B8848574107D2F5'
       self.mnt_dir = mnt_dir


    def compare_ids(self):
        """
        Pulls all files from RDSS
        Pulls the list from RedCap
        Compares IDs and returns a dict with matches with the following structure:
        key: subject ID (boost_id),
            values: list of dictionaries with keys: filename, labID, date
        """
        # Retrieve the RedCap report and RDSS file list
        report = self._return_report()
        rdss = self._rdss_file_list()

        # Initialize the result dictionary
        result = {}

        # Iterate over the rows in the RedCap report
        for _, row in report.iterrows():
            boost_id = str(row['boost_id'])
            lab_id = str(row['lab_id'])

            # Filter RDSS DataFrame to find matching files for the lab_id
            rdss_matches = rdss[rdss['ID'] == lab_id]

            # If matches are found, add them to the result dictionary
            if not rdss_matches.empty:
                if boost_id not in result:
                    result[boost_id] = []
                for _, match_row in rdss_matches.iterrows():
                    result[boost_id].append({
                        'filename': match_row['filename'],
                        'labID': lab_id,
                        'date': match_row['Date']
                    })

        return result

    def _return_report(self):
        """
        Pulls the ID report from the RDSS
        Reads the report as a dataframe

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
            print(f"Error! Status code is {r.status_code}")
            sys.exit(1)
        df = pd.read_csv(StringIO(r.text))
        return df

    def _rdss_file_list(self):
        """
        Extracts the first string before the space and the date from filenames ending with .csv
        in the specified folder and stores them in a DataFrame.

        Args:
            folder_path (str): Path to the folder containing the .csv files.

        Returns:
            pd.DataFrame: A DataFrame with columns 'ID', 'Date' and 'filename'.
        """
        # Initialize an empty list to store the extracted data
        extracted_data = []

        # Loop through all files in the folder
        for filename in os.listdir(os.path.join(self.mnt_dir, 'rdss_dir')):
            if filename.endswith('.csv'):  # Check for .csv files
                # Split the filename to extract the required parts
                try:
                    base_name = filename.split(' ')[0]  # Extract the first part before the space
                    date_part = filename.split('(')[1].split(')')[0]  # Extract the date inside parentheses
                    extracted_data.append({'ID': base_name, 'Date': date_part, 'filename': filename})
                except IndexError:
                    print(f"Skipping file with unexpected format: {filename}")

        # Convert the list of dictionaries to a DataFrame
        df = pd.DataFrame(extracted_data)

        return df




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



