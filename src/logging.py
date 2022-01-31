import argparse
import logging

from typing import Any, Dict, MutableMapping, Tuple

class LogsAdapter(logging.LoggerAdapter):

    def __init__(self, logger: logging.Logger):
        super().__init__(logger, extra={})

    def process(self, msg: str, kwargs: MutableMapping[str, Any]) -> Tuple[str, Dict]:
        """
        This is the main post-processing function for rotki logs

        This function also appends all kwargs to the final message.
        """
        msg += ','.join(' {}={}'.format(a[0], a[1]) for a in kwargs.items())
        return msg, {}

def configure_logging(args: argparse.Namespace) -> None:
    logger = logging.getLogger()
    handler = logging.FileHandler(
        filename=args.logfile, 
        encoding='utf-8', 
        mode='w',
    )
    loglevel = args.loglevel.upper()
    if loglevel == 'DEBUG':
        logger.setLevel(logging.DEBUG)
    elif loglevel == 'INFO':
        logger.setLevel(logging.INFO)
    elif loglevel == 'WARN':
        logger.setLevel(logging.WARN)
    elif loglevel == 'ERROR':
        logger.setLevel(logging.ERROR)
    elif loglevel == 'CRITICAL':
        logger.setLevel(logging.CRITICAL)
        
    #handler.setLevel(logging.INFO)
    handler.setFormatter(logging.Formatter('%(asctime)s:%(levelname)s:%(name)s: %(message)s'))
    logger.addHandler(handler) 
    