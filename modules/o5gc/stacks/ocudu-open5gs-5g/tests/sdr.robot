*** Settings ***
Documentation   OCUDU 5G SA gNB with Open5GS core, SDR
Test Tags       SDR  ocudu  open5gs
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=gNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ocudu-open5gs-5g
@{CONTAINERS}     upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb
@{FILES_TO_SAVE}  gnb:/o5gc/ocudu/gnb.yaml  gnb:/o5gc/ocudu/gnb.overlay.yaml


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify gNB Cell Is Configured
    Container Log Should Match Regexp  gnb  Cell pci=\\d+, bw=\\d+ MHz, .*dl_arfcn=\\d+

Verify gNB Is Connected To AMF
    Container Log Should Match Regexp  gnb  N2: Connection to AMF on [\\d.]+:\\d+ completed
    Container Log Should Match Regexp  ${AMF_CONTAINER}  \\[Added\\] Number of gNBs is now 1


*** Keywords ***
gNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the gNB has opened the radio, set up N2
    ...    with the AMF and reported that it started.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  gnb  ==== gNB started ===
