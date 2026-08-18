*** Settings ***
Documentation   OAI-RAN 5G SA with Open5GS core, RF simulation
Test Tags       Emulated  oai-ran  open5gs
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          oairan-open5gs-5g-rfsim
${UE_TYPE}        oai
${CORE_TYPE}      open5gs
@{CONTAINERS}     upf  smf  amf  nrf  ausf  udr  udm  pcf  bsf  nssf  scp  sgwc  sgwu  pcrf  gnb  ue
@{FILES_TO_SAVE}  gnb:/o5gc/openairinterface5g/etc/gnb.conf  ue:/o5gc/openairinterface5g/etc/nr-ue.conf


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
