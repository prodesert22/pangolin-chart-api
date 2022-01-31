from flask import Flask
from flask_caching import Cache
from flask_cors import CORS
from flask_restful import Api

cache = Cache(config={'CACHE_TYPE': 'SimpleCache'})

# Flask APP
app = Flask(__name__)
app.config['BUNDLE_ERRORS'] = True # https://flask-restful.readthedocs.io/en/0.3.6/reqparse.html#error-handling

# Flask API
api = Api(app)

# Init cache in app
cache.init_app(app)

# Add cors in api
cors = CORS(app, resources={r"*": {"origins": "*"}})