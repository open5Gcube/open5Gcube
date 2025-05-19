## Develop Own Stacks
To define a new Stack, create a sub-directory in ``etc`` and add a ``docker-compose.yaml`` file.
The easiest way is to use an existing Stack as a template.

Add Makefile targets to run and stop the Stack like the following:
```makefile
run-<stackname>: .create-running-env  ##
    cd etc/<stackname>;                                                       \
    $(DOCKER_COMPOSE) --profile=gnb --profile=core up ${DOCKER_COMPOSE_DETACH}
stop-<stackname>: .create-running-env  ##
    cd etc/<stackname>;                                                       \
    $(DOCKER_COMPOSE) --profile=gnb --profile=core down
```
Adjust the ``--profile`` parameter as needed by the Stack definition in the ``docker-compose.yaml``
file.

## Use external Core Networks / RANs
The use of ``macvlan`` to interconnect the Docker container across the hosts, makes the integration
of external Cores / RANs very easy. First, an IP address from the ``corenet`` subnet (default
``192.168.70.0/24``) must be configured at the external host. Then, this IP address must be set for
the corresponding component in the [``networks.env``](user_guide.md#networkenv) settings files,
for example for the gNB:
```shell
GNB_IP_ADDR=192.168.70.XXX
```
Last, connect the external host to the *open5Gcube* via the switch and start the desired part
of a Stack, like
```console
make run-oairan-open5gs-5g-core
```
