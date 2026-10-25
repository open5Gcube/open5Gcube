*** Settings ***
Documentation   UERANSIM 5G SA with Ella Core, Ella IMS and Ella SMSC, radio link
...             simulation: IMS registration and a call between two UEs
Test Tags       Emulated  ueransim  ellacore  ims
Resource        ../../../../../tests/common.resource
Library         Collections
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          ueransim-ellacore
${UE_TYPE}        ueransim
${CORE_TYPE}      ellacore
@{CONTAINERS}     ellacore  ellacore-ims  ellacore-smsc  gnb  ue  ue2
@{FILES_TO_SAVE}  gnb:/o5gc/ueransim/config/gnb.yaml  ue:/o5gc/ueransim/config/ue.yaml
# builds ims_test.go in the Ella IMS source tree of the ellacore-ims image
${IMS_TEST_BUILD}  mkdir -p o5gc && cp /mnt/imstest/*.go o5gc/
...                && go test -tags o5gc -c -o /tmp/ims.test ./o5gc


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

Verify IMS PDU Sessions
    UE Should Have IMS Session
    UE Should Have IMS Session  container=ue2

Verify Diameter Links Of Ella IMS And SMSC
    [Documentation]  ellacore-init sets up Ella IMS and SMSC, and waits for each
    ...    of their Diameter connections to Ella Core to open.
    Wait Until Keyword Succeeds  150s  5s  Container Log Should Match Regexp  ellacore-init
    ...    (?s)Diameter connection to Ella Core is open.*Diameter connection to Ella Core is open

Verify IMS Registration
    IMS Test Should Pass  TestRegister

Verify IMS Call
    IMS Test Should Pass  TestCall


*** Keywords ***
IMS Test Should Pass
    [Documentation]  Run a Go test of imstest/ims_test.go: it is built inside the
    ...    Ella IMS source tree of the ellacore-ims image, as it uses internal
    ...    packages, and enters the network namespaces of the UE containers.
    [Arguments]  ${test}
    @{env} =  IMS Test Environment
    ${result} =  Run Process  docker  run  --rm  --privileged  --pid\=host
    ...    --entrypoint  bash  -v  ${CURDIR}/imstest:/mnt/imstest:ro  @{env}
    ...    o5gc/ellacore-ims  -c  ${IMS_TEST_BUILD} && /tmp/ims.test -test.v -test.run ^${test}$
    ...    stderr=STDOUT  timeout=5min
    Log  ${result.stdout}
    Should Be Equal  ${result.rc}  ${0}  ${test} failed:\n${result.stdout}
    Should Contain  ${result.stdout}  --- PASS: ${test}

IMS Test Environment
    [Documentation]  docker run options with the O5GC_* environment of ims_test.go
    ${pcscf} =  Get Env  PCSCF_EXT_IP_ADDR
    ${ims_pool} =  Get Env  UE_IMS_IP_SUBNET
    ${mnc} =  Get Env  MNC
    ${mnc_length} =  Get Length  ${mnc}
    @{env} =  Create List  -e  O5GC_PCSCF\=${pcscf}:5060  -e  O5GC_IMS_POOL\=${ims_pool}
    ...    -e  O5GC_MNC_LENGTH\=${mnc_length}
    FOR  ${ue}  ${container}  ${suffix}  IN  1  ue  ${EMPTY}  2  ue2  _0
        @{ue_env} =  UE Test Environment  ${ue}  ${container}  ${suffix}
        Append To List  ${env}  @{ue_env}
    END
    RETURN  ${env}

UE Test Environment
    [Documentation]  O5GC_UE<n>_* options of UE ${ue}: the soft UE in ${container},
    ...    with the UE_SOFT_*${suffix} subscriber
    [Arguments]  ${ue}  ${container}  ${suffix}
    ${mcc} =  Get Env  MCC
    ${mnc} =  Get Env  MNC
    ${msin} =  Get Env  UE_SOFT_MSIN${suffix}
    ${key} =  Get Env  UE_SOFT_KEY${suffix}
    ${opc} =  Get Env  UE_SOFT_OPC${suffix}
    ${pid} =  Run Process  docker  inspect  -f  {{.State.Pid}}  ${container}
    @{env} =  Create List  -e  O5GC_UE${ue}_IMSI\=${mcc}${mnc}${msin}
    ...    -e  O5GC_UE${ue}_K\=${key}  -e  O5GC_UE${ue}_OPC\=${opc}
    ...    -e  O5GC_UE${ue}_PID\=${pid.stdout}
    RETURN  ${env}
