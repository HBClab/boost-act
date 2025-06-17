from utils.mnt import create_symlinks
from utils.save import Save
from utils.group import Group
from core.gg import GG
import sys


class Pipe:
    INT_DIR = '/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
    OBS_DIR = '/mnt/nfs/lss/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
    RDSS_DIR = '/mnt/nfs/rdss/vosslab/Repositories/Accelerometer_Data'
    def __init__(self, token, daysago):
        self.token = token
        self.daysago = daysago

    def run_pipe(self):
        self._create_syms()
        matched = Save(
            intdir=self.INT_DIR,
            obsdir=self.OBS_DIR,
            rdssdir=self.RDSS_DIR,
            token=self.token,
            daysago=self.daysago
        ).save()

        with open('res/data.json', 'w') as file:
            file.write('{\n}')
            file.write(',\n'.join(f'   "{key}": "{value}"' for key, value in matched.items()))

        GG(matched=matched, intdir=self.INT_DIR, obsdir=self.OBS_DIR).run_gg()
        Group().plot_person()
        Group().plot_session()

        return None

    def _create_syms(self):
        return create_symlinks('../mnt')


if __name__ == '__main__':
    # Expect exactly 2 arguments: daysago (integer) and token (string)
    if len(sys.argv) != 3:
        print("Usage: python main.py <daysago> <token>")
        print("  <daysago> must be an integer, <token> must be a non-empty string.")
        sys.exit(1)

    # Parse daysago
    try:
        daysago = int(sys.argv[1])
    except ValueError:
        print("Error: <daysago> must be an integer.")
        sys.exit(1)

    # Parse token
    token = sys.argv[2]
    if not token:
        print("Error: <token> cannot be empty.")
        sys.exit(1)

    p = Pipe(token, daysago)
    p.run_pipe()
