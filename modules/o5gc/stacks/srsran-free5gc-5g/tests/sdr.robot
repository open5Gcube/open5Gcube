*** Settings ***
Documentation   srsRAN 5G SA with free5GC core, SDR
Test Tags       SDR  srsran  free5gc
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=gNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-free5gc-5g
@{CONTAINERS}     upf  smf  amf  nrf  ausf  udr  udm  pcf  nssf  gnb
@{FILES_TO_SAVE}  gnb:/o5gc/srsRAN_Project/gnb.yaml  gnb:/o5gc/srsRAN_Project/gnb.overlay.yaml


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
    Container Log Should Match Regexp  ${AMF_CONTAINER}  Send NG-Setup response


*** Keywords ***
gNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the gNB has opened the radio, set up N2
    ...    with the AMF and reported that it started.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  gnb  ==== gNB started ===
