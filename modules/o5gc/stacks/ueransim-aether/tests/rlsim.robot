*** Settings ***
Documentation   UERANSIM 5G SA with Aether SD-Core and BESS UPF, radio link simulation
Test Tags       Emulated  ueransim  aether
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ueransim-aether
${UE_TYPE}        ueransim
${CORE_TYPE}      aether
@{CONTAINERS}     mongo  aether-webui  nrf  amf  ausf  udm  udr  pcf  nssf  smf  upf  gnb  ue
@{FILES_TO_SAVE}  gnb:/o5gc/ueransim/config/gnb.yaml  ue:/o5gc/ueransim/config/ue.yaml
...               amf:/amfcfg.yaml  smf:/smfcfg.yaml  upf:/upf.jsonc


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
