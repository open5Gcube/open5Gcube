import importlib
import shlex
import re
import docker
import subprocess
import sys
from io import StringIO
from datetime import datetime
from pathlib import Path
from types import ModuleType
from http import HTTPStatus
from requests.exceptions import ReadTimeout, ConnectionError

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
    uedb = []
    idx = 1
    for fn in [current_app.config["UE_ENV_PATH"]] + list(current_app.config["UE_ENV_D_PATH"].glob('*.env')):
        with open(fn, 'r') as f:
            e = ''.join(line for line in f if not line.lstrip().startswith('#'))
            for ue in dotenv.dotenv_values(stream=StringIO(e)).get('UE_DB+', '').splitlines():
                if not ue.strip(): continue
                uedb.append({
                    "id": idx,
                    "imsi": ue.split()[0],
                    "key": ue.split()[1],
                    "opc": ue.split()[2],
                })
                idx += 1
    return uedb

def run_simcard_container(cmd):
    """
    Return Value: (digest: str, timeout: bool, exitcode: int|None, log: str)
    """
    client = docker.from_env()
    try:
        container = client.containers.run('o5gc/simcard', cmd,
                volumes=["/dev/bus/usb:/dev/bus/usb", "o5gc-simcard-scripts:/o5gc-simcard-scripts:ro"],
                stderr=True, privileged=True, detach=True)
        response = None
        timeout = None
        try:
            response = container.wait(timeout=120)
            timeout = False
        except (ReadTimeout, ConnectionError):
            timeout = True
        finally:
            logs = container.logs(stdout=True, stderr=True).decode("utf8", "surrogateescape")
            container.reload()
            container.remove(force=True)
            exitcode = response.get("StatusCode", None) if response else None
            digest = str(cmd) + '\n' + logs + '\n' + (f'Exited with code {response.get("StatusCode", response)}.' if response else f'Forced removal of container after timeout was reached. Last state: {container.status}.')
            return digest, timeout, exitcode, logs

    except docker.errors.ContainerError as err:
        return str(cmd) + '\n' + "ContainerError during execution:\n" + str(err), None, -1, ""

@bp.get('/pcsc_scan/readers')
def get_pcsc_scan_readers():
    digest, _, _, _ = run_simcard_container("pcsc_scan -r -t1")
    return Response(digest, content_type="text/plain")

@bp.get('/pcsc_scan/cards')
def get_pcsc_scan_cards():
    digest, _, _, _ = run_simcard_container("pcsc_scan -c -t1")
    return Response(digest, content_type="text/plain")

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
    _, timeout, exitcode, log = run_simcard_container("./pySim-prog.py -t list")
    if timeout:
        return "SIM Card types could not be loaded since command timed out.", HTTPStatus.GATEWAY_TIMEOUT
    elif exitcode:
        return f"SIM Card types could not be loaded since the command failed with exitcode {exitcode}.", HTTPStatus.INTERNAL_SERVER_ERROR

    return log.split()

@bp.get('/pysim/read')
def get_pysim_read():
    digest, _, _, _ = run_simcard_container("./pySim-read.py -p0")
    return Response(digest, content_type="text/plain")

