*** Settings ***
Documentation  Common keywords
Library  OperatingSystem
Library  Process
Library  String
Library  get_env.py


*** Variables ***
# Tunnel interface each UE implementation brings up. These names are fixed by the
# UE software rather than configurable: see docker/oai/ran-entrypoint.sh and
# docker/srsran/4g/entrypoint.sh; UERANSIM creates uesimtun0 itself.
&{UE_TUN_IFACE}  oai=oaitun_ue1  ueransim=uesimtun0  srsran=tun_srsue

# Core-specific assertions. The AMF and SMF log formats differ between the cores,
# so each core gets its own keyword and CORE_TYPE picks the pair.
&{CORE_PDU_SESSION_KW}   oai=OAI SMF Log Should Contain PDU Session Setup
...                      open5gs=Open5GS SMF Log Should Contain PDU Session Setup
...                      free5gc=Free5GC SMF Log Should Contain PDU Session Setup
&{CORE_REGISTRATION_KW}  oai=OAI AMF Log Should Show UE Registered
...                      open5gs=Open5GS AMF Log Should Show UE Registered
...                      free5gc=Free5GC AMF Log Should Show UE Registered


*** Keywords ***
Wait Until Startup Complete
    [Documentation]  Poll until the stack is ready. The last startup milestone is the SMF
    ...    establishing a PDU session, asserted by the keyword CORE_TYPE selects.
    ...    ${timeout} is the ceiling; the keyword returns as soon as the core network,
    ...    gNB and UE have completed startup.
    [Arguments]  ${timeout}=120s  ${interval}=3s
    Log To Console  Waiting up to ${timeout} for core network, gNB and UE startup
    Wait Until Keyword Succeeds  ${timeout}  ${interval}  Startup Should Be Complete

Startup Should Be Complete
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    SMF Log Should Contain PDU Session Setup

Setup Stack
    [Documentation]  Start the stack (make run-${STACK}) and wait until it is ready.
    ...    Used as Suite Setup; the suite only supplies ${STACK}.
    Log To Console  Setup Stack: run 'make run-${STACK}'
    Start Process  make  run-${STACK}
    # Give 'make' a moment to fork the compose stack before we assert the process
    # is alive; actual readiness is polled by Wait Until Startup Complete below.
    Sleep  5s
    Process Should Be Running
    Wait Until Startup Complete

Teardown Stack
    [Documentation]  Collect artifacts (best effort) then stop the stack. Runs on
    ...    every exit, including a failed Suite Setup, so logs survive a bad startup.
    Run Keyword And Warn On Failure  Collect Test Data
    Log To Console  Teardown Stack: run 'make stop-${STACK}'
    Run Process  make  stop-${STACK}
    No Container Should Be Running  @{CONTAINERS}
    Terminate All Processes  kill=True

Collect Test Data
    Save Container Logs  @{CONTAINERS}
    Set Container Versions Metadata  @{CONTAINERS}
    Save Files From Container  @{FILES_TO_SAVE}

Get Suite Output Dir
    [Documentation]  Per-suite results directory, created on first use.
    ${_}  ${suite_id}  ${_}  ${_} =  Split String From Right  ${SUITE SOURCE}  /  3
    Create Directory  ${OUTPUT_DIR}/${suite_id}
    RETURN  ${OUTPUT_DIR}/${suite_id}

Save Files From Container
    [Arguments]  @{files}
    ${suite_output_dir} =  Get Suite Output Dir
    FOR  ${file}  IN  @{files}
        ${result} =  Run Process  docker  cp  ${file}  ${suite_output_dir}/
        Should Be Equal  ${result.rc}  ${0}
    END

Save Container Logs
    [Arguments]  @{containers}
    ${suite_output_dir} =  Get Suite Output Dir
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  logs  ${container}
        ...          stdout=${suite_output_dir}/${container}.log  stderr=STDOUT
        Should Be Equal  ${result.rc}  ${0}
    END

No Running Container Should Be
    [Arguments]  ${health_status}
    ${result} =  Run Process  docker  ps  --format  {{.Names}}: {{.Status}}
    ...          --filter  health\=${health_status}  shell=True  stderr=STDOUT
    Should Be Equal  ${result.rc}  ${0}
    Should Be Empty  ${result.stdout}

