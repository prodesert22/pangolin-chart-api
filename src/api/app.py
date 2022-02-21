from flask import Flask
from flask_caching import Cache
from flask_cors import CORS
from flask_restful import Api

cache = Cache(config = {
    'CACHE_TYPE': 'FileSystemCache',
    'CACHE_DIR': 'cache', # path to your server cache folder
    'CACHE_THRESHOLD': 100000 # number of 'files' before start auto-delete
})

# Flask APP
app = Flask(__name__)
app.config['BUNDLE_ERRORS'] = True # https://flask-restful.readthedocs.io/en/0.3.6/reqparse.html#error-handling

# Flask API
api = Api(app)

# Init cache in app
cache.init_app(app)

# Add cors in api
cors = CORS(app, resources={r"*": {"origins": "*"}})