from collections import Counter
from datetime import datetime, timezone
from typing import List, Dict
import docker
from docker.errors import APIError, DockerException, NotFound

PROJECT_IMAGE_PREFIX = "o5gc/"

CONTAINER_PS_ARGS = ("-eo user,pid,pri,pcpu,pmem,vsz=VIRT,rss=RES,stat,start_time,time,args"
                     " --sort=-pcpu")


class ContainerNotFoundException(Exception):
    pass


def _is_project_image(image: Dict) -> bool:
    return bool(image.get("RepoTags")) and any(
        tag.startswith(PROJECT_IMAGE_PREFIX) for tag in image["RepoTags"]
    )


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


def get_container_stats() -> Dict:
    """
    Raw resource counters for every running stack container.

    one_shot, because sampling without it blocks ~1.5 s per container. The price is an
    empty precpu_stats, so the CPU percentage is left to the caller.
    """
    client = docker.from_env()
    stats = {}
    # No all=True: a stopped container has no meaningful resource usage.
    for container in client.containers.list(filters={"label": "o5gc.stack"}):
        try:
            s = client.api.stats(container.id, stream=False, one_shot=True)
        except (NotFound, DockerException):
            # Container went away between the listing and the sample.
            continue

        mem = s.get("memory_stats") or {}
        nets = s.get("networks") or {}
        io = (s.get("blkio_stats") or {}).get("io_service_bytes_recursive") or []

        stats[container.id] = {
            # Cumulative - differenced by the caller
            "cpu_total": s["cpu_stats"]["cpu_usage"]["total_usage"],
            "cpu_system": s["cpu_stats"].get("system_cpu_usage"),
            "online_cpus": s["cpu_stats"].get("online_cpus"),
            "net_rx": sum(v["rx_bytes"] for v in nets.values()),
            "net_tx": sum(v["tx_bytes"] for v in nets.values()),
            "blk_read": sum(x["value"] for x in io if x["op"].lower() == "read"),
            "blk_write": sum(x["value"] for x in io if x["op"].lower() == "write"),
            # Absolute - no delta needed. Subtracting the inactive page cache from
            # memory_stats.usage is what makes this agree with "docker stats".
            "mem_usage": mem.get("usage", 0) - (mem.get("stats") or {}).get("inactive_file", 0),
            "mem_limit": mem.get("limit"),
            # Tasks in the pids cgroup, so threads count too - the PIDS column of "docker stats"
            "pids": (s.get("pids_stats") or {}).get("current")
        }

    # The caller divides by the real elapsed interval instead of assuming the poll period.
    return {"stats": stats, "time": datetime.now(timezone.utc).isoformat()}


def get_container_processes(container_id: str) -> Dict:
    """
    The processes of one container, the way "docker top" lists them.

    Deliberately not part of get_container_stats(): the daemon runs ps for every call
    (~25 ms against the ~2 ms of a stats sample), which is affordable for the single
    container a detail view shows but not for a whole stack on every poll.

    It is also the only way to a process count: ps is fed the cgroup's process list, which
    holds the thread group leaders, while the pids counter of get_container_stats() counts
    every thread.
    """
    client = docker.from_env()
    try:
        container = client.containers.get(container_id)
    except NotFound:
        raise ContainerNotFoundException()

    try:
        top = client.api.top(container.id, ps_args=CONTAINER_PS_ARGS)
    except APIError:
        try:
            # Either the container is not running, or the host's ps does not understand
            # the format above - fall back to the daemon's default before giving up.
            top = client.api.top(container.id)
        except APIError:
            return {"titles": [], "processes": []}

    return {"titles": top.get("Titles") or [], "processes": top.get("Processes") or []}


def get_running_stacks() -> List[str]:
    client = docker.from_env()
    containers = client.containers.list(all=True, filters={"label":"o5gc.stack"})
    return sorted({c.labels.get("o5gc.stack") for c in containers})


