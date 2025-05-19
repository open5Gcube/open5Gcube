from datetime import datetime
from typing import List, Dict


class ContainerNotFoundException(Exception):
    pass


def get_running_containers() -> List[Dict]:
    return [
      {
        "host": "node1",
        "container_id": "123abc",
        "container_name": "srsran_enb",
        "status": {"state": "running"}
      }
    ]


def get_container_logs(host: str, container_id: str,
                       stdout: bool, stderr: bool, timestamps: bool, tail: int,
                       since: datetime | None, until: datetime | None) -> bytes:
    result = ""
    if stdout:
        result += (f"{'2023-12-24T18:00:00.123456789Z ' if timestamps else ''}It is christmas! \n"
                   f"{'2023-12-24T18:00:01.123456789Z ' if timestamps else ''}Host {host} \n"
                   f"{'2023-12-24T18:00:02.123456789Z ' if timestamps else ''}Container ID {container_id} \n"
                   f"{'2023-12-24T18:00:03.123456789Z ' if timestamps else ''}Stdout {stdout} \n"
                   f"{'2023-12-24T18:00:04.123456789Z ' if timestamps else ''}Stderr {stderr} \n")
    if stderr:
        result += f"{'2023-12-24T18:00:05.123456789Z ' if timestamps else ''}ERROR\n"

    if stdout:
        result += (f"{'2023-12-24T18:00:06.123456789Z ' if timestamps else ''}Timestamps {timestamps} \n"
                   f"{'2023-12-24T18:00:07.123456789Z ' if timestamps else ''}Tail {tail} \n"
                   f"{'2023-12-24T18:00:08.123456789Z ' if timestamps else ''}Since {since.isoformat() if since else None} \n"
                   f"{'2023-12-24T18:00:10.123456789Z ' if timestamps else ''}Until {until.isoformat() if until else None} \n")

    return result.encode("utf8")
