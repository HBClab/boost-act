from utils.mnt import create_symlinks
from utils.save import Save
from core.gg import GG

INT_DIR = '/mnt/nfs/lss/vosslabhpc/Projects/BOOST/InterventionStudy/3-experiment/data/act-int-test'
OBS_DIR = '/mnt/nfs/lss/vosslabhpc/Projects/BOOST/ObservationalStudy/3-experiment/data/act-obs-test'
RDSS_DIR = '/mnt/nfs/rdss/vosslab/Repositories/Accelerometer_Data'

class pipe:
    def __init__(self):
        self.funny = False # i happen to be pretty lame

    def run_pipe(self):
        self._create_syms()
        matched = Save(intdir=INT_DIR, obsdir=OBS_DIR, rdssdir=RDSS_DIR).save()
        with open('res/data.json', 'w') as file:
            file.write('{\n}')
            file.write(',\n'.join(f'   "{key}": "{value}"' for key, value in matched.items()))
        #GG(matched=matched, intdir=INT_DIR, obsdir=OBS_DIR).run_gg()
        return None

    def _create_syms(self):
        return create_symlinks('../mnt')


if __name__ == '__main__':
    p = pipe()
    p.run_pipe()
