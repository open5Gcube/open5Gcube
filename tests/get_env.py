import os
from pathlib import Path
from dotenv import dotenv_values
from robot.libraries.BuiltIn import BuiltIn

class get_env:
    def __init__(self):
        suite_source = Path(BuiltIn().get_variable_value("${SUITE SOURCE}"))
        base_dir = Path(os.getenv('BASE_DIR'))
        env_dir = Path(os.getenv('ENV_DIR'))
        stack = suite_source.parent.parent.name
        module = suite_source.relative_to(base_dir).parts[1]
        env_file = env_dir / module / f'{stack}.env'
        self.config = dotenv_values(env_file)

    def get_env(self, name):
        return self.config[name]
