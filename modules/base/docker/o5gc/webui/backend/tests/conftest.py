import importlib
from pathlib import Path

import pytest
from src import create_app
import shutil


@pytest.fixture
def app(tmp_path):
    app = create_app({
        "TESTING": True,
        "DEBUG": True,
        "STACKS_DIR": tmp_path / "test_instance" / "etc",
        "STATUS_MODULE_PATH": tmp_path / "test_instance" / "status.py",
        "BASE_DIR": tmp_path / "test_instance",
        "GLOBAL_ENV_PATH": tmp_path / "test_instance" / "etc" / "settings.env",
        "STACK_ENV_FILENAME": "settings.env",
        "ENV_OVERRIDES_DIR": tmp_path / "test_instance" / "var" / "etc"
    })

    # Copy contents of test_stacks to the tmp directory to mess around with them later
    shutil.copytree(Path(__file__).parent / "test_instance", tmp_path / "test_instance")

    yield app

    # Reload the api module so the Blueprint is created anew for the next test
    # Otherwise the cors plugin will fail to when it's trying to register again
    from src import api
    importlib.reload(api)


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def runner(app):
    return app.test_cli_runner()
