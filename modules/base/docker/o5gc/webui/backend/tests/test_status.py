import docker
import pytest

from src import status


def test_get_host_info_degrades_without_docker(monkeypatch):
    def raise_docker_exception():
        raise docker.errors.DockerException("Error while fetching server API version")

    monkeypatch.setattr(docker, "from_env", raise_docker_exception)

    host_info = status.get_host_info()

    # Everything that comes from the Docker socket is unknown ...
    assert host_info["docker"] is None
    assert host_info["os"] == {"name": None, "kernel": None, "arch": None}
    assert host_info["cpu"]["count"] is None
    assert host_info["memory"]["total_bytes"] is None

    # ... but everything read from /proc is still there
    assert len(host_info["cpu"]["loadavg"]) == 3
    assert all(isinstance(load, float) for load in host_info["cpu"]["loadavg"])
    assert host_info["cpu"]["jiffies"]["total"] > host_info["cpu"]["jiffies"]["idle"] > 0
    assert host_info["memory"]["available_bytes"] > 0
    assert host_info["time"].endswith("+00:00")
