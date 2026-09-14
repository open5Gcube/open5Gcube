from typing import Dict

import docker


class ContainerNotFoundException(Exception):
    pass


def get_host_info() -> Dict:
    """Host info as it looks when the Docker socket is unavailable."""
    return {
        "docker": None,
        "os": {
            "name": None,
            "kernel": None,
            "arch": None
        },
        "cpu": {
            "count": None,
            "loadavg": [1.11, 0.73, 0.36],
            "jiffies": {"total": 16768523, "idle": 16254984}
        },
        "memory": {
            "total_bytes": None,
            "available_bytes": 21750579200
        },
        "time": "2026-09-09T17:30:00+00:00"
    }


def get_container_stats() -> Dict:
    """Stats need the Docker socket; the endpoint degrades to an empty set."""
    raise docker.errors.DockerException("socket unavailable")


def get_host_image_usage() -> Dict:
    """Sizing needs the Docker socket, so it fails outright rather than degrading."""
    raise docker.errors.DockerException("socket unavailable")


def get_container_processes(container_id: str) -> Dict:
    """The process list comes from the daemon, so it fails outright rather than degrading."""
    raise docker.errors.DockerException("socket unavailable")
