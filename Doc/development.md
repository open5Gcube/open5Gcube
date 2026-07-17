## Develop Own Stacks
To define a new Stack, create a sub-directory in ``modules/<module>/stacks`` and add a
``docker-compose.yaml`` file. The easiest way is to use an existing Stack as a template.

Declare the profiles the Stack runs by default with a top-level ``x-o5gc-profiles`` key:
```yaml
x-o5gc-profiles: [ gnb, core ]
```
That is all that is needed: the ``run-<stackname>`` and ``stop-<stackname>`` targets are generated
from this key, along with a ``run-<stackname>-<profile>`` target for each profile listed. Use
``make list-stacks`` to show all Stacks and their default profiles.

Only Stacks needing extra environment variables or dynamically chosen profiles have to define their
own targets, which pass the module, the Stack and the profiles to the ``run_stack``/``stop_stack``
macros:
```makefile
run-<stackname>:  ##
    export SOME_VAR=1;                                                        \
    $(call run_stack,<module>,<stackname>,gnb core)
stop-<stackname>:  ##
    $(call stop_stack,<module>,<stackname>,gnb core)
```

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
