import os
from pathlib import Path

BASE_DIR = Path(os.getenv("BASE"))
ENV_DIR = BASE_DIR / "etc"
MODULES_DIR = BASE_DIR / "modules"
GLOBAL_ENV_PATH = ENV_DIR / "settings.env"
UE_ENV_PATH = ENV_DIR / "uedb.env"
STACK_ENV_FILENAME = "settings.env"
ENV_OVERRIDES_DIR = Path("/tmp/")
STATUS_MODULE_PATH = Path(__file__).resolve().parent / "status.py"
PYSIM_SCRIPTS_PATH = Path("/o5gc-simcard-scripts")
