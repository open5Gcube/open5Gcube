*** Settings ***
Documentation   OCUDU 5G SA split gNB (DU, CU-CP, CU-UP) with Open5GS core, SDR
Test Tags       SDR  ocudu  open5gs
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=gNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ocudu-split-open5gs-5g
@{CONTAINERS}     upf  smf  amf  nrf  udr  udm  ausf  pcf  bsf  nssf  scp  du  cu-cp  cu-up
@{FILES_TO_SAVE}  du:/o5gc/ocudu/du.yaml  du:/o5gc/ocudu/du.overlay.yaml
...               cu-cp:/o5gc/ocudu/cu_cp.yaml  cu-cp:/o5gc/ocudu/cu_cp.overlay.yaml
...               cu-up:/o5gc/ocudu/cu_up.yaml  cu-up:/o5gc/ocudu/cu_up.overlay.yaml


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify DU Cell Is Configured
    Container Log Should Match Regexp  du  Cell pci=\\d+, bw=\\d+ MHz, .*dl_arfcn=\\d+

Verify CU-CP Is Connected To AMF
    Container Log Should Match Regexp  cu-cp  N2: Connection to AMF on [\\d.]+:\\d+ completed
    Container Log Should Match Regexp  ${AMF_CONTAINER}  \\[Added\\] Number of gNBs is now 1

Verify DU Is Connected To CU-CP
    Container Log Should Match Regexp  du  F1 Setup: Procedure completed successfully

Verify CU-UP Is Connected To CU-CP
    Container Log Should Match Regexp  cu-up  "E1AP CU-UP Setup Procedure" finalized


*** Keywords ***
gNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the DU has opened the radio and completed
    ...    F1 setup, and the CU-UP has completed E1 setup with the CU-CP.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  du  DU started successfully
    Container Log Should Match Regexp  cu-up  ==== CU-UP started ===
