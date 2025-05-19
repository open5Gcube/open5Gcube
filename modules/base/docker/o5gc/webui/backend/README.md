# Backend for 5G Cube

This REST backend provides an API to control the stacks run by the 5G cube and get status information.

## Usage

To run the backend, use the provided Dockerfile. Make sure to include the necessary files and directories mentioned
below. The configuration for the Flask app should be passed as a python file. Set the environment variable
`FLASK_CONFIG_FILE` to specify the location of this file.

## Structure

All stacks should be defined in a configurable directory called `STACKS_DIR`. Each stack should have its own
subdirectory with the same name as the stack.

### Makefile

A Makefile must be provided at a configurable path `MAKEFILE_PATH` that defines the following targets per stack:

- `run-[stack_name]`
- `stop-[stack_name]`

The Makefile should act as a wrapper for the necessary tools (e.g., Docker, Docker Swarm, or Kubernetes) to start a
stack. The stack subdirectory may contain additional files required for deployment, such as docker-compose files
or Kubernetes manifests. This ensures that the backend remains independent of the chosen orchestration technology.

### Python File

To be able to retrieve information about the current status, a Python file must be provided at a configurable path
`STATUS_MODULE_PATH` that defines the following functions:

#### `get_running_containers() -> List[Dict]`

This function returns a list of all running containers on all hosts.

```json
[
  {
    "host": "node1",
    "container_id": "123abc",
    "container_name": "srsran_enb",
    "status": { ... docker inspect output ... }
  },
  ...
]
```

#### `get_container_logs(host: str, container_id: str, stdout: bool, stderr: bool, timestamps: bool, tail: int | str, since: datetime | None, until: datetime | None) -> string`

This function returns the output of `docker logs` or the corresponding function in the Docker Python SDK.

### Environment

- For further configuration, a file containing global environment variables can be placed at a configurable path `GLOBAL_ENV_PATH`.
- Each stack directory can have a stack-specific file with a configurable name `STACK_ENV_FILENAME` that contains additional environment variables. Variables defined in this file take precedence over global environment variables.
- Environment variables defined in the files mentioned above can be overridden via the API when starting a stack.
- To pass the overridden environment variables from the API to the Makefile, a file named `env-overrides-{stack_name}.env` is created and placed in a configurable directory `ENV_OVERRIDES_DIR`. The path to this file is then passed to the Makefile as a variable called `ENV_OVERRIDES_PATH`. Even if no additional environment variables are passed to the API, an empty file is created. The Makefile is responsible for applying the variables, respecting the precedence. The correct environment can be created by sourcing the three files in sequential order.

## Endpoints

The following endpoints are available  in the API.

### GET /api/stacks

Response:

- **200** *application/json*
```json
{
  "stacks": [
    {"stack_name": "Stack XY"}
  ]
}
```

### POST /api/stack/<stack_name>

Request:
*application/json*
```json
{
  "env": {"VAR1": "val1", "VAR2": "val2", ...}
}
```

or

```json
{
  "env_file": "VAR1=val1\nVAR2=val2\n..."
}
```

Note: The variable names and contents will be escaped. It is not possible to use special shell characters here.

Response:

