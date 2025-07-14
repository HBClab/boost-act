import numpy as np
import pandas as pd


# this file will create test data for to add the `date` column to the original plot function
# This should be > 5 dataframes of len(7 > x < 10) days with dummy dates and random values for data columns

# each df must have the following columns:
# - dur_day_total_IN_min
# - dur_day_total_LIG_min
# - dur_day_total_MOD_min
# - dur_day_total_VIG_min
# - dur_spt_sleep_min
# - dur_spt_min_pla
# - filename (with a session number, e.g. 'ses-1') <- will be randomly generates with sub-####_ses-#_accel.csv format
# - 7 - 10 rows of data with random values and dates (in new dates column) for each df

def create_test_data(num_dfs=5, min_days=7, max_days=10):
    dataframes = []
    for i in range(num_dfs):
        num_days = np.random.randint(min_days, max_days + 1)
        dates = pd.date_range(start=f'2023-01-{i+1}', periods=num_days, freq='D')
        
        # Create random data
        data = {
            'dur_day_total_IN_min': np.random.randint(0, 1440, size=num_days),
            'dur_day_total_LIG_min': np.random.randint(0, 1440, size=num_days),
            'dur_day_total_MOD_min': np.random.randint(0, 1440, size=num_days),
            'dur_day_total_VIG_min': np.random.randint(0, 1440, size=num_days),
            'dur_spt_sleep_min': np.random.randint(0, 1440, size=num_days),
            'dur_spt_min_pla': np.random.randint(0, 1440, size=num_days),
            'filename': [f'sub-{i+1:04d}_ses-{np.random.randint(1, 4)}_accel.csv'] * num_days,
            'date': dates
        }
        
        df = pd.DataFrame(data)
        dataframes.append(df)
    return dataframes

df_list = create_test_data()
print(f"Created {len(df_list)} dataframes with random data:")
print("The following columns are present in each dataframe: \n")
print(df_list[0].columns.tolist())
print("\nSample data from the first dataframe:")
print(df_list[0].head())

