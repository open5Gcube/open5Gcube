from datetime import datetime
from typing import List, Dict
import docker
from docker.errors import NotFound


class ContainerNotFoundException(Exception):
    pass


def get_running_containers() -> List[Dict]:
    client = docker.from_env()
    containers = client.containers.list(all=True, filters={"label":"o5gc.stack"})
    inspects = [client.api.inspect_container(c.id) for c in containers]
    #inspects.sort(key = lambda ci: (ci['State']['ExitCode'] == 0, not ci['State']['Running'], ci['State'].get('Health', {}).get('Status', '') == 'healthy', ci['Name']))
    return [
        {
            "host": "host0",
            "container_id": ci['Id'],
            "container_name": ci['Name'].lstrip("/"),
            "status": ci
        }
        for ci in inspects
    ]


def get_container_logs(host: str, container_id: str,
                       stdout: bool, stderr: bool, timestamps: bool, tail: int,
                       since: datetime | None, until: datetime | None) -> str:
    client = docker.from_env()
    try:
        container = client.containers.get(container_id)
    except NotFound:
        raise ContainerNotFoundException()

    return container.logs(stdout=stdout, stderr=stderr, timestamps=timestamps, tail=tail, since=since, until=until)
