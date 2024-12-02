## This file is the orhcestrator for the GGIR workflow

# this file should control the workflow doing some basic checks on the way

import os
import requests
import pandas as pd
import shutil
from io import StringIO
import src.match
import argparse
import sys

OBSDIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-Experiment/data/bids'
INTDIR = '/Volumes/vosslabhpc/Projects/BOOST/ObersvationalStudy/3-Experiment/data/bids'
RDSSDIR = '/Volumes/VossLab/Repositories/Accelerometer_Data/'
TXT = './resources/files.txt'


def parse_args():
    parser = argparse.ArgumentParser(description="move act files across locations and run GGIR on them")
    parser.add_argument('-i', type=str, required=True, help='Input Directory (RDSS)')
    parser.add_argument('-token', type=str, required=True, help='Token for RedCap API')
    args = parser.parse_args()
    return args


def init_servers():
    #this should connect the linux machine to the RDSS and LSS

    try:
        os.system("sudo mount -t cifs //itf-rs-store24.hpc.uiowa.edu/vosslabhpc /home/vosslab-svc/tmp/vosslabhpc -o uid=vosslab-svc,username=vosslab-svc,vers=3.0")
    except Exception as e:
        print(f'An error occured trying to connect to LSS: {e}')
        sys.exit(1)
    try:
        os.system("sudo mount -t cifs //rdss.iowa.uiowa.edu/rdss_mwvoss/VossLab /mnt/nfs/rdss/rdss_vosslab -o user=vosslab-svc,uid=2418317,gid=900001021")
    except Exception as e:
        print(f'An error occured trying to connect to RDSS: {e}')
        sys.exit(1)

    print("""
          Server check passed -> checking rdss files
          *----------------------------* 
          """)
    return None

def check_files():
    from src.match import get_files, compare

    rdss_files = get_files(RDSSDIR)

    if len(rdss_files) == 0:
        print("error: RDSS files were not grabbed - find out why")
        sys.exit(1)

    need = compare(rdss_files, TXT)


    if len(need) == 0:
        print("no files need GGIR at the moment. quitting...")
        sys.exit(1)

    return need

def create_comparable_dataframe(need):
    #need is a list of files, parse the files using the command from match -> check for things along the way
    from src.match import parse_files

    if type(need) != list:
        print("""
             need is not a list... you need to figure out why
             *----------------------------* 
              """)
        exit()

    lab_id_file = parse_files(need)
    errors = []
    for index, row in lab_id_file.iterrows():
        #check if first column is string of four numbers
        if not isinstance(str(row[0]), str) or not str(row[0]).isdigit() or len(str(row[0])) != 4:
            errors.append(f"Row {index} has an invalid lab id: {str(row[0])}")

        #check if second column is valid filepath
        if not os.path.isfile(str(row[1])):
            errors.append(f"Row {index} has an invalid filepath: {str(row[1])}")

        if errors:
            for error in errors:
                print(error)
            sys.exit(1)
        else:
            print("""
                  All rows are valid
                  *----------------------------*
                  """)

    return lab_id_file


def get_redcap_list_and_compare(token, files):

    from src.match import get_list, compare_ids, add_sub_to_sublist, evaluate_run
    sub_lab_id = get_list(token)

    matched_df = compare_ids(files, sub_lab_id)

    add_sub_to_sublist(matched_df)

    matched_df = evaluate_run(matched_df)

    return matched_df

def save_n_rename(matched, indir):

    from src.match import save_n_rename_files

    outputs = save_n_rename_files(matched, indir)

    return outputs

def GGIR(outs):
    #this is where we run GGIR using the GGIR function in matched
    from src.match import GGIR
    GGIR(outs)
    print("GGIR completed -> moving to validation")
    return None


def main():
    args = parse_args()

    init_servers()

    need = check_files()

    labid_df = create_comparable_dataframe(need)

    matched_df = get_redcap_list_and_compare(args.token, labid_df)

    outputs = save_n_rename(matched_df, args.i)

    GGIR(outputs)

    return None

if __name__ == '__main__':
    main()


