*** Settings ***
Documentation   UERANSIM 5G SA with Open5GS core, radio link simulation
Force Tags      Emulated
Resource        ../../../../../tests/common.resource

Suite Setup     Setup Suite
Suite Teardown  Teardown Suite


*** Variables ***
${STACK}  ueransim-open5gs


*** Test Cases ***
Verify Successful Startup
    Containers Should Running  upf  smf  amf  nrf  ausf  udr  udm  pcf  bsf  nssf  scp  gnb  ue  mongo
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Is Registered At AMF
    ${MCC}=  Get Env  MCC
    ${MNC}=  Get Env  MNC
    ${UE_SOFT_MSIN}=  Get Env  UE_SOFT_MSIN
    Container Log Should Match Regexp  amf  \\[imsi-${MCC}${MNC}${UE_SOFT_MSIN}\\] Registration complete

Verify UE Connectivity
    UERANSIM UE Should Can Ping  8.8.8.8

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
    Wait  120s  to complete core network, gNB and UE startup

Teardown Suite
    Log To Console  Teardown Suite: run 'make stop-${STACK}'
    Run Process   make  stop-${STACK}
    No Container Should Running  upf  smf  amf  nrf  ausf  udr  udm  pcf  bsf  nssf  scp  gnb  ue  mongo
    Terminate All Processes

Collect Container Logs
    Save Container Logs  upf  smf  amf  nrf  ausf  udr  udm  pcf  bsf  nssf  scp  gnb  ue  mongo

Collect Container Versions
    Set Container Versions Metadata  upf  smf  amf  nrf  ausf  udr  udm  pcf  bsf  nssf  scp  gnb  ue

Collect Configuration Files
    Save Files From Container  gnb:/o5gc/ueransim/config/gnb.yaml  ue:/o5gc/ueransim/config/ue.yaml
