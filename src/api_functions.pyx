import logging

from src.constants.coins import (
    WAVAX,
    PNG,
    WETH,
    DAI,
    USDC,
    USDT,
)
from src.utils.graph import Graph

DEFAULTCOINS = [WAVAX, PNG, WETH, DAI, USDC, USDT]

logger = logging.getLogger('__main__.' + __name__)

cdef class Candles(): 
    cdef candlesSubgraph
    cdef exchangeSubgraph
    cdef list defaulCoins

    def __cinit__(self):
        self.candlesSubgraph = Graph("https://api.thegraph.com/subgraphs/name/pangolindex/pangolin-dex-candles")
        self.exchangeSubgraph = Graph("https://api.thegraph.com/subgraphs/name/pangolindex/exchange")

    cdef tuple order_pair(self, str tokenA, str tokenB):
        cdef list pair = [tokenA, tokenB]
        pair.sort()
        cdef str token0 = pair[0]
        cdef str token1 = pair[1]
        return token0, token1

    cdef list format_candles(self, list candles, tokenA, token0):
        for i in range(len(candles)):
            candles[i] = {
                "close": 1/float(float(candles[i]["close"])) if tokenA == token0 else float(float(candles[i]["close"])),
                "high": 1/float(float(candles[i]["high"])) if tokenA == token0 else float(float(candles[i]["high"])),
                "low": 1/float(float(candles[i]["low"])) if tokenA == token0 else float(float(candles[i]["low"])),
                "open": 1/float(float(candles[i]["open"])) if tokenA == token0 else float(float(candles[i]["open"])),
                "time": candles[i]["time"],
            }
        return candles 

    cdef list fetch_candles(self, str token0, str token1, int period, int limit):
        # Return candles of pangolin subgraph, return inverted tokens, token0/token1 > token1/token0
        cdef str queryStr = """
            query dexCandlesQuery($token0: String!, $token1: String!, $period: Int!, $limit: Int!) {
                candles(first: $limit, orderBy: time, orderDirection: desc, where: {token0: $token0, token1: $token1, period: $period}) {
                    time
                    open
                    low
                    high
                    close
                }
            }
        """

        cdef dict params = {
            "token0": token0.lower(),
            "token1": token1.lower(),
            "period": period,
            "limit": limit,
        }

        cdef dict result = self.candlesSubgraph.query(queryStr, params)

        if result["candles"]:
            return result["candles"]

        return []
    
    def get_candles(self, str tokenA, str tokenB, int period, int limit = 1000):
        # Temporary function
        token0, token1 = self.order_pair(tokenA, tokenB)
        candles = self.fetch_candles(
            token0,
            token1,
            period,
            limit,
        )

        # Accepts at least 10% of limit ass the amount of candles 
        if len(candles) >= (limit/100)*10:
            candles = self.format_candles(candles, tokenA, token0)
        else: # Try get candles by top tokens in pangolin
            # takes the price of tokenA in relation to defaultCoin and the price of tokenB in relation to defaultCoin and calculates the price by 
            for defaultCoin in DEFAULTCOINS:
                if defaultCoin == tokenA or defaultCoin == tokenB:
                    continue 

                token0, token1 = self.order_pair(tokenA, defaultCoin)
                token2, token3 = self.order_pair(defaultCoin, tokenB)
                candles = self.fetch_candles(
                    token0,
                    token1,
                    period,
                    limit,
                )

                candles2 = self.fetch_candles(
                    token2,
                    token3,
                    period,
                    limit,
                )

                if len(candles) >= (limit/100)*10 and len(candles2) >= (limit/100)*10 and len(candles) == len(candles2):
                    # tokenA/defaultCoin - tokenB/defaultCoin
                    if defaultCoin == token0 and defaultCoin == token2:
                        for i in range(len(candles)):
                            close = float(float(candles[i]["close"]))/float(candles2[i]["close"])
                            high = float(candles[i]["high"])/float(candles2[i]["high"])
                            low = float(candles[i]["low"])/float(candles2[i]["low"])
                            open = float(candles[i]["open"])/float(candles2[i]["open"])
                            candles[i] = {
                                "close": float(close),
                                "high": float(high),
                                "low": float(low),
                                "open": float(open),
                                "time": candles[i]["time"],
                            }
            
                    # defaultCoin/tokenA - defaultCoin/tokenB
                    elif defaultCoin == token1 and defaultCoin == token3:
                        for i in range(len(candles)):
                            close = float(candles2[i]["close"])/float(candles[i]["close"])
                            high = float(candles2[i]["high"])/float(float(candles[i]["high"]))
                            low = float(candles2[i]["low"])/float(candles[i]["low"])
                            open = float(candles2[i]["open"])/float(candles[i]["open"])
                            candles[i] = {
                                "close": float(close),
                                "high": float(high),
                                "low": float(low),
                                "open": float(open),
                                "time": candles[i]["time"],
                            }

                    # tokenA/defaultCoin - defaultCoin/tokenB
                    elif defaultCoin == token0 and defaultCoin == token3:
                        for i in range(len(candles)):
                            close = float(candles[i]["close"])/(1/float(candles2[i]["close"]))
                            high = float(candles[i]["high"])/(1/float(candles2[i]["high"]))
                            low = float(candles[i]["low"])/(1/float(candles2[i]["low"]))
                            open = float(candles[i]["open"])/(1/float(candles2[i]["open"]))
                            candles[i] = {
                                "close": float(close),
                                "high": float(high),
                                "low": float(low),
                                "open": float(open),
                                "time": candles[i]["time"],
                            }
                    
                    # defaultCoin/tokenA - tokenB/defaultCoin
                    else:
                        for i in range(len(candles)):
                            close = (1/float(candles[i]["close"]))/float(candles2[i]["close"])
                            high = (1/float(candles[i]["high"]))/float(candles2[i]["high"])
                            low = (1/float(candles[i]["low"]))/float(candles2[i]["low"])
                            open = (1/float(candles[i]["open"]))/float(candles2[i]["open"])
                            candles[i] = {
                                "close": float(close),
                                "high": float(high),
                                "low": float(low),
                                "open": float(open),
                                "time": candles[i]["time"],
                            }

                if len(candles) >= (limit/100)*10 :
                    return candles
                continue

        return candles
