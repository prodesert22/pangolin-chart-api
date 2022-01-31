import json

from flask import Response, make_response, request as flask_request
from flask_restful import Resource, reqparse
from http import HTTPStatus
from typing import Any, Dict, List, Optional
from web3 import Web3

from src.api.app import cache
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
        ARGS: List[Dict[str, Any]] = [
            {
                "name": "tokenA",
                "type": str,
                "required": True,
                "location": "args",
                "help": "tokenA: {error_msg}",
            },
            {
                "name": "tokenB",
                "type": str,
                "required": True,
                "location": "args",
                "help": "tokenB: {error_msg}",
            },
            {
                "name": "period",
                "type": int,
                "required": True,
                "location": "args",
                "help": "Period invalid: {error_msg}",
                "choices": (
                    5 * 60,
                    15 * 60,
                    60 ** 2,
                    4 * 60 * 60,
                    24 * 60 * 60,
                    7 * 24 *  60 * 60,
                ),
            },
        ]
        args = add_args(ARGS)
        functions = api_functions.Candles()
        
        message = {}
        if not Web3.isAddress(args["tokenA"]):
            message["tokenA"] = "tokenA is not address"
        if not Web3.isAddress(args["tokenB"]):
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
                functions.get_candles(args["tokenA"], args["tokenB"], args["period"], 1000)
            )
        )
