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


def get_container_stats() -> Dict:
    return {
        "stats": {
            "123abc": {
                "cpu_total": 17376857000,
                "cpu_system": 541012150000000,
                "online_cpus": 16,
                "net_rx": 12345,
                "net_tx": 67890,
                "blk_read": 2580480,
                "blk_write": 16384,
                "mem_usage": 36663296,
                "mem_limit": 33240776704,
                "pids": 3
            }
        },
        "time": "2026-09-09T17:30:00+00:00"
    }


def get_container_processes(container_id: str) -> Dict:
    return {
        "titles": ["USER", "PID", "PRI", "%CPU", "%MEM", "VIRT", "RES", "STAT", "START", "TIME", "COMMAND"],
        "processes": [
            ["root", "10535", "19", "0.1", "0.0", "758176", "10384", "Ssl", "09:46", "00:00:11",
             "./build/nr-gnb -c config/gnb.yaml"],
            ["root", "10451", "19", "0.0", "0.0", "2800", "1664", "Ss", "09:46", "00:00:00",
             "/bin/sh entrypoint.sh"]
        ]
    }


def get_host_info() -> Dict:
    return {
        "docker": {
            "version": "28.5.2",
            "images": 111
        },
        "os": {
            "name": "Ubuntu 24.04.4 LTS",
            "kernel": "7.0.0-30-generic",
            "arch": "x86_64"
        },
        "cpu": {
            "count": 16,
            "loadavg": [1.11, 0.73, 0.36],
            "jiffies": {"total": 16768523, "idle": 16254984}
        },
        "memory": {
            "total_bytes": 33240797184,
            "available_bytes": 21750579200
        },
        "time": "2026-09-09T17:30:00+00:00"
    }


def get_host_image_usage() -> Dict:
    return {
        "count": 111,
        "size_bytes": 48619000000,
        "exact": True,
        "store_total_bytes": 77374000000
    }


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