- **200** (Stack started successfully)
- **400** (Request malformed)
- **404** (Stack name does not exist)
- **415** (Payload in wrong format, not in JSON)
- **500** (Couldn't start for some reason on server)

### DELETE /api/stack/<stack_name>

Response:

- **200** (Stack stopped successfully)
- **404** (Stack name does not exist)
- **404** (Stack is not started)
- **500** (Couldn't be stopped for some reason on server)

### GET /api/stack/<stack_name>/env

Response:

- **200** *text/x-sh*
```shell
ENV1=specific_val1
ENV2=specific_val2
ENV4=new_val4
```

only the contents of the specific environment file, does not respect the global environment

- **404** (Stack has no specific environment file)
- **404** (Stack does not exist)

### GET /api/stack/<stack_name>/env_overrides

Response:

- **200** *text/x-sh*
```shell
ENV1=specific_val1
ENV2=specific_val2
ENV4=new_val4
```

the contents of the current environment overrides file

- **404** (Stack has no environment overrides file)
- **404** (Stack does not exist)

### GET /api/stack/<stack_name>/description

Response:

- **200** *text/markdown*
```
This is a short and concise description of the stack that should appear in the frontend
alongside the stack information.
```
- **404** (Stack has no description)
- **404** (Stack does not exist)

### GET /api/containers

Response:

- **200** *application/json*
```json
{
  "containers": [
    { /* output of docker inspect xyz */ }
  ]
}
```
- **500** (Containers couldn't be loaded for some reason)

### GET /api/container/<host_id>/<container_id>/logs

GET Parameters:

- `stdout`: true/false // optional, default true
- `stderr`: true/false // optional, default true
- `timestamps`: true/false // optional, default true
- `tail`: int | "all" // optional, default "all"
- `since`: "2023-12-24T18:21+00:00" // optional, default null
- `until`: "2023-12-31T23:59+04:00" // optional, default null

API works similar to [logs() in docker-py](https://docker-py.readthedocs.io/en/stable/containers.html#docker.models.containers.Container.logs)
- *stdout*: Whether to include stdout of logs
- *stderr*: Whether to include stderr of logs
- *timestamps*: Whether to include timestamps of log lines
- *tail*: Specified number of lines at the end of log if set, default all lines
- *since*: Start datetime for logs (all if null)
- *until*: End datetime for logs (all if null)

Response (depending on Accept header):

- **200** (Log was found - plain) *text/plain*
```text
2023-06-23T15:17:08.951378353Z [INFO] [LOGGING] Fastpath logging disabled at runtime.
2023-06-23T15:17:09.474664843Z [INFO] [UHD RF] RF UHD Generic instance constructed
2023-06-23T15:17:09.500433868Z [INFO] [B200] Detected Device: B210
2023-06-23T15:17:09.580560811Z [INFO] [B200] Operating over USB 3.
2023-06-23T15:17:09.603418702Z [INFO] [B200] Initialize CODEC control...
2023-06-23T15:17:09.894350599Z [INFO] [B200] Initialize Radio control...
2023-06-23T15:17:09.927447818Z [INFO] [B200] Performing register loopback test... 
2023-06-23T15:17:09.938812494Z [INFO] [B200] Register loopback test passed
2023-06-23T15:17:09.945037282Z [INFO] [B200] Performing register loopback test... 
2023-06-23T15:17:09.956738671Z [INFO] [B200] Register loopback test passed
2023-06-23T15:17:09.988747305Z [INFO] [B200] Asking for clock rate 23.040000 MHz... 
2023-06-23T15:17:10.256843957Z [INFO] [B200] Actually got clock rate 23.040000 MHz.
2023-06-23T15:17:13.596472223Z Supported RF device list: UHD zmq file
2023-06-23T15:17:13.596494955Z Trying to open RF device 'UHD'
2023-06-23T15:17:13.596496645Z Opening USRP channels=1, args: type=b200,master_clock_rate=23.04e6
2023-06-23T15:17:13.596498198Z RF device 'UHD' successfully opened
2023-06-23T15:17:13.596499777Z 
2023-06-23T15:17:13.596501124Z ==== eNodeB started ===
2023-06-23T15:17:13.596502770Z Type <t> to view trace
2023-06-23T15:17:13.597056258Z Setting frequency: DL=2680.0 Mhz, UL=2560.0 MHz for cc_idx=0 nof_prb=50
2023-06-23T15:17:13.599222731Z Closing stdin thread.
```
- **200** (Log was found - line by line, ordered by time) *application/json*
```json
{
  "log_lines": [
    {
      "time": "2023-06-23T15:17:08.951378353Z",
      "log": "[INFO] [LOGGING] Fastpath logging disabled at runtime.", 
      "stream": "stdout"
    },
    ...
  ]
}
```

- **400** (Request malformed)
- **404** (Container not found)
- **500** (Logs couldn't be fetched due to server error)

### GET /api/global_env

Response:

- **200** *text/x-sh*
```shell
ENV1=val1
ENV2=val2
ENV3=val3
...
```

only the contents of the global environment file

- **404** (Global environment file does not exist)