No Container Should Be Failed
    [Documentation]  Fail if any container exited with a non-zero status. Cleanly
    ...    exited containers (Exited (0)) are allowed. The exit code is the first
    ...    character after "Exited (": 0 is success, anything else is a failure.
    ${result} =  Run Process  docker  ps  --all  --filter  status\=exited
    ...          --format  {{.Names}}: {{.Status}}  stderr=STDOUT
    Should Be Equal  ${result.rc}  ${0}
    ${failed} =  Get Lines Matching Regexp  ${result.stdout}  Exited \\([^0]  partial_match=True
    Should Be Empty  ${failed}  Containers exited with a non-zero status:\n${failed}

No Container Should Be Running
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  ps  -q  --filter  status\=running  --filter  name\=${container}
        Should Be Equal  ${result.rc}  ${0}
        Should Be Empty  ${result.stdout}
    END

Containers Should Be Running
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  ps  -q  --filter  status\=running  --filter  name\=${container}
        Should Be Equal  ${result.rc}  ${0}
        Should Not Be Empty  ${result.stdout}  ${container} not running
    END

Container Log Should Match Regexp
    [Arguments]  ${container}  ${regex}
    ${result} =  Run Process  docker  logs  ${container}
    ...          stdout=${TEMPDIR}/o5gc.test.${container}.log  stderr=STDOUT
    Should Be Equal  ${result.rc}  ${0}
    Should Match Regexp  ${result.stdout}  ${regex}
    Remove File  ${TEMPDIR}/o5gc.test.${container}.log

Set Container Versions Metadata
    [Documentation]  Record each container's /etc/image_version as suite metadata.
    ...    Containers without that file (e.g. the mysql/mongo database image) are
    ...    skipped with a warning rather than failing the whole collection, so the
    ...    caller can pass the full container list.
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  exec  ${container}  cat  /etc/image_version
        IF  ${result.rc}
            Log  Skipping ${container}: no /etc/image_version  level=WARN
            CONTINUE
        END
        Set Suite Metadata  Docker Container Versions  - ${container}: ${result.stdout}\n  append=True
    END

UE Should Reach The Internet
    [Documentation]  Ping 8.8.8.8 from the UE through its tunnel interface.
    ...    ${ue} names the UE implementation (oai, ueransim, srsran) and defaults to the
    ...    suite's UE_TYPE; the interface it brings up is looked up in UE_TUN_IFACE.
    [Arguments]  ${ue}=${UE_TYPE}
    ${result} =  Run Process  docker  exec  ue  ping  -I  ${UE_TUN_IFACE}[${ue}]  -c  1  8.8.8.8
    Should Be Empty  ${result.stderr}
    Should Be Equal  ${result.rc}  ${0}
    Log  ${result.stdout}

UE Should Be Registered At AMF
    [Documentation]  Assert the AMF registered the UE whose IMSI is built from the
    ...    stack's MCC/MNC/MSIN. ${core} names the core network and defaults to the suite's CORE_TYPE.
    [Arguments]  ${core}=${CORE_TYPE}
    ${mcc} =  Get Env  MCC
    ${mnc} =  Get Env  MNC
    ${msin} =  Get Env  UE_SOFT_MSIN
    Run Keyword  ${CORE_REGISTRATION_KW}[${core}]  ${mcc}${mnc}${msin}

SMF Log Should Contain PDU Session Setup
    [Documentation]  Assert the SMF established a PDU session. ${core} names the
    ...              core network (oai, open5gs) and defaults to CORE_TYPE.
    [Arguments]  ${core}=${CORE_TYPE}
    Run Keyword  ${CORE_PDU_SESSION_KW}[${core}]

OAI AMF Log Should Show UE Registered
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  amf  5GMM-REGISTERED\\s+\\|\\s+${imsi}

Open5GS AMF Log Should Show UE Registered
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  amf  \\[imsi-${imsi}\\] Registration complete

OAI SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  smf  Received a SM context create request from AMF
    Container Log Should Match Regexp  smf  PDU Session Create SM Context Request
    Container Log Should Match Regexp  smf  PDU_SESSION_ESTABLISHMENT_ACCEPT, encode starting
    Container Log Should Match Regexp  smf  Set PDU Session Status to PDU Session Status Establishment Pending
    Container Log Should Match Regexp  smf  PDU_SESSION_ESTABLISHMENT_UE_REQUESTED
    Container Log Should Match Regexp  smf  Set PDU Session Status to PDU Session Status Active

Open5GS SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  smf  \\[Added\\] Number of SMF-Sessions is now
    Container Log Should Match Regexp  smf  UE SUPI\\[imsi-\\d+\\] DNN\\[.*\\] IPv4\\[\\d

Free5GC AMF Log Should Show UE Registered
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  amf  supi:SUPI:imsi-${imsi}.*Handle Registration Complete

Free5GC SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  smf  Receive Create SM Context Request
    Container Log Should Match Regexp  smf  In HandlePDUSessionEstablishmentRequest
    Container Log Should Match Regexp  smf  Sending PFCP Session Establishment Request
    Container Log Should Match Regexp  smf  Received PFCP Session Establishment Accepted Response
