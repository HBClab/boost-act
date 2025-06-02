import os
import pandas as pd


class QC:
    def __init__(self, project: str):
        """
        Initialize a QC instance.

        Parameters:
        -----------
        project : str
            Either 'obs' for observational study (7 days worn) or 'int' for
            intervention study (9 days worn). Determines expected wear-time.

        Attributes:
        -----------
        n_days_worn : int
            Number of days the device is expected to be worn, based on project.
        base_dir : str
            Full path to the parent “GGIR‐3.2.6‐test” directory containing all subjects.
        csv_path : str
            Path to the master CSV where QC outcomes are logged.
        """

        # Determine the expected days worn based on project type
        if project == 'obs':
            self.n_days_worn = 7
        elif project == 'int':
            self.n_days_worn = 9
        else:
            raise ValueError("Project must be 'obs' or 'int'")

        # Hardcoded base directory for GGIR outputs (change if needed)
        self.base_dir = (
            "/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/"
            "3-experiment/data/act-obs-test/derivatives/GGIR-3.2.6-test"
        )

        # Path to the master CSV that accumulates QC errors/warnings
        self.csv_path = "../logs/GGIR_QC_errs.csv"


    def qc(self) -> None:
        """
        Loop through each subject under self.base_dir, locate the three QC files
        (QC report, person summary, day summary), extract metrics, and run all
        QC checks for that subject/session. After processing each subject, delete
        loaded data from memory to free up resources.

        This method updates self.csv_path with pass/error/warning flags for:
          - Calibration error
          - Hours considered
          - Valid days
          - Cleaning code

        Returns:
        --------
        None
        """
        # Ensure base directory exists
        if not os.path.isdir(self.base_dir):
            raise FileNotFoundError(f"Base directory not found: {self.base_dir}")

        # Iterate over all entries in base_dir; expect subject directories named 'sub-XXXX'
        for entry in os.listdir(self.base_dir):
            sub_path = os.path.join(self.base_dir, entry)
            if not os.path.isdir(sub_path) or not entry.startswith("sub-"):
                # Skip non-directories and non-subject folders
                continue

            # Construct path to the results folder for this subject
            results_dir = os.path.join(
                sub_path,
                "accel",
                "output_accel",
                "results"
            )

            # If results directory does not exist, skip this subject
            if not os.path.isdir(results_dir):
                # Optionally, log that results are missing for this subject
                continue

            # 1. Locate the QC report file
            qc_file = os.path.join(results_dir, "QC", "data_quality_report.csv")
            if not os.path.isfile(qc_file):
                # Skip if QC file missing
                continue

            # 2. Locate the person summary CSV (filename starts with 'part5_personsummary')
            person_file = None
            for fname in os.listdir(results_dir):
                if fname.startswith("part5_personsummary") and fname.endswith(".csv"):
                    person_file = os.path.join(results_dir, fname)
                    break
            if person_file is None:
                # Skip if person summary missing
                continue

            # 3. Locate the day summary CSV (filename starts with 'part5_daysummary')
            day_file = None
            for fname in os.listdir(results_dir):
                if fname.startswith("part5_daysummary") and fname.endswith(".csv"):
                    day_file = os.path.join(results_dir, fname)
                    break
            if day_file is None:
                # Skip if day summary missing
                continue

            # Extract subject ID and session from the QC file’s 'filename' column
            # and retrieve the relevant metrics
            dfs = [qc_file, person_file, day_file]
            metrics, sub, ses = self.extract_metrics(dfs)

            # Unpack metrics
            cal_err, h_considered, valid_days, clean_code_series = metrics

            # Run each QC check, which will append/update self.csv_path
            self.cal_error_check(cal_err, sub, ses)
            self.h_considered_check(h_considered, sub, ses)
            self.valid_days_check(valid_days, sub, ses)
            self.cleaning_code_check(clean_code_series, sub, ses)

            # Clean up DataFrames/variables to free memory before next iteration
            try:
                del metrics, cal_err, h_considered, valid_days, clean_code_series
                del dfs, person_file, day_file, qc_file
                del sub, ses
            except UnboundLocalError:
                # If any variable wasn’t set, ignore
                pass

        # End of qc loop


    def extract_metrics(self, dfs: list) -> tuple:
        """
        Given a list of exactly three file paths [qc_csv, person_csv, day_csv],
        read each into a DataFrame, extract the relevant metrics, and return
        (metrics_list, subject, session).

        Parameters:
        -----------
        dfs : list of str
            dfs[0]: Full path to QC/data_quality_report.csv
            dfs[1]: Full path to part5_personsummary_*.csv
            dfs[2]: Full path to part5_daysummary_*.csv

        Returns:
        --------
        metrics : list
            [calibration_error (float),
             hours_considered (int),
             valid_days (int),
             cleaning_code (pd.Series)]
        sub : str
            Subject identifier, e.g., 'sub-7001'
        ses : str
            Session identifier, e.g., 'ses-1'

        Raises:
        -------
        FileNotFoundError if any of the three paths are invalid.
        """
        qc_path, person_path, day_path = dfs

        # Read the CSVs into DataFrames
        qc_df = pd.read_csv(qc_path)
        person_df = pd.read_csv(person_path)
        day_df = pd.read_csv(day_path)

        # The QC report’s 'filename' column holds something like 'sub-7001_ses-1_xxx.ext'
        # Split on '_' to get subject and session identifiers
        file_id = qc_df["filename"].iloc[0]
        parts = file_id.split("_")
        sub = parts[0]   # e.g., 'sub-7001'
        ses = parts[1]   # e.g., 'ses-1'

        # Extract metrics from each DataFrame:
        # 1) Calibration error: from qc_df column 'cal.error.end'
        cal_err = qc_df["cal.error.end"].iloc[0]
        # 2) Hours considered: from qc_df column 'n.hours.considered'
        h_considered = qc_df["n.hours.considered"].iloc[0]
        # 3) Valid days: from person summary column 'Nvaliddays'
        valid_days = person_df["Nvaliddays"].iloc[0]
        # 4) Cleaning code series: from day summary column 'cleaningcode'
        clean_code = day_df["cleaningcode"]

        metrics = [cal_err, h_considered, valid_days, clean_code]
        return metrics, sub, ses


    # ─────────────────────────────────────────────────────────────────────
    # #2: Append/Update Master QC CSV with human-readable messages
    # ─────────────────────────────────────────────────────────────────────

    def create_and_return_csv(self, check: str, code: int, sub: str, ses: str) -> None:
        """
        Appends or updates a row in self.csv_path for (sub, ses), setting
        the human-readable interpretation for the specified QC check.

        If an expected variable wasn’t set (code = 3), writes a “missing variable”
        message into the CSV for that check.
        """
        # Map internal check names to CSV column names
        name_map = {
            'cal_err':      'Calibration_Error',
            'h_considered': 'Hours_Considered',
            'clean_code':   'Cleaning_Code',
            'val_days':     'Valid_Days'
        }
        col = name_map.get(check, check)

        # Human-readable interpretations for each check / response code
        meanings = {
            'Calibration_Error': {
                0: 'Pass',
                1: 'ERROR: Calibration error too high',
                3: 'ERROR: Calibration error missing'
            },
            'Hours_Considered': {
                0: 'Pass',
                1: 'ERROR: Too few hours considered',
                2: 'WARNING: Exceeds expected hours (possible worn-day mismatch)',
                3: 'ERROR: Hours considered missing'
            },
            'Cleaning_Code': {
                0: 'Pass',
                1: 'ERROR: Invalid cleaning code found',
                2: 'WARNING: Missing (NaN) cleaning codes present',
                3: 'ERROR: Cleaning code missing'
            },
            'Valid_Days': {
                0: 'Pass',
                1: 'ERROR: Fewer valid days than worn days',
                2: 'WARNING: More valid days than worn days',
                3: 'ERROR: Valid days missing'
            }
        }
        interpretation = meanings[col].get(code, 'ERROR: Unknown code')

        # Load existing master CSV if it exists; otherwise create a fresh DataFrame
        if os.path.exists(self.csv_path):
            master_df = pd.read_csv(self.csv_path)
        else:
            cols = ['Subject', 'Session'] + list(name_map.values())
            master_df = pd.DataFrame(columns=cols)

        # Check if a row for this (sub, ses) already exists
        mask = (master_df['Subject'] == sub) & (master_df['Session'] == ses)
        if mask.any():
            # Overwrite only this column’s value
            master_df.loc[mask, col] = interpretation
        else:
            # Create a new row, with blanks in all QC columns except this one
            new_row = {c: '' for c in master_df.columns}
            new_row['Subject'] = sub
            new_row['Session'] = ses
            new_row[col] = interpretation
            master_df = pd.concat([master_df, pd.DataFrame([new_row])], ignore_index=True)

        # Write back to CSV (index=False to avoid an extra column)
        master_df.to_csv(self.csv_path, index=False)


    # ─────────────────────────────────────────────────────────────────────
    # #3: Individual QC Check Methods (append to CSV via create_and_return_csv)
    #      Modified to catch “variable not set” and report code = 3
    # ─────────────────────────────────────────────────────────────────────

    def cal_error_check(self, cal_error: float, sub: str, ses: str, threshold: float = 0.03) -> int:
        """
        Check calibration error against a threshold.

        Returns:
        --------
        0 → OK
        1 → Calibration error exceeds threshold
        3 → Calibration error variable was not set
        """
        try:
            # If cal_error is None or NaN, treat as missing
            if cal_error is None or (isinstance(cal_error, float) and pd.isna(cal_error)):
                raise ValueError("cal_error is missing")

            if cal_error > threshold:
                self.create_and_return_csv('cal_err', 1, sub, ses)
                return 1
            else:
                self.create_and_return_csv('cal_err', 0, sub, ses)
                return 0

        except Exception:
            # Any exception (NameError, ValueError, etc.) means variable not set
            self.create_and_return_csv('cal_err', 3, sub, ses)
            return 3


    def h_considered_check(self, h_considered: int, sub: str, ses: str, tolerance: int = 5) -> int:
        """
        Check if the number of hours considered is within the expected window.

        Returns:
        --------
        0 → OK
        1 → Too few hours considered
        2 → More hours than expected (possible mismatch with n_days_worn)
        3 → Hours considered variable was not set
        """
        try:
            # If h_considered is None or NaN, treat as missing
            if h_considered is None or (isinstance(h_considered, (int, float)) and pd.isna(h_considered)):
                raise ValueError("h_considered is missing")

            expected_hours = self.n_days_worn * 24
            if h_considered < (expected_hours - tolerance):
                self.create_and_return_csv('h_considered', 1, sub, ses)
                return 1
            elif h_considered > expected_hours:
                self.create_and_return_csv('h_considered', 2, sub, ses)
                return 2
            else:
                self.create_and_return_csv('h_considered', 0, sub, ses)
                return 0

        except Exception:
            self.create_and_return_csv('h_considered', 3, sub, ses)
            return 3


    def valid_days_check(self, valid_days: int, sub: str, ses: str) -> int:
        """
        Verify that the number of valid days meets the expected days worn.

        Returns:
        --------
        0 → OK
        1 → Too few valid days
        2 → Too many valid days (likely error in counting)
        3 → Valid days variable was not set
        """
        try:
            # If valid_days is None or NaN, treat as missing
            if valid_days is None or (isinstance(valid_days, (int, float)) and pd.isna(valid_days)):
                raise ValueError("valid_days is missing")

            if valid_days < self.n_days_worn:
                self.create_and_return_csv('val_days', 1, sub, ses)
                return 1
            elif valid_days > self.n_days_worn:
                self.create_and_return_csv('val_days', 2, sub, ses)
                return 2
            else:
                self.create_and_return_csv('val_days', 0, sub, ses)
                return 0

        except Exception:
            self.create_and_return_csv('val_days', 3, sub, ses)
            return 3


    def cleaning_code_check(self, clean_code: pd.Series, sub: str, ses: str) -> int:
        """
        Inspect the 'cleaningcode' column from the day summary.

        Returns:
        --------
        0 → All codes valid (0 or 1)
        1 → Found invalid code (not 0 or 1)
        2 → Only NaNs, no invalid codes
        3 → Cleaning code variable was not set
        """
        try:
            # If clean_code is None or not a Series, treat as missing
            if clean_code is None or not isinstance(clean_code, pd.Series):
                raise ValueError("clean_code is missing")

            # If any value outside {0,1} appears and is not NaN → error
            if ((~clean_code.isin([0, 1])) & clean_code.notna()).any():
                self.create_and_return_csv('clean_code', 1, sub, ses)
                return 1
            # If all values are NaN → warning (no cleaning codes present)
            elif clean_code.isna().all():
                self.create_and_return_csv('clean_code', 2, sub, ses)
                return 2
            else:
                self.create_and_return_csv('clean_code', 0, sub, ses)
                return 0

        except Exception:
            self.create_and_return_csv('clean_code', 3, sub, ses)
            return 3
