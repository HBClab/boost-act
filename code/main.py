from code.utils.group import Group
from code.core.gg import GG
from code.utils.pipe import Pipe
import sys
import logging

logging.basicConfig(
    level=logging.INFO,  # <-- this is key
    format='[%(levelname)s] %(message)s'
)
logger = logging.getLogger()  # root logger


if __name__ == '__main__':
    # Expect at least 2 arguments: daysago (integer) and token (string)
    if len(sys.argv) < 3:
        print("Usage: python main.py <daysago> <token> [system]")
        print("  <daysago> must be an integer, <token> must be a non-empty string.")
        print("  [system] optional values: 'vosslnx', 'argon', 'local' (default 'vosslnx').")
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

    # Parse system
    if len(sys.argv)>3:
        system = sys.argv[3]
    else: system = None
    if not system:
        print("System not specified, defaulting to 'vosslnx'.")
    elif system not in ['vosslnx', 'argon', 'local']:
        print("Error: <system> must be one of 'vosslnx', 'argon', or 'local'.")
        sys.exit(1)

    p = Pipe(token, daysago, system)
    p.run_pipe()

    Group(system).plot_person()
    Group(system).plot_session()
