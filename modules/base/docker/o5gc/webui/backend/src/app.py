import os
import sys
from typing import Mapping, Any

from flask import Flask
from flask_cors import CORS

from . import api


def create_app(config: Mapping[str, Any] | None = None):
    app = Flask(__name__, instance_relative_config=True)

    if config is None:
        app.config.from_envvar("FLASK_CONFIG_FILE")
    else:
        app.config.from_mapping(config)

    CORS(app)

    os.makedirs(app.instance_path, exist_ok=True)

    CORS(api.bp)
    app.register_blueprint(api.bp)

    return app
