*** Settings ***
Documentation   srsRAN 5G SA with OAI core, SDR
Test Tags       SDR  srsran  oaicn
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=gNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-oaicn5g-5g
@{CONTAINERS}     upf  smf  amf  nrf  udr  udm  ausf  gnb  mysql
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
    # the AMF's gNB table, which it logs periodically
    Wait Until Keyword Succeeds  60s  5s  Container Log Should Match Regexp  ${AMF_CONTAINER}
    ...    \\|\\s+1\\s+\\|\\s+Connected\\s+\\|


*** Keywords ***
gNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the gNB has opened the radio, set up N2
    ...    with the AMF and reported that it started.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  gnb  ==== gNB started ===
