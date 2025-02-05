import os
import pandas as pd

"""
THIS FILE SYMBOLICALLY LINKS RDSS and LSS to working directory
"""

# Define paths
INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/bids'
OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/bids'
RDSS_DIR = '/Volumes/VossLab/Repositories/Accelerometer_Data'

def create_symlinks(target_dir='../mnt'):
    # Ensure the target directory exists
    os.makedirs(target_dir, exist_ok=True)

    # Define symbolic links
    symlinks = {
        'int_dir': INT_DIR,
        'obs_dir': OBS_DIR,
        'rdss_dir': RDSS_DIR
    }

    # Create symbolic links
    for link_name, target_path in symlinks.items():
        link_path = os.path.join(target_dir, link_name)
        try:
            # Remove existing symbolic link if it exists
            if os.path.islink(link_path) or os.path.exists(link_path):
                os.remove(link_path)
            os.symlink(target_path, link_path)
            print(f"Created symlink: {link_path} -> {target_path}")
        except OSError as e:
            print(f"Failed to create symlink for {link_name}: {e}")

