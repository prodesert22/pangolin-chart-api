from src.api.server import APIServer
from src.args import app_args
from src.logging import configure_logging

class Server():
    def __init__(self) -> None:
        """Initializes the backend server
        May raise:
        - SystemPermissionError due to the given args containing a datadir
        that does not have the correct permissions
        """
        arg_parser = app_args(
            prog='Pangolin Candles Api',
            description=(
                'Api for get candles of tokens in Pangolin Dex'
            ),
        )
        self.args = arg_parser.parse_args()
        
        self.api_server = APIServer()
        
        configure_logging(self.args)
        
    def stop(self) -> None:
        log.debug('Shutdown initiated')
        self.api_server.stop()
    
    def start(self) -> None:
        self.api_server.start(
            host=self.args.api_host,
            port=self.args.rest_api_port,
        )
