import logging

from flask import Response
from flask_restful import Api, Resource
from gunicorn.app.base import BaseApplication
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

class APIServer(BaseApplication):
    
    def __init__(self, options=None) -> None:

        flask_api_context = api
        setup_urls(
            flask_api_context=flask_api_context,
            urls=URLS,
        )

        self.flask_app = app
        self.options = options or {}

        self.flask_app.errorhandler(HTTPStatus.NOT_FOUND)(endpoint_not_found)
        self.flask_app.register_error_handler(Exception, self.unhandled_exception)

        super().__init__()

    @staticmethod
    def unhandled_exception(exception: Exception) -> Response:
        """ Flask.errorhandler when an exception wasn't correctly handled """
        log.critical(
            "Unhandled exception when processing endpoint request",
            exc_info=True,
        )
        return api_response(wrap_in_fail_result(str(exception)), HTTPStatus.INTERNAL_SERVER_ERROR)

    def load_config(self):
        config = {key: value for key, value in self.options.items()
                  if key in self.cfg.settings and value is not None}
        for key, value in config.items():
            self.cfg.set(key.lower(), value)

    def load(self):
        return self.flask_app
