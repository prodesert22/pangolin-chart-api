import argparse

from typing import Any, List

class CommandAction(argparse.Action):
    """Interprets the positional argument as a command if that command exists"""
    def __init__(
            self,
            option_strings: List[str],
            dest: str,
            **kwargs: Any,
    ) -> None:
        super().__init__(option_strings, dest)

    def __call__(self) -> None:
        # Only command we have at the moment is version
        print('1.0.0')
        sys.exit(0)

def app_args(prog: str, description: str) -> argparse.ArgumentParser:
    """Add the rotki arguments to the argument parser and return it"""
    p = argparse.ArgumentParser(
        prog=prog,
        description=description,
    )
    p.add_argument(
        '--api-host',
        help='The host on which the rest API will run',
        default='127.0.0.1',
    )
    p.add_argument(
        '--rest-api-port',
        help='The port on which the rest API will run',
        type=int,
        default=43114,
    )
    p.add_argument(
        '--logfile',
        help='The name of the file to write log entries to',
        default='console.log',
    )
    p.add_argument(
        '--loglevel',
        help='Choose the logging level',
        choices=['debug', 'info', 'warn', 'error', 'critical'],
        default='debug',
    )
    p.add_argument(
        '--version',
        help='Shows the program version',
        action=CommandAction,
    )

    return p
