
from utils.mnt import create_symlinks
from utils.save import Save
from core.gg import GG
import sys

class Pipe:
    INT_DIR = '/mnt/nfs/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
    OBS_DIR = '/mnt/nfs/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
    RDSS_DIR = '/mnt/nfs/vosslab/Repositories/Accelerometer_Data'
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

        return None

    def _create_syms(self):
        return create_symlinks('../mnt')


