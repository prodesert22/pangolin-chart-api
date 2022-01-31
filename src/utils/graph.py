import requests
import logging

from gql import Client, gql
from gql.transport.requests import RequestsHTTPTransport, log as requests_logger
from typing import Any, Dict, Optional

logger = logging.getLogger('__main__.' + __name__)
requests_logger.setLevel(logging.WARNING) # set gql log in warning
class Graph():

    def __init__(self, url: str) -> None:
        self.url = url
        transport = RequestsHTTPTransport(url=url)
        self.client = Client(transport=transport, fetch_schema_from_transport=False)

    def query(
            self,
            queryStr: str,
            params: Optional[Dict[str, Any]] = None,
    ) -> Optional[Dict[str, Any]]:
        # Query any the Graph api
        logger.debug(f'Querying Graph api for: {queryStr}')
        logger.debug(f'Params: {params}')
        try:
            result = self.client.execute(gql(queryStr), variable_values=params)
        except (requests.exceptions.RequestException, Exception) as e:
            logger.warn(f'Error in fetch graph api.\nerror: {e}\nurl: {self.url}\nQuery: {querystr}')
            return None

        return result
