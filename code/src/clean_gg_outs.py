import os
import shutil
import argparse

def args():
    argparser = argparse.ArgumentParser(description='Rename directories')
    argparser.add_argument('--dir', type=str, help='Directory of files')
    return argparser.parse_args()


def gather_dirs(dir):
    dirs = os.listdir(dir)
    #only keep dirs that start with 'output'
    dirs = [d for d in dirs if d.startswith('output')]
    for d in dirs:
        d = os.path.join(dir, d)
    print(dirs)
    return dirs

import os

def rename_dirs(list, dir):
    renamed_dirs = []
    for d in list:
        print(d)
        sub_dir = os.path.join(dir, d, 'results', 'file summary reports')
        if os.path.exists(sub_dir):
            # store any file that ends with .pdf in variable sub
            sub = [f for f in os.listdir(sub_dir) if f.endswith('.pdf')]
            print(sub)
            for s in sub:
                # only keep four consecutive digits
                if s[0:4].isdigit():
                    s = s[0:4]
                    print(s)

                    # Use the updated string
                    updated_d = d.replace('output', f"sub-{s}")
                    final = os.path.join(dir, updated_d)
                    print(final)
                    renamed_dirs.append(final)

                    # Rename the directory
                    print('Renaming', os.path.join(dir, d), final)
                    os.rename(os.path.join(dir, d), final)

    return renamed_dirs

def structure_dirs(list, dir):
    for d in list:
        sub_split = d.split('_')[0]
        print(sub_split)
        ses_split = d.split('_')[1]
        print(ses_split)

        # create a new subject directory
        new_sub = os.path.join(dir, sub_split)
        print(new_sub)
        os.makedirs(new_sub, exist_ok=True)

        # move the renamed directory to the new subject directory
        print('Moving', d, new_sub)
        shutil.move(d, new_sub)
    return None



def main():
    arg = args()
    dirs = gather_dirs(arg.dir)
    structure_dirs(rename_dirs(dirs, arg.dir), arg.dir)

if __name__ == '__main__':
    main()
