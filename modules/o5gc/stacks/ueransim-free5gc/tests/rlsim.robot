*** Settings ***
Documentation   UERANSIM 5G SA with free5GC core, radio link simulation
Test Tags       Emulated  ueransim  free5gc
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ueransim-free5gc
${UE_TYPE}        ueransim
${CORE_TYPE}      free5gc
@{CONTAINERS}     upf  smf  amf  nrf  ausf  udr  udm  pcf  nssf  gnb  ue
@{FILES_TO_SAVE}  gnb:/o5gc/ueransim/config/gnb.yaml  ue:/o5gc/ueransim/config/ue.yaml


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
