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

        options = {
            'bind': f'{self.args.api_host}:{self.args.api_port}',
            'workers': 4,
            'accesslog': 'console.log',
            'logger_class': 'src.logging.GunicornLogger',
            'access_log_format': '"%(r)s" %(s)s %(b)s "%(f)s"'
        }

        self.api_server = APIServer(options)
        
        configure_logging(self.args)

    def stop(self) -> None:
        log.debug('Shutdown initiated')
        self.api_server.stop()

    def start(self) -> None:
        print(f'Running server at {self.args.api_host}:{self.args.api_port}')
        self.api_server.run()
