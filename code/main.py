from utils.mnt import create_symlinks
from utils.save import Save
from core.gg import GG
import sys

INT_DIR = '/Volumes/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
OBS_DIR = '/Volumes/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
RDSS_DIR = '/Volumes/VossLab/Repositories/Accelerometer_Data'

class pipe:
    def __init__(self, daysago=None):
        self.daysago = daysago

    def run_pipe(self):
        self._create_syms()
        matched = Save(intdir=INT_DIR, obsdir=OBS_DIR, rdssdir=RDSS_DIR, daysago=self.daysago).save()
        with open('code/res/data.json', 'w') as file:
            file.write('{\n}')
            file.write(',\n'.join(f'   "{key}": "{value}"' for key, value in matched.items()))
        #GG(matched=matched, intdir=INT_DIR, obsdir=OBS_DIR).run_gg()
        return None

    def _create_syms(self):
        return create_symlinks('../mnt')


if __name__ == '__main__':
    if len(sys.argv) > 1:  # Ensure there's an argument
        try:
            daysago = int(sys.argv[1])  # Convert argument to integer
        except ValueError:
            print("Error: daysago must be an integer")
            sys.exit(1)  # Exit script with error
    else:
        daysago = None  # Default to None if no argument is provided

    p = pipe(daysago=daysago)
    p.run_pipe()
