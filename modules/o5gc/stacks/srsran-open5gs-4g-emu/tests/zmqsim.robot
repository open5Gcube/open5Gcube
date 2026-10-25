*** Settings ***
Documentation   srsRAN 4G LTE with Open5GS EPC, ZMQ RF simulation
Test Tags       Emulated  srsran  open5gsepc
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-open5gs-4g-emu
${UE_TYPE}        srsran
${CORE_TYPE}      open5gs-epc
@{CONTAINERS}     mme  hss  sgwc  sgwu  smf  upf  pcrf  enb  ue
@{FILES_TO_SAVE}  enb:/mnt/srsran/enb.conf


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Attaches To EPC
    UE Should Be Registered At AMF

Verify UE Connectivity
    UE Should Reach The Internet

Verify Default Bearer Establishment
    SMF Log Should Contain PDU Session Setup
