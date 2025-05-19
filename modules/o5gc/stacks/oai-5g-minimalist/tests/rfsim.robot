*** Settings ***
Documentation   OAI 5G SA minimalist rfsim
Force Tags      Emulated
Resource        ../../../tests/common.resource

Suite Setup     Setup Suite
Suite Teardown  Teardown Suite


*** Test Cases ***
Verify Successful Startup
    Containers Should Running  spgwu  smf  amf  nrf  gnb  ue  mysql
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify UE Is Registered At AMF
    Container Log Should Match Regexp  amf  5GMM-REGISTERED\\|\\s+${MCC}${MNC}${UE_SOFT_MSIN}

Verify UE Connectivity
    OAI UE Should Can Ping  12.1.1.1
    OAI UE Should Can Ping  8.8.8.8

Verify PDU Session Establishment At SMF
    OAI SMF Log Should Contain PDU Session Setup

Collect Test Data
    Collect Container Logs
    Collect Container Versions
    Collect Configuration Files


*** Keywords ***
Setup Suite
    Log To Console  Setup Suite: run 'make run-oai-5g-sa-minimalist-rfsim'
    Start Process   make  run-oai-5g-sa-minimalist-rfsim
    Sleep  5s
    Process Should Be Running
    Wait  45s  to complete core network, gNB and UE startup

Teardown Suite
    Log To Console  Teardown Suite
    Terminate All Containers
    Terminate All Processes

Collect Container Logs
    Save Container Logs  spgwu  smf  amf  nrf  gnb  ue

Collect Container Versions
    Set Container Versions Metadata  spgwu  smf  amf  nrf  gnb  ue

Collect Configuration Files
    Save Local Files  gnb.conf  ue.conf
