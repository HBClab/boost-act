import os
import sys
import requests


OUTDIR = '/Volumes/vosslabhpc/Projects/Boost/path/to/out'


def parse_args():
    from argparse import ArgumentParser
    args = ArgumentParser(description='validates a run from an input text output')
    args.add_argument('-i', type=str, required=True, help='input txt file from most recent GGIR pipeline out')


    return args.parse_args()

def create_obj(filepath):
    # creates a parseable text object from a text file -> used to validate run of pipeline post-compute
    dic = {}
    with open(filepath, 'r') as f:
        for line in f:

    return None


def main():
    args = parse_args()
    in = args.i



    return None






if __name__ == '__main__':
    main()
