# pangolin-chart-api
Wrapped api for pangolin dex candles subgraph

## Install

### Create Python Environment
`python -m venv env`

*env is arbitrary name of environment, it can be your choice but you must use the same name to activate your environment*

### Active Environment 

#### On Linux
Run the command bellow:

`source <path to env>/env/bin/activate`

#### On Windows
Run the command bellow:

`<path to env>\env\Scripts\activate.bat`

### Install packages

`pip install -r requirements.txt`

## Run

`python main.py <args>`

**Args**
| Name     | Description | Default |
|----------|----------|---------|
| --api-host | the host on which the rest API will run | 127.0.0.1 |
| --rest-api-port | The port on which the rest API will run | 43114|
| --logfile  | The name of the file to write log entries | console.log|
| --loglevel | Choose the logging level  | info |
| --version  | Shows the program version |

## Endpoints
### candles
`/candles?tokenA=<address>&tokenB=<address>&interval=<interval>`

This endpoint return all candles in the requested range between tokenA/tokenB 

**Params**
| Name     | Description | Required|
|----------|----------|----------|
| tokenA   | address of tokenA | Yes|
| tokenB   | address of tokenB | Yes|
| interval | Interval between candles in seconds | Yes|
| limit    | Total number of candles | No (default 100)|
| skip     | Number of candles to skip | No (default 0)|

*supported intervals: 5m (300), 15m (900), 1h (3600), 4h (14400), 1d (86400) and 7d (604800)*
### Example
`/candles?tokenA=0x60781c2586d68229fde47564546784ab3faca982&tokenB=0xd586e7f844cea2f87f50152665bcbc2c279d8d70&interval=300`

Returns the PNG/DAI.e pair price candles  