@bp.post('/pysim/prog')
def get_pysim_prog():
    payload_schema = {
        "type": "object",
        "properties": {
            "type": { "type": "string" },
            "mcc": { "type": "string", "minLength": 3, "maxLength": 3 },
            "mnc": { "type": "string", "minLength": 2, "maxLength": 3 },
            "imsi": { "type": "string", "minLength": 6 },
            "ki": { "type": "string", "minLength": 32, "maxLength": 32 },
            "opc": { "type": "string", "minLength": 32, "maxLength": 32 },
            "adm": {"type": "string" }
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

    digest, _, _, _ = run_simcard_container(
        f"./pySim-prog.py -p 0 --num 0"
        f" --type={payload.get('type')}"
        f" --pin-adm={payload.get('adm')}"
        f" --mcc={payload.get('mcc')}"
        f" --mnc={payload.get('mnc')}"
        f" --imsi={payload.get('imsi')}"
        f" --ki={payload.get('ki')}"
        f" --opc={payload.get('opc')}"
    )

    return Response(digest, content_type="text/plain")


class IsNotRegularFileError(Exception):
    pass


class PathTraversalDetectedError(Exception):
    pass


def read_and_parse_pysim_script(filepath: Path):
    if not filepath.parent == current_app.config["PYSIM_SCRIPTS_PATH"]:
        raise PathTraversalDetectedError()

    if not filepath.is_file():
        raise IsNotRegularFileError()
    # Raises UnicodeDecodeError / PermissionError
    content = filepath.read_text(encoding="utf-8")

    lines = content.splitlines(keepends=True)
    comment_lines = []

    # If first line is a comment, we parse it and include it in the result.
    if lines and lines[0].startswith('#'):
        for line in lines:
            if not line.startswith('#'): break
            comment_lines.append(line[1:].lstrip(" "))

    return {
        "comment": comment_lines,
        "content": content,
        "error": None
    }


@bp.get('/pysim/scripts')
def get_pysim_scripts():
    result = {}
    for scriptfile in current_app.config["PYSIM_SCRIPTS_PATH"].iterdir():
        if not scriptfile.is_file():
            continue
        try:
            result[scriptfile.name] = read_and_parse_pysim_script(scriptfile)
        except UnicodeDecodeError:
            result[scriptfile.name] = {
                "comment": None,
                "content": None,
                "error": "Script contains binary data / invalid unicode characters."
            }
        except PermissionError:
            result[scriptfile.name] = {
                "comment": None,
                "content": None,
                "error": "Script could not be read due to permission error."
            }
        except (FileNotFoundError, IsNotRegularFileError):
            continue

    return result


@bp.get('/pysim/script/<string:script_name>')
def get_pysim_script(script_name: str):
    try:
        return read_and_parse_pysim_script(current_app.config["PYSIM_SCRIPTS_PATH"] / script_name)
    except PathTraversalDetectedError:
        return "Path traversal detected.", HTTPStatus.FORBIDDEN
    except PermissionError:
        return "Permission error.", HTTPStatus.FORBIDDEN
    except (FileNotFoundError, IsNotRegularFileError):
        return "Script doesn't exist (or is not a regular file).", HTTPStatus.NOT_FOUND
    except UnicodeDecodeError:
        return "Script content is binary / has invalid unicode bytes.", HTTPStatus.INTERNAL_SERVER_ERROR


@bp.put('/pysim/script/<string:script_name>')
def upload_pysim_script(script_name: str):
    script_path: Path = current_app.config["PYSIM_SCRIPTS_PATH"] / script_name
    if not script_path.parent == current_app.config["PYSIM_SCRIPTS_PATH"]:
        return "Path traversal detected.", HTTPStatus.FORBIDDEN

    if script_path.exists() and not script_path.is_file():
        return "Script file exists, but is not a regular file.", HTTPStatus.INTERNAL_SERVER_ERROR

    existed_before = script_path.is_file()
    with open(script_path, 'wb') as f:
        for chunk in iter(lambda: request.stream.read(8192), b''):
            f.write(chunk)

    return f"Script {script_name} saved.", HTTPStatus.CREATED if not existed_before else HTTPStatus.OK


@bp.delete('/pysim/script/<string:script_name>')
def delete_pysim_script(script_name: str):
    script_path: Path = current_app.config["PYSIM_SCRIPTS_PATH"] / script_name
    if not script_path.parent == current_app.config["PYSIM_SCRIPTS_PATH"]:
        return "Path traversal detected.", HTTPStatus.FORBIDDEN
    if script_path.is_file():
        try:
            script_path.unlink()
            return "Script deleted.", HTTPStatus.OK
        except PermissionError:
            return "No permission to remove script file.", HTTPStatus.FORBIDDEN
    else:
        return "Script does not exist.", HTTPStatus.NOT_FOUND


@bp.post('/pysim/run_script/<string:script_name>')
def run_pysim_script(script_name: str):
    payload_schema = {
        "type": "object",
        "properties": {
            "adm": {"type": "string"}
        },
        "required": ["adm"]
    }

    if not request.content_length or request.content_length == 0:
        return "Payload missing", HTTPStatus.BAD_REQUEST
    payload = request.get_json()
    try:
        jsonschema.validate(payload, payload_schema)
    except jsonschema.exceptions.ValidationError as e:
        return str(e), HTTPStatus.BAD_REQUEST

    script_path: Path = current_app.config["PYSIM_SCRIPTS_PATH"] / script_name
    if not script_path.parent == current_app.config["PYSIM_SCRIPTS_PATH"]:
        return "Path traversal detected.", HTTPStatus.FORBIDDEN
    if not script_path.is_file():
        return "Script does not exist.", HTTPStatus.NOT_FOUND

    script_path_volume = Path("/o5gc-simcard-scripts") / script_name

    digest, timeout, exitcode, log = run_simcard_container([
        f"./pySim-shell.py", '-p0',
        "-a", payload.get('adm'),
        "--script", script_path_volume.as_posix()
    ])

    return Response(digest, content_type="text/plain")
