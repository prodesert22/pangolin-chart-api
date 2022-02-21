import logging
import numpy as np

from datetime import datetime

from src.constants.coins import (
    WAVAX,
    USDC,
    USDT,
)
from src.utils.graph import Graph
from src.utils.worker import Worker

DEFAULTCOINS = [WAVAX, USDC, USDT]

logger = logging.getLogger('__main__.' + __name__)

cdef class Candles(): 
    cdef candlesSubgraph
    cdef exchangeSubgraph
    cdef list defaulCoins

    def __cinit__(self):
        self.candlesSubgraph = "https://api.thegraph.com/subgraphs/name/pangolindex/pangolin-dex-candles" 
        self.exchangeSubgraph = "https://api.thegraph.com/subgraphs/name/pangolindex/exchange"

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

    cdef dict get_pair_data(self, str token0, str token1):
        cdef str queryStr = """
            query pairData($token0: String!, $token1: String!) {
                pairs(where: {token0: $token0, token1: $token1}) {
                    reserve0
                    reserve1
                    reserveUSD
                }
            }
        """

        params = {
            "token0": token0,
            "token1": token1,
        }

        result = Graph(self.exchangeSubgraph).query(queryStr, params)
        return result

    cdef float current_price(self, str tokenA, str tokenB, str midToken = ""):
        """Get current price of tokenA in relation to tokenB, if there is a token between them, use that token to get the price

        Args:
            tokenA str: address of tokenA.
            tokenb str: address of tokenB.
            midToken str: address of token between tokenA and tokenB. (optional)
        Returns:
            currentPrice: float: price of tokenA/tokenB 
        """

        # if not exist modToken, use only tokenA and tokenB
        if midToken == "":
            token0, token1 = self.order_pair(tokenA, tokenB)

            result = self.get_pair_data(token0, token1)

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

            result = self.get_pair_data(token0, token1)
            result2 = self.get_pair_data(token2, token3)

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
        if len(candles) == 0:
            return candles

        cdef float currentPrice = self.current_price(tokenA, tokenB, midToken)
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

        cdef dict result = Graph(self.candlesSubgraph).query(queryStr, params)

        if result is not None and result["candles"]:
            return result["candles"]

        return []
    
    cdef list smooth_candles(self, list candles):
        """# Smooth the candles, remove bad candles

        Args:
            candles list: list of candles
        Returns:
            candles list: list of smooth candles
        """
        close, high, low, open, times = zip(*map(dict.values, candles))
        
        # https://stackoverflow.com/a/65200210/18268694
        # https://blog.finxter.com/how-to-find-outliers-in-python-easily/
        def outlier_smoother(x, m=7, win=3):
            ''' finds outliers in x, points > m*mdev(x) [mdev:median deviation] 
            and replaces them with the median of win points around them '''
            x_corr = x[::]
            d = np.abs(x - np.median(x))
            mdev = np.median(d)
            idxs_outliers = np.nonzero(d > m*mdev)[0]
            for i in idxs_outliers:
                if i-win < 0:
                    x_corr[i] = np.median(np.append(x[0:i], x[i+1:i+win+1]))
                elif i+win+1 > len(x):
                    x_corr[i] = np.median(np.append(x[i-win:i], x[i+1:len(x)]))
                else:
                    x_corr[i] = np.median(np.append(x[i-win:i], x[i+1:i+win+1]))
            return x_corr

        smooth_close = outlier_smoother(np.array(close))
        smooth_high = outlier_smoother(np.array(high))
        smooth_low = outlier_smoother(np.array(low))
        smooth_open = outlier_smoother(np.array(open))

        cdef list smooth_candles = []
        for candle in zip(smooth_close, smooth_high, smooth_low, smooth_open, times):
            smooth_candles.append({
                "close": candle[0],
                "high": candle[1],
                "low": candle[2],
                "open": candle[3],
                "time": candle[4],
            })

        for i in range(1, len(smooth_candles)-1):
            smooth_candles[i]['open'] =  smooth_candles[i-1]['close']

        return smooth_candles

    def get_candles(self, str tokenA, str tokenB, int interval, int limit = 1000, int skip = 0):
        # Temporary function
        token0, token1 = self.order_pair(tokenA, tokenB)

        fetchCandles = Worker(
            self.fetch_candles,
            self,
            token0,
            token1,
            interval,
            limit,
            skip,
        )

       # pairData = self.get_pair_data(token0, token1)

        fetchPairData = Worker(
            self.get_pair_data,
            self,
            token0,
            token1
        )

        fetchCandles.start()
        fetchPairData.start()

        fetchCandles.join()
        fetchPairData.join()

        candles = fetchCandles.result
        pairData = fetchPairData.result

        if len(pairData['pairs']):
            reserveUSD = float(pairData['pairs'][0]['reserveUSD'])
        else:
            reserveUSD = 0

        # Accepts at least 10% of limit as the amount of candles 
        if len(candles) < (limit/100)*10 and reserveUSD < 3000: # If there aren't enough candles, try get candles by top tokens in pangolin
            # takes the price of tokenA in relation to defaultCoin and the price of tokenB in relation to defaultCoin and calculates the price
            workers = []
            for defaultCoin in DEFAULTCOINS:
                if defaultCoin == tokenA or defaultCoin == tokenB:
                    workers.append(None)
 
                token0, token1 = self.order_pair(tokenA, defaultCoin)
                token2, token3 = self.order_pair(defaultCoin, tokenB)
                workers.append(Worker(
                    self.fetch_candles,
                    self,
                    token0,
                    token1,
                    interval,
                    limit,
                    0,
                ))

                workers.append(Worker(
                    self.fetch_candles,
                    self,
                    token2,
                    token3,
                    interval,
                    limit,
                    0,
                ))

            for worker in workers:
                if worker is not None:
                    worker.start()

            for worker in workers:
                if worker is not None:
                    worker.join()  

            for i in range(0, len(workers)-1, 2):
                index = int(i/2)
                defaultCoin = DEFAULTCOINS[index].lower()
                if workers[i] is None or workers[i+1] is None:
                    continue 

                token0, token1 = self.order_pair(tokenA, defaultCoin)
                token2, token3 = self.order_pair(defaultCoin, tokenB)

                candles = workers[i].result
                candles2 = workers[i+1].result

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
                    candles = self.smooth_candles(candles)
                    return candles
                else:
                    continue
        if len(candles) > 0:
            candles = self.format_candles(candles, tokenA, token0)
            candles = self.update_current_price(candles, tokenA, tokenB, interval)
            candles = self.smooth_candles(candles)
        return candles
