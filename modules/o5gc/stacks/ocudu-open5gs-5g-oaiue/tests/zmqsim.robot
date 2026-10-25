*** Settings ***
Documentation   OCUDU 5G SA gNB with OAI nrUE and Open5GS core, ZMQ RF simulation
Test Tags       Emulated  ocudu  oaiue  open5gs
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ocudu-open5gs-5g-oaiue
${UE_TYPE}        oai
${CORE_TYPE}      open5gs
@{CONTAINERS}     upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue
@{FILES_TO_SAVE}  gnb:/o5gc/ocudu/gnb.yaml  gnb:/o5gc/ocudu/gnb.overlay.yaml
...               ue:/o5gc/openairinterface5g/etc/nr-ue.run.conf


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Is Registered At AMF
    UE Should Be Registered At AMF

Verify UE Connectivity
    UE Should Reach The Internet

Verify PDU Session Establishment At SMF
    SMF Log Should Contain PDU Session Setup
