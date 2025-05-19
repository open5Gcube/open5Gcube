from datetime import datetime
from typing import List, Dict


class ContainerNotFoundException(Exception):
    pass


def get_running_containers() -> List[Dict]:
    raise ConnectionError()


def get_container_logs(host: str, container_id: str,
                       stdout: bool, stderr: bool, timestamps: bool, tail: int | str,
                       since: datetime | None, until: datetime | None) -> str:
    raise ContainerNotFoundException()
