*** Settings ***
Documentation   OAI 5G SA minimalist rfsim
Test Tags       Emulated  oai-ran  oai-cn
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          oai-5g-minimalist-rfsim
${UE_TYPE}        oai
${CORE_TYPE}      oai
@{CONTAINERS}     upf  smf  amf  gnb  ue  mysql
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
