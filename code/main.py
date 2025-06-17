from utils.mnt import create_symlinks
from utils.save import Save
from utils.group import Group
from core.gg import GG
from utils.pipe import Pipe
import sys
import logging

logging.basicConfig(
    level=logging.DEBUG,  # <-- this is key
    format='[%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)


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

    Group().plot_person()
    Group().plot_session()

