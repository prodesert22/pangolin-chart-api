import logging

from flask import Response
from flask_restful import Api, Resource
from gevent.pywsgi import WSGIServer
from http import HTTPStatus
from typing import List, Tuple
from werkzeug.exceptions import NotFound

from src.api.app import app, api
from src.api.resources import (
    api_response,
    wrap_in_fail_result,
    CandlesResource,
)
from src.logging import LogsAdapter

logger = logging.getLogger(__name__)
log = LogsAdapter(logger)

URLS = [
    ('/candles', CandlesResource),
]

def setup_urls(
        flask_api_context: Api,
        urls: List[Tuple[str, Resource]],
) -> None:
    for url_tuple in urls:
        if len(url_tuple) != 2:
            raise ValueError(f"Invalid URL format: {url_tuple!r}")
        route, resource_cls = url_tuple  # type: ignore
        endpoint = resource_cls.__name__.lower()
        flask_api_context.add_resource(
            resource_cls,
            route,
            endpoint=endpoint,
        )

def endpoint_not_found(e: 'NotFound') -> Response:
    # The isinstance check is because I am not sure if `e` is always going to
    # be a "NotFound" error here
    msg = e.description if isinstance(e, NotFound) else 'invalid endpoint'
    return api_response(wrap_in_fail_result(msg), HTTPStatus.NOT_FOUND)

class APIServer():
    
    def __init__(self) -> None:

        flask_api_context = api
        setup_urls(
            flask_api_context=flask_api_context,
            urls=URLS,
        )

        self.flask_app = app

        self.wsgiserver: Optional[WSGIServer] = None

        self.flask_app.errorhandler(HTTPStatus.NOT_FOUND)(endpoint_not_found)
        self.flask_app.register_error_handler(Exception, self.unhandled_exception)

    @staticmethod
    def unhandled_exception(exception: Exception) -> Response:
        """ Flask.errorhandler when an exception wasn't correctly handled """
        log.critical(
            "Unhandled exception when processing endpoint request",
            exc_info=True,
        )
        return api_response(wrap_in_fail_result(str(exception)), HTTPStatus.INTERNAL_SERVER_ERROR)

    def start(
            self,
            host: str = '127.0.0.1',
            port: int = 43114,
    ) -> None:
        wsgi_logger = logging.getLogger(f'{__name__}.pywsgi')
        self.wsgiserver = WSGIServer(
            listener=(host, port),
            application=self.flask_app,
            log=wsgi_logger,
            error_log=wsgi_logger,
        )
        msg = f'REST API server is running at: {host}:{port}'
        print(msg)
        log.info(msg)
        #create server 
        self.wsgiserver.serve_forever()

    def stop(self, timeout: int = 5) -> None:
        """Stops the API server. If handlers are running after timeout they are killed"""
        if self.wsgiserver is not None:
            self.wsgiserver.stop(timeout)
            self.wsgiserver = None