def get_host_info() -> Dict:
    # Docker info is the only source for the host's totals (core count, RAM) that stays
    # correct when the backend runs inside a container. If the socket is gone, everything
    # derived from it degrades to None instead of failing the whole readout.
    info = {}
    images = None
    try:
        client = docker.from_env()
        info = client.info()

        # Only the project's own images are counted. One entry per unique image ID, so
        # an image tagged both ":latest" and ":<version>" counts once, and dangling
        # images cannot match a reference filter because they carry no repository tag.
        images = len(client.api.images(filters={"reference": "o5gc/*"}))
    except DockerException:
        info = {}

    with open("/proc/loadavg") as f:
        load = [float(x) for x in f.read().split()[:3]]

    # MemAvailable is not namespaced, so it reports the host's value inside a container.
    mem_available = 0
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemAvailable:"):
                mem_available = int(line.split()[1]) * 1024   # kB -> bytes
                break

    # Raw cumulative counters: the CPU percentage is a delta between two samples and is
    # computed by the caller. Sampling it here would either block a worker or return
    # numbers that flicker between the gunicorn workers.
    with open("/proc/stat") as f:
        v = [int(x) for x in f.readline().split()[1:]]
    # v = user nice system idle iowait irq softirq steal ...

    return {
        "docker": {
            "version": info["ServerVersion"],
            "images": images
        } if info else None,
        "os": {
            "name": info.get("OperatingSystem"),
            "kernel": info.get("KernelVersion"),
            "arch": info.get("Architecture")
        },
        "cpu": {
            "count": info.get("NCPU"),
            "loadavg": load,
            "jiffies": {"total": sum(v), "idle": v[3] + v[4]}
        },
        "memory": {
            "total_bytes": info.get("MemTotal"),
            "available_bytes": mem_available
        },
        "time": datetime.now(timezone.utc).isoformat()
    }


def get_host_image_usage() -> Dict:
    """
    Disk occupied by this project's images, with shared layers counted once.

    Summing each image's Size would count the shared base layers once per image deriving
    from it (199 GB against a 72 GB store). Docker exposes no per-layer sizes, so:

        size = layers used by one project image only   (sum of Size - SharedSize)
             + the whole shared pool                   (LayersSize - all unique)

    The second term belongs to this project only while every shared layer is used by one
    of its images, which is checked rather than assumed: otherwise the figure is an upper
    bound and "exact" is False.

    Walks every image's layer chain, hence its own endpoint rather than the status poll.
    """
    client = docker.from_env()
    df = client.df()
    images = df["Images"]

    project = [i for i in images if _is_project_image(i)]

    unique_project = sum(i["Size"] - i["SharedSize"] for i in project)
    unique_all = sum(i["Size"] - i["SharedSize"] for i in images)
    shared_pool = df["LayersSize"] - unique_all

    # Precondition: is every layer with more than one user also used by a project image?
    layer_users = Counter()
    project_layers = set()
    for image in images:
        try:
            layers = set(client.api.inspect_image(image["Id"])["RootFS"]["Layers"])
        except (DockerException, KeyError):
            continue
        layer_users.update(layers)
        if _is_project_image(image):
            project_layers |= layers

    shared_layers = {layer for layer, users in layer_users.items() if users >= 2}

    return {
        "count": len(project),
        "size_bytes": unique_project + shared_pool,
        "exact": shared_layers <= project_layers,
        "store_total_bytes": df["LayersSize"]
    }


def get_container_logs(host: str, container_id: str,
                       stdout: bool, stderr: bool, timestamps: bool, tail: int,
                       since: datetime | None, until: datetime | None) -> str:
    client = docker.from_env()
    try:
        container = client.containers.get(container_id)
    except NotFound:
        raise ContainerNotFoundException()

    return container.logs(stdout=stdout, stderr=stderr, timestamps=timestamps, tail=tail, since=since, until=until)
