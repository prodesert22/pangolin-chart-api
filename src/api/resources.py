import json

from flask import Response, make_response, request as flask_request
from flask_restful import Resource, reqparse
from http import HTTPStatus
from typing import Any, Dict, List, Optional
from eth_utils import is_address

from src.api.app import cache
from src.api.args import CANDLES_ARGS

import api_functions

def _wrap_in_ok_result(result: Any) -> Dict[str, Any]:
    return {'result': result, 'message': ''}

def _wrap_in_result(result: Any, message: str) -> Dict[str, Any]:
    return {'result': result, 'message': message}

def wrap_in_fail_result(message: str, status_code: Optional[HTTPStatus] = None) -> Dict[str, Any]:
    result: Dict[str, Any] = {'result': None, 'message': message}
    if status_code:
        result['status_code'] = status_code

    return result

def api_response(
        result: Dict[str, Any],
        status_code: HTTPStatus = HTTPStatus.OK,
) -> Response:
    if status_code == HTTPStatus.NO_CONTENT:
        assert not result, "Provided 204 response with non-zero length response"
        data = ""
    else:
        data = json.dumps(result)
        
    return make_response(
        (data, status_code, {"mimetype": "application/json", "Content-Type": "application/json"}),
    )

def cache_key() -> str:
    #return cache key with args
    url_args = flask_request.args
    args = "?"
    args += '&'.join(
        f"{item[0]}={str(item[1]).lower()}" for item in url_args.items()
    )
    if args != "?":
        return flask_request.base_url+args
    return flask_request.base_url

def add_args(args: List[Dict[str, Any]]):
    parser = reqparse.RequestParser()
    for arg in args:
        parser.add_argument(**arg)
    return parser.parse_args()

class CandlesResource(Resource):
    
    @cache.cached(timeout=300, key_prefix=cache_key)
    def get(self) -> Response:
        args = add_args(CANDLES_ARGS)
        functions = api_functions.Candles()
        
        message = {}
        if not is_address(args["tokenA"]):
            message["tokenA"] = "tokenA is not address"
        if not is_address(args["tokenB"]):
            message["tokenB"] = "tokenB is not address"
        
        if message.keys():
            return api_response(
                wrap_in_fail_result(
                    message,
                    HTTPStatus.BAD_REQUEST
                )
            )

        return api_response(
            _wrap_in_ok_result(
                functions.get_candles(
                    args["tokenA"].lower(),
                    args["tokenB"].lower(),
                    args["interval"],
                    args["limit"],
                    args["skip"],
                )
            )
        )
