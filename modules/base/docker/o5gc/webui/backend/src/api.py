import importlib
import shlex
import re
import docker
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from types import ModuleType
from http import HTTPStatus

import pytz
import dotenv
import kiopcgenerator
from flask import Blueprint, current_app, request, Response, abort
import jsonschema

bp = Blueprint('api', __name__, url_prefix='/api')


@bp.get('/stacks')
def get_stacks():
    stacks = sorted([stack for stack in current_app.config["MODULES_DIR"].glob("*/stacks/*") if stack.is_dir()])
    return {
        "stacks": [
            {"module_name": stack.parts[-3], "stack_name": stack.parts[-1]}
            for stack in stacks if stack.name not in ("__pycache__",)
        ]
    }

def get_module(stack_name):
    for stack in get_stacks()['stacks']:
        if stack['stack_name'] == stack_name:
            return stack['module_name']
    return None

def run_cmd(cmd):
    result = subprocess.run(cmd, cwd=current_app.config["BASE_DIR"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return ('$ ' + ' '.join(cmd) + '\n' + result.stdout.decode('utf-8'), result.returncode)

@bp.post('/stack/<string:stack_name>')
def start_stack(stack_name: str):
    # JSONSchema for the POST payload
    post_payload_schema = {
        "type": "object",
        "properties": {
            "env": {
                "type": "object",
                "patternProperties": {
                    ".*": {"type": "string"}
                }
            },
            "env_file": {
                "type": "string"
            }
        },
        "required": [],
        # Disallow env and env_file to both be present
        "not": {
            "required": ["env", "env_file"]
        },
        "additionalProperties": False
    }

    # Check whether stack exists
    if not get_module(stack_name):
        return "Stack does not exist.", HTTPStatus.NOT_FOUND

    # Check whether content-type is json & parse
    if request.content_length and request.content_length > 0:
        payload = request.get_json()
    else:
        payload = {"env": {}}

    # Check request format
    try:
        jsonschema.validate(payload, post_payload_schema)
    except jsonschema.exceptions.ValidationError as e:
        return str(e), HTTPStatus.BAD_REQUEST

    # Create file with environment variables
    env_filepath: Path = current_app.config["ENV_OVERRIDES_DIR"] / f"env-overrides-{stack_name}.env"
    current_app.config["ENV_OVERRIDES_DIR"].mkdir(parents=True, exist_ok=True)
    with open(env_filepath, "w") as envfile:
        if "env" in payload:
            for env_var, env_val in payload.get("env", {}).items():
                envfile.write(f"{env_var}={shlex.quote(env_val)}\n")
        elif "env_file" in payload:
            envfile.write(payload["env_file"])
        else:
            envfile.write("")

    # Call Makefile
    output, returncode = run_cmd(["make", f"run-{stack_name}", "DETACHED=1", f"ENV_OVERRIDES_PATH={env_filepath.as_posix()}", f"ENV_DIR=/tmp"])
    if returncode != 0:
        return output, HTTPStatus.INTERNAL_SERVER_ERROR
    else:
        return Response(output)


@bp.delete('/stack/<string:stack_name>')
def stop_stack(stack_name: str):
    # Check whether stack exists
    if not get_module(stack_name):
        return "Stack does not exist.", HTTPStatus.NOT_FOUND

    # Call Makefile
    output, returncode = run_cmd(["make", f"stop-{stack_name}"])
    if returncode != 0:
        return output, HTTPStatus.INTERNAL_SERVER_ERROR
    else:
        return Response(output)


@bp.get('/stack/<string:stack_name>/env')
def get_stack_env(stack_name: str):
    module_name = get_module(stack_name)

    # Check whether stack exists
    if not module_name:
        return "Stack does not exist.", HTTPStatus.NOT_FOUND

    env_path = current_app.config["MODULES_DIR"] / module_name / "stacks" / stack_name / current_app.config["STACK_ENV_FILENAME"]

    if not env_path.is_file():
        return "Stack has no stack environment.", HTTPStatus.NOT_FOUND

    return Response(env_path.read_text(), content_type="text/x-sh")


@bp.get('/stack/<string:stack_name>/env_overrides')
def get_stack_env_overrides(stack_name: str):
    env_filepath: Path = current_app.config["ENV_OVERRIDES_DIR"] / f"env-overrides-{stack_name}.env"

    # Check whether stack environment file exists and check for path traversal
    if not env_filepath.parent == current_app.config["ENV_OVERRIDES_DIR"] or not env_filepath.is_file():
        return "Stack does not have environment overrides or does not exist.", HTTPStatus.NOT_FOUND

    return Response(env_filepath.read_text(), content_type="text/x-sh")


def replace_relative_path(match, prefix):
    link, rel_path = match.groups(2)
    if rel_path.startswith('http://') or rel_path.startswith('https://') or rel_path.startswith('/'):
        return match.group(0)
    return f'{link}({prefix}/{rel_path})'

@bp.get('/stack/<string:stack_name>/description')
def get_stack_description(stack_name: str):
    module_name = get_module(stack_name)

    # Check whether stack exists
    if not module_name:
        return "Stack does not exist.", HTTPStatus.NOT_FOUND

    stack_dir = current_app.config["MODULES_DIR"] / module_name / "stacks" / stack_name

    readme_files = [f for f in stack_dir.iterdir() if f.is_file() and f.name.lower() == 'readme.md']
    if not readme_files:
        return "Stack has no description.", HTTPStatus.NOT_FOUND

    description = readme_files[0].read_text()
    for regex in [r'(!\[.*?\])\((.*?)\)', r'(\[.*\])\((.*?)\)']:
        description = re.sub(regex, lambda m: replace_relative_path(m, f'/o5gc/etc/{stack_name}'), description)

    return Response(description, content_type="text/markdown")


def import_status_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("status", current_app.config["STATUS_MODULE_PATH"])
    module = importlib.util.module_from_spec(spec)
    sys.modules["status"] = module
    spec.loader.exec_module(module)
    return module


@bp.get('/containers')
def get_containers():
    status_module = import_status_module()

    return {
        "containers": status_module.get_running_containers()
    }


def get_logs(status_module, host_id, container_id, stdout, stderr, timestamps, tail, since, until):
    try:
        return status_module.get_container_logs(host_id, container_id, stdout, stderr, timestamps, tail, since, until)
    except status_module.ContainerNotFoundException:
        abort(HTTPStatus.NOT_FOUND)


def parse_lines(lines, timestamps, stream):
    parsed_lines = []
    for line in lines:
        if len(line) == 0:
            continue
        split = line.split(" ", 1)
        parsed_lines.append({"time": split[0], "log": split[1], "stream": stream})
    return parsed_lines


def get_container_logs_json(host_id, container_id, stdout, stderr, timestamps, tail, since, until):
    if not timestamps:
        return "To get a log in JSON format, timestamps must be set to true.", HTTPStatus.BAD_REQUEST

    status_module = import_status_module()

    stdout_lines = get_logs(status_module, host_id, container_id, True, False,
                            timestamps, tail, since, until).decode("utf8").split('\n') if stdout else []
    stderr_lines = get_logs(status_module, host_id, container_id, False, True,
                            timestamps, tail, since, until).decode("utf8").split('\n') if stderr else []

    log_lines = (parse_lines(stdout_lines, timestamps, "stdout")
                 + parse_lines(stderr_lines, timestamps, "stderr"))

    sorted_log_lines = sorted(log_lines, key=lambda x: x.get("time"))

    return {"log_lines": sorted_log_lines}


def get_container_logs_text(host_id, container_id, stdout, stderr, timestamps, tail, since, until):
    status_module = import_status_module()

    log = get_logs(status_module, host_id, container_id, stdout, stderr, timestamps, tail, since, until)

    return Response(log, content_type="text/plain")


@bp.get('/container/<string:host_id>/<string:container_id>/logs')
def get_container_logs(host_id: str, container_id: str):
    since = request.values.get("since", None)
    until = request.values.get("until", None)

    if since and since.endswith("Z"): since = since[:-1] + "+00:00"
    if until and until.endswith("Z"): until = until[:-1] + "+00:00"

    since = datetime.fromisoformat(since).astimezone(pytz.timezone("UTC")).replace(tzinfo=None) if since else None
    until = datetime.fromisoformat(until).astimezone(pytz.timezone("UTC")).replace(tzinfo=None) if until else None

    stdout = request.values.get("stdout", True, lambda s: s.lower() == "true")
    stderr = request.values.get("stderr", True, lambda s: s.lower() == "true")

    # Set tail to "all" if not set or if it's "all", otherwise convert to integer
    tail = "all" if request.values.get("tail", "all") == "all" else int(request.values.get("tail"))

    # Check if boolean GET parameters are valid bools
    for boolean_value in ["stdout", "stderr", "timestamps"]:
        if request.values.get(boolean_value, "true").lower() not in ("true", "false"):
            abort(HTTPStatus.BAD_REQUEST)

    timestamps = request.values.get("timestamps", True, lambda s: s.lower() == "true")

    mime = request.accept_mimetypes.best_match(["application/json", "text/plain"])
    if mime == "application/json":
        return get_container_logs_json(host_id, container_id, stdout, stderr, timestamps, tail, since, until)
    # Return text version even if no mime type fits instead of status 406
    else:
        return get_container_logs_text(host_id, container_id, stdout, stderr, timestamps, tail, since, until)


@bp.get('/global_env')
def get_env():
    if not current_app.config["GLOBAL_ENV_PATH"].is_file():
        return "Global Env file does not exist.", HTTPStatus.NOT_FOUND

    with open(current_app.config["GLOBAL_ENV_PATH"], "r") as env_file:
        env_content = env_file.read()

    return Response(env_content, content_type="text/x-sh")


@bp.get('/uedb')
def get_uedb():
    if not current_app.config["UE_ENV_PATH"].is_file():
        return "UE DB file does not exist.", HTTPStatus.NOT_FOUND

    uedb = dotenv.dotenv_values(current_app.config["UE_ENV_PATH"])
    return [
        {
            "id": int(key.removeprefix("UE_")),
            "imsi": value.split()[0],
            "key": value.split()[1],
            "opc": value.split()[2],
        }
        for key,value in uedb.items() if re.match(r"UE_[1-9]+\d*", key)
    ]


def run_simcard_container(cmd):
    client = docker.from_env()
    try:
        output = client.containers.run('o5gc/simcard', cmd,
                                       volumes=["/dev/bus/usb:/dev/bus/usb"],
                                       stderr=True, privileged=True, auto_remove=True)
        return cmd + '\n' + output.decode('utf-8')
    except docker.errors.ContainerError as err:
        return str(err)

@bp.get('/pcsc_scan/readers')
def get_pcsc_scan_readers():
    return Response(run_simcard_container("pcsc_scan -r -t1"), content_type="text/plain")

@bp.get('/pcsc_scan/cards')
def get_pcsc_scan_cards():
    return Response(run_simcard_container("pcsc_scan -c -t1"), content_type="text/plain")

@bp.get('/kiopcgen')
def kiopcgen():
    ki = kiopcgenerator.gen_ki()
    op = "00000000000000000000000000000000"
    return {
        "ki": ki,
        "opc": kiopcgenerator.gen_opc(op, ki).decode()
    }

@bp.get('/pysim/prog_types')
def get_pysim_prog_types():
    return run_simcard_container("./pySim-prog.py -t list").split()

@bp.get('/pysim/read')
def get_pysim_read():
    return Response(run_simcard_container("./pySim-read.py -p0"), content_type="text/plain")

@bp.post('/pysim/prog')
def get_pysim_prog():
    payload_schema = {
        "type": "object",
        "properties": {
            "type": {
                "type": "string" },
            "mcc": {
                "type": "string", "minLength": 3, "maxLength": 3 },
            "mnc": {
                "type": "string", "minLength": 2, "maxLength": 3 },
            "imsi": {
                "type": "string", "minLength": 6 },
            "ki": {
                "type": "string", "minLength": 32, "maxLength": 32 },
            "opc": {
                "type": "string", "minLength": 32, "maxLength": 32 },
            "adm": {
                "type": "string" }
        },
        "required": ["type", "mcc", "mnc", "imsi", "ki", "opc", "adm"]
    }

    if not request.content_length or request.content_length == 0:
        return "Payload missing", HTTPStatus.BAD_REQUEST
    payload = request.get_json()
    try:
        jsonschema.validate(payload, payload_schema)
    except jsonschema.exceptions.ValidationError as e:
        return str(e), HTTPStatus.BAD_REQUEST
    return Response(run_simcard_container(
            f"./pySim-prog.py -p 0 --num 0"
            f" --type={payload.get('type')}"
            f" --pin-adm={payload.get('adm')}"
            f" --mcc={payload.get('mcc')}"
            f" --mnc={payload.get('mnc')}"
            f" --imsi={payload.get('imsi')}"
            f" --ki={payload.get('ki')}"
            f" --opc={payload.get('opc')}"),
        content_type="text/plain")
