import logging
from datetime import datetime

from src.constants.coins import (
    WAVAX,
    PNG,
    WETH,
    DAI,
    USDC,
    USDT,
)
from src.utils.graph import Graph

DEFAULTCOINS = [WAVAX, USDC, USDT, WETH, PNG, DAI]

logger = logging.getLogger('__main__.' + __name__)

cdef class Candles(): 
    cdef candlesSubgraph
    cdef exchangeSubgraph
    cdef list defaulCoins

    def __cinit__(self):
        self.candlesSubgraph = Graph("https://api.thegraph.com/subgraphs/name/pangolindex/pangolin-dex-candles")
        self.exchangeSubgraph = Graph("https://api.thegraph.com/subgraphs/name/pangolindex/exchange")

    cdef tuple order_pair(self, str tokenA, str tokenB):
        """Order the tokens for token0 and token1 according to the order in the blockchain

        Args:
            tokenA str: address of tokenA.
            tokenb str: address of tokenB.
        Returns:
            token0 str: address of token0.
            token1 str: address of token1.
        """

        cdef list pair = [tokenA, tokenB]
        pair.sort()
        cdef str token0 = pair[0]
        cdef str token1 = pair[1]
        return token0, token1

    cdef float current_price(self, str tokenA, str tokenB, str midToken = ""):
        """Get current price of tokenA in relation to tokenB, if there is a token between them, use that token to get the price

        Args:
            tokenA str: address of tokenA.
            tokenb str: address of tokenB.
            midToken str: address of token between tokenA and tokenB. (optional)
        Returns:
            currentPrice: float: price of tokenA/tokenB 
        """

        cdef str queryStr = """
            query pairData($token0: String!, $token1: String!) {
                pairs(where: {token0: $token0, token1: $token1}) {
                    reserve0
                    reserve1
                }
            }
        """
        # if not exist modToken, use only tokenA and tokenB
        if midToken == "":
            token0, token1 = self.order_pair(tokenA, tokenB)
            params = {
                "token0": token0,
                "token1": token1,
            }

            result = self.exchangeSubgraph.query(queryStr, params)

            if result is not None and result["pairs"] and len(result["pairs"]) > 0:
                reserve0 = float(result["pairs"][0]["reserve0"])
                reserve1 = float(result["pairs"][0]["reserve1"])

                if reserve0 == 0 or reserve1 == 0:
                    return 0

                if(token0 == tokenA):
                    return reserve1/reserve0 # reserve_tokenA / reserve_tokenB 
                else:
                    return reserve0/reserve1 # reserve_tokenB / reserve_tokenA

        else:
            # if exist midToken, get price of tokenA in relation to midToken and midToken in relation of tokenB
            token0, token1 = self.order_pair(tokenA, midToken)
            token2, token3 = self.order_pair(tokenB, midToken)

            params = {
                "token0": token0,
                "token1": token1,
            }

            result = self.exchangeSubgraph.query(queryStr, params)

            params["token0"] = token2
            params["token1"] = token3
            result2 = self.exchangeSubgraph.query(queryStr, params)

            if (
                result is not None and
                result2 is not None and
                result["pairs"] and
                result2["pairs"] and
                len(result["pairs"]) > 0 and
                len(result2["pairs"]) > 0
            ):
                reserve0 = float(result["pairs"][0]["reserve0"])
                reserve1 = float(result["pairs"][0]["reserve1"])
                reserve2 = float(result2["pairs"][0]["reserve0"])
                reserve3 = float(result2["pairs"][0]["reserve1"])
                if (reserve0 == 0 or reserve1 == 0 or reserve2 == 0 or reserve3 == 0):
                    return 0
                # I used the following formula (a/b) / (c/d) = (a*d)/(c*b)
                if(token0 == tokenA and token2 == tokenB):
                    return (reserve1*reserve2)/(reserve0/reserve3) # (reserve_DefaultToken / reserve_tokenA) / (reserve_DefaultToken / reserve_tokenB)
                elif(token1 == tokenA and token2 == tokenB):
                    return (reserve0*reserve2)/(reserve1*reserve3) # (reserve_tokenA / reserve_DefaultToken) / (reserve_DefaultToken / reserve_tokenB)
                elif(token0 == tokenA and token3 == tokenB):
                    return (reserve1*reserve3)/(reserve0*reserve2) # (reserve_DefaultToken / reserve_tokenA) / (reserve_tokenB / reserve_DefaultToken)
                else:
                    return (reserve0*reserve3)/(reserve1*reserve2) # (reserve_tokenA / reserve_DefaultToken) / (reserve_tokenB / reserve_DefaultToken)

        return 0

    cdef list format_candles(self, list candles, tokenA, token0):
        """If token0 == tokenA we have to invert it because the subgraph returns the value in token1/token0

        Args:
            candles list: list of candles.
            tokenA str: address of tokenA.
            tokenb str: address of tokenB.
        Returns:
            candles list: list of formatted candles
        """

        for i in range(len(candles)):
            candles[i] = {
                "close": 1/float(float(candles[i]["close"])) if tokenA == token0 else float(float(candles[i]["close"])),
                "high": 1/float(float(candles[i]["high"])) if tokenA == token0 else float(float(candles[i]["high"])),
                "low": 1/float(float(candles[i]["low"])) if tokenA == token0 else float(float(candles[i]["low"])),
                "open": 1/float(float(candles[i]["open"])) if tokenA == token0 else float(float(candles[i]["open"])),
                "time": candles[i]["time"],
            }

        return candles[::-1] # invert the array to asc order of time

    cdef list update_current_price(self, list candles, str tokenA, str tokenB, int interval, str midToken = ""):
        """This function update last candle with current price or add more candles that is missing

        Args:
            candles list: list of candles.
            tokenA str: address of tokenA.
            tokenb str: address of tokenB.
            interval int: interval between candles in seconds
            midToken str: midToken str: address of token between tokenA and tokenB. (optional).
        Returns:
            candles list: list of formatted candles
        """

        cdef float currentPrice = self.current_price(tokenA, tokenB, midToken)
        logger.debug(f"currentPrice {currentPrice}")
        cdef float timestamp = datetime.now().timestamp()
        cdef int lastTime = candles[-1]["time"]
        if timestamp > lastTime+interval:
            # is missing for example 3 candles, 3 new candles will be add
            missingCandles = int((lastTime+interval)/timestamp)
            missingCandles = missingCandles if missingCandles < 1000 else 1000
            # apply currentPrice in last candle
            for i in range(missingCandles):
                candles.append({
                    "close": currentPrice,
                    "high": currentPrice if currentPrice > candles[-1]["close"] else candles[-1]["close"],
                    "low": currentPrice if currentPrice < candles[-1]["close"] else candles[-1]["close"],
                    "open": candles[-1]["close"],
                    "time": timestamp,
                })
        else:
            candles[-1]["close"] = currentPrice
            if currentPrice > candles[-1]["high"]:
                candles[-1]["high"] = currentPrice

            if currentPrice < candles[-1]["low"]:
                candles[-1]["low"] = currentPrice

        return candles

    cdef list fetch_candles(self, str token0, str token1, int interval, int limit, int skip):
        """# Return candles of pangolin subgraph, return inverted tokens, token0/token1 > token1/token0

        Args:
            token0 str: address of token0.
            token1 str: address of token1.
            interval int: interval between candles in seconds.
            limit int: max of candles.
            skip int: number of tokens to skip.
        Returns:
            candles list: list of formatted candles
        """

        cdef str queryStr = """
            query dexCandlesQuery($token0: String!, $token1: String!, $interval: Int!, $limit: Int!, $skip: Int!) {
                candles(first: $limit, skip: $skip, orderBy: time, orderDirection: desc, where: {token0: $token0, token1: $token1, period: $interval}) {
                    time
                    open
                    low
                    high
                    close
                }
            }
        """

        cdef dict params = {
            "token0": token0,
            "token1": token1,
            "interval": interval,
            "limit": limit,
            "skip": skip
        }

        cdef dict result = self.candlesSubgraph.query(queryStr, params)

        if result is not None and result["candles"]:
            return result["candles"]

        return []
    
    def get_candles(self, str tokenA, str tokenB, int interval, int limit = 1000, int skip = 0):
        # Temporary function
        token0, token1 = self.order_pair(tokenA, tokenB)
        candles = self.fetch_candles(
            token0,
            token1,
            interval,
            limit,
            skip,
        )

        # Accepts at least 10% of limit as the amount of candles 
        if len(candles) < (limit/100)*10: # If there aren't enough candles, try get candles by top tokens in pangolin
            # takes the price of tokenA in relation to defaultCoin and the price of tokenB in relation to defaultCoin and calculates the price
            for defaultCoin in DEFAULTCOINS:
                defaultCoin = defaultCoin.lower()
                if defaultCoin == tokenA or defaultCoin == tokenB:
                    continue 

                token0, token1 = self.order_pair(tokenA, defaultCoin)
                token2, token3 = self.order_pair(defaultCoin, tokenB)
                candles = self.fetch_candles(
                    token0,
                    token1,
                    interval,
                    limit,
                    0,
                )

                candles2 = self.fetch_candles(
                    token2,
                    token3,
                    interval,
                    limit,
                    0,
                )
                if len(candles) >= (limit/100)*10 and len(candles2) >= (limit/100)*10:
                    # filters candles where there is the same timestamp in the other candle
                    if len(candles) < len(candles2):
                        avariableTimes = [candle["time"] for candle in candles]
                        candles2 = list(filter(lambda d: d['time'] in avariableTimes, candles2))
                    elif len(candles2) < len(candles):
                        avariableTimes = [candle["time"] for candle in candles2]
                        candles = list(filter(lambda d: d['time'] in avariableTimes, candles))
                    # tokenA/defaultCoin | tokenB/defaultCoin
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
            
                    # defaultCoin/tokenA | defaultCoin/tokenB
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

                    # tokenA/defaultCoin | defaultCoin/tokenB
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
                    
                    # defaultCoin/tokenA | tokenB/defaultCoin
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
                    candles = candles[::-1] # invert the array to asc order of time
                    candles = self.update_current_price(candles, tokenA, tokenB, interval, defaultCoin)
                    return candles
                else:
                    continue

        candles = self.format_candles(candles, tokenA, token0)
        candles = self.update_current_price(candles, tokenA, tokenB, interval)
        return candles
