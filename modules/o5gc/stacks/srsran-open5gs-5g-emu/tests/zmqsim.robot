*** Settings ***
Documentation   srsRAN 5G SA with Open5GS core, ZMQ RF simulation
Test Tags       Emulated  srsran  open5gs
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-open5gs-5g-emu
${UE_TYPE}        srsran
${CORE_TYPE}      open5gs
@{CONTAINERS}     upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue
@{FILES_TO_SAVE}  gnb:/mnt/srsran/gnb.yaml


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
