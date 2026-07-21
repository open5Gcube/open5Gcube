*** Settings ***
Documentation   srsRAN 5G SA with Open5GS core, ZMQ RF simulation
Force Tags      Emulated
Resource        ../../../../../tests/common.resource

Suite Setup     Setup Suite
Suite Teardown  Teardown Suite


*** Variables ***
${STACK}  srsran-open5gs-5g-emu


*** Test Cases ***
Verify Successful Startup
    Containers Should Running  upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue  mongo
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Is Registered At AMF
    ${MCC}=  Get Env  MCC
    ${MNC}=  Get Env  MNC
    ${UE_SOFT_MSIN}=  Get Env  UE_SOFT_MSIN
    Container Log Should Match Regexp  amf  \\[imsi-${MCC}${MNC}${UE_SOFT_MSIN}\\] Registration complete

Verify UE Connectivity
    srsRAN UE Should Can Ping  8.8.8.8

Verify PDU Session Establishment At SMF
    Open5GS SMF Log Should Contain PDU Session Setup

Collect Test Data
    Collect Container Logs
    Collect Container Versions
    Collect Configuration Files


*** Keywords ***
Setup Suite
    Log To Console  Setup Suite: run 'make run-${STACK}'
    Start Process   make  run-${STACK}
    Sleep  5s
    Process Should Be Running
    Wait Until Startup Complete  Open5GS SMF Log Should Contain PDU Session Setup

Teardown Suite
    Log To Console  Teardown Suite: run 'make stop-${STACK}'
    Run Process   make  stop-${STACK}
    No Container Should Running  upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue  mongo
    Terminate All Processes  kill=True

Collect Container Logs
    Save Container Logs  upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue  mongo

Collect Container Versions
    Set Container Versions Metadata  upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  gnb  ue

Collect Configuration Files
    Save Local Files  gnb.yaml
