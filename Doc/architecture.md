## Networking
The network architecture incorporates three virtual Docker networks:

* ``corenet`` (192.168.70.0/24): Configured as a *[macvlan](https://docs.docker.com/network/drivers/macvlan/)*
  this network is designated for all Core Network and RAN components. The use of 802.1q trunk
  bridge mode allows a flexible distribution of containers across multiple servers.
  The host system is configured with an additional virtual interfaces, facilitating direct
  communication with services within the network.
* ``extnet`` (192.168.10.0/24): Bridged to the WAN, this network facilitates the Core Network
  Gateway (SPGWU) and other services (like DNS) for external connectivity through the host
  interface.
* ``rfnet`` (192.168.40.0/24): This network is dedicated to connecting the USRP X310 SDRs,
  providing an isolated network for their operations.

## Container Orchestration
All services of the [Stacks](stacks.md) are executed always in isolated Docker containers.
This ensures the reproducibility of the Stacks and allows to describe the building and running
environment in code and configuration files.

The structure, parameters and dependencies of the services in a Stack are organised using
[Docker Compose](https://docs.docker.com/compose/). While Docker Compose is a great and simple
to use tool to operate multi-container scenarios on a single host, it doesn't has features to
manage containers across multiple hosts. This is where typically
[Docker Swarm](https://docs.docker.com/engine/swarm/) or [Kubernetes](https://kubernetes.io/)
enter the stage. However, Kubernetes is quite complex and comes with a lot of overhead and
Docker Swarm doesn't support static IP assignment to the containers.

Therefore, the *open5Gcube* uses a unsophisticated script-based approach to run containers
on remote hosts. To make the setup as simple as possible, one server is selected as so called
**Controller Host** (``o5gc1``). On this machine, the project repository is installed. It
runs all Stack services (especially the core network) except the RAN software. This is delegated
to the **RAN Hosts** (``o5gc2`` & ``o5gc3``) by a helper script (``scripts/docker-remote.sh``).

When a Stack is started on the Controller host, the eNB / gNB container are started as well.
Their entrypoint scripts call the ``docker-remote.sh`` script, which uses
*Docker-outside-of-Docker (DooD)* to

* detect that the current host is not the configured eNB / gNB host in
  [``etc/local.env``](user_guide.md#localenv)
* disconnect the container from all Docker networks
* connects it to the default Docker bridge
* configures the ssh usage
* copy the files to run the container to the remote host
* execute the docker-compose client [connecting to the remote daemon via SSH](https://docs.docker.com/engine/reference/commandline/cli/#a-namehosta-specify-daemon-host--h---host)
  to run the eNB / gNB

With this approach, all containers are managed on the Controller host using standard Docker
Compose features.

The [Docker image build procedure](user_guide.md#build-docker-images), implemented by a central
``Makefile``, takes care of building the images on the RAN hosts as well.

## Docker Images
To streamline the Docker image building process for the project, a specialized
``o5gc-build-cacher`` image has been created. This image plays a crucial role in supporting
the building of the actual images by incorporating the following features:

* ``ccache``: This component caches compiled source files, optimizing the build process.
* ``apt-cacher-ng``: It caches Ubuntu Apt packages, reducing the need for redundant downloads
  during image building.
* ``git-cache-http-server``: This element caches git repositories, enhancing efficiency by
  avoiding repeated fetches.
``Downloads``: Large downloaded files are cached to accelerate subsequent builds.

All Docker images specific follow a standardized naming convention within the ``o5gc/``
namespace. Examples include images like ``o5gc/oai-amf`` for example. These images are versioned
to reflect the project version, such as ``o5gc/oai-amf:1.4.0``. The ``latest`` tag is assigned
to the most recently built version, creating a convenient reference, like ``o5gc/oai-amf:latest``
pointing to ``o5gc/oai-amf:1.4.0``.

While the images are not optimized for size, they closely follow to the structure of the official
images associated with their respective projects as far as sensible. Almost all images are built
on a common base image ``o5gc-base``. This approach ensures consistency and incorporates
essential configurations to leverage the build-cacher. Moreover, the ``o5gc-base`` image
provides a user-friendly environment within a running container, enabling convenient console
interactions. It includes the following features:

* Bash as Default Shell: The default shell within the container is set to Bash, providing a
  familiar and versatile command-line interface.
* Preinstalled Packages: The image comes with a lot of preinstalled packages, simplifying the
  installation of the various projects.
* Current Wireshark Version: Wireshark is included in the image with the latest version.
* SSH Key for Inter-Container Login: An SSH key is configured, facilitating login between
  containers.
* Common Working Directory: The working directory within the container is set to
 ``/o5gc/``, offering a designated space for project-specific installations and operations.
