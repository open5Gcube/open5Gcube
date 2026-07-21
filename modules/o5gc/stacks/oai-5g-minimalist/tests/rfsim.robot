*** Settings ***
Documentation   OAI 5G SA minimalist rfsim
Force Tags      Emulated
Resource        ../../../../../tests/common.resource

Suite Setup     Setup Suite
Suite Teardown  Teardown Suite

*** Variables ***
${STACK}  oai-5g-minimalist-rfsim


*** Test Cases ***
Verify Successful Startup
    Containers Should Running  upf  smf  amf  gnb  ue  mysql
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Is Registered At AMF
    ${MCC}=  Get Env  MCC
    ${MNC}=  Get Env  MNC
    ${UE_SOFT_MSIN}=  Get Env  UE_SOFT_MSIN
    Container Log Should Match Regexp  amf  5GMM-REGISTERED\\s+\\|\\s+${MCC}${MNC}${UE_SOFT_MSIN}

Verify UE Connectivity
    OAI UE Should Can Ping  8.8.8.8

Verify PDU Session Establishment At SMF
    OAI SMF Log Should Contain PDU Session Setup

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
    Wait Until Startup Complete  OAI SMF Log Should Contain PDU Session Setup

Teardown Suite
    Log To Console  Teardown Suite: run 'make stop-${STACK}'
    Run Process   make  stop-${STACK}
    No Container Should Running  upf  smf  amf  gnb  ue  mysql
    Terminate All Processes  kill=True

Collect Container Logs
    Save Container Logs  upf  smf  amf  gnb  ue

Collect Container Versions
    Set Container Versions Metadata  upf  smf  amf  gnb  ue

Collect Configuration Files
    Save Local Files  gnb.conf  ue.conf
