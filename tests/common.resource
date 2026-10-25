*** Settings ***
Documentation  Common keywords
Library  OperatingSystem
Library  Process
Library  String
Library  get_env.py


*** Variables ***
# Tunnel interface each UE implementation brings up. These names are fixed by the
# UE software rather than configurable: see docker/oai/ran-entrypoint.sh and
# docker/srsran/4g/entrypoint.sh. UERANSIM and PacketRusher are absent here because
# their names are not fixed: see Get UE Tunnel Interface.
&{UE_TUN_IFACE}  oai=oaitun_ue1  srsran=tun_srsue

# Container running the UE. Stacks that combine the gNB and UE in a single container
# (PacketRusher) override this in their suite.
${UE_CONTAINER}  ue
# Containers running the AMF and SMF. Stacks that name them differently (the roaming
# stack runs visited-amf and visited-smf) override these in their suite.
${AMF_CONTAINER}  amf
${SMF_CONTAINER}  smf

# Core-specific assertions. The AMF and SMF log formats differ between the cores,
# so each core gets its own keyword and CORE_TYPE picks the pair.
&{CORE_PDU_SESSION_KW}   oai=OAI SMF Log Should Contain PDU Session Setup
...                      open5gs=Open5GS SMF Log Should Contain PDU Session Setup
...                      free5gc=Free5GC SMF Log Should Contain PDU Session Setup
...                      ellacore=Ellacore SMF Log Should Contain PDU Session Setup
...                      srsepc=srsEPC Default Bearer Should Be Established
...                      open5gs-epc=Open5GS SMF Log Should Contain Default Bearer
&{CORE_REGISTRATION_KW}  oai=OAI AMF Log Should Show UE Registered
...                      open5gs=Open5GS AMF Log Should Show UE Registered
...                      free5gc=Free5GC AMF Log Should Show UE Registered
...                      ellacore=Ellacore AMF Log Should Show UE Registered
...                      srsepc=srsEPC Log Should Show UE Attached
...                      open5gs-epc=Open5GS MME Log Should Show UE Attached


*** Keywords ***
Wait Until Startup Complete
    [Documentation]  Poll ${ready_kw} until the stack is ready. By default the last startup
    ...    milestone is the SMF establishing a PDU session, asserted by the keyword
    ...    CORE_TYPE selects. Stacks without a UE of their own pass another keyword.
    ...    ${timeout} is the ceiling; the keyword returns as soon as ${ready_kw} passes.
    [Arguments]  ${ready_kw}=Startup Should Be Complete  ${timeout}=120s  ${interval}=3s
    Log To Console  Waiting up to ${timeout} for stack startup
    Wait Until Keyword Succeeds  ${timeout}  ${interval}  ${ready_kw}

Startup Should Be Complete
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    SMF Log Should Contain PDU Session Setup

Setup Stack
    [Documentation]  Start the stack and wait until it is ready.
    ...    Used as Suite Setup; the suite only supplies ${STACK}, and optionally
    ...    the readiness keyword passed on to Wait Until Startup Complete.
    [Arguments]  ${ready_kw}=Startup Should Be Complete
    Start Stack
    Wait Until Startup Complete  ${ready_kw}

Start Stack
    [Documentation]  Start the stack ${stack} with 'make run-${stack}' in the background
    ...    and assert it is running. Its output, the container logs compose writes, goes
    ...    to run-${stack}.log in the suite's output directory.
    [Arguments]  ${stack}=${STACK}
    Log To Console  Start Stack: run 'make run-${stack}'
    # Into a file, not the default pipe: nothing reads the pipe while the stack runs, so
    # with the container logs compose writes it would fill up and block compose before
    # it started all containers.
    ${suite_output_dir} =  Get Suite Output Dir
    Start Process  make  run-${stack}  stdout=${suite_output_dir}/run-${stack}.log  stderr=STDOUT
    # Give 'make' a moment to fork the compose stack before we assert the process
    # is alive; actual readiness is polled by Wait Until Startup Complete.
    Sleep  5s
    Process Should Be Running

Teardown Stack
    [Documentation]  Collect artifacts then stop the stack. Runs on every exit,
    ...   including a failed Suite Setup, so logs survive a bad startup.
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
    ...    ${ue} names the UE implementation (oai, ueransim, srsran, packetrusher) and
    ...    defaults to the suite's UE_TYPE; ${container} defaults to the suite's UE_CONTAINER.
    [Arguments]  ${ue}=${UE_TYPE}  ${container}=${UE_CONTAINER}
    ${iface} =  Get UE Tunnel Interface  ${ue}  ${container}
    ${result} =  Run Process  docker  exec  ${container}  ping  -I  ${iface}  -c  1  8.8.8.8
    Should Be Empty  ${result.stderr}
    Should Be Equal  ${result.rc}  ${0}
    Log  ${result.stdout}

UE Should Have IMS Session
    [Documentation]  Assert the UERANSIM UE in ${container} brought up its PDU session on the
    ...    ims data network: one of its tunnel interfaces has an IPv4 address of the IMS pool
    ...    UE_IMS_IP_SUBNET. ${container} defaults to the suite's UE_CONTAINER.
    [Arguments]  ${container}=${UE_CONTAINER}
    Get UERANSIM Tunnel Interface  ${container}  ims=${True}

Get UE Tunnel Interface
    [Documentation]  Name of the tunnel interface the UE in ${container} brings up for its
    ...    internet PDU session. Most implementations use a fixed name (UE_TUN_IFACE), but
    ...    PacketRusher names one interface per subscriber, derived from the MSIN, e.g.
    ...    MSIN 0010000001 gives gtp00010000001, and UERANSIM numbers its interfaces in the
    ...    order the PDU sessions come up: see Get UERANSIM Tunnel Interface.
    [Arguments]  ${ue}=${UE_TYPE}  ${container}=${UE_CONTAINER}
    IF  '${ue}' == 'packetrusher'
        ${msin} =  Get Env  UE_SOFT_MSIN
        RETURN  gtp0${msin}
    END
    IF  '${ue}' == 'ueransim'
        ${iface} =  Get UERANSIM Tunnel Interface  ${container}
        RETURN  ${iface}
    END
    RETURN  ${UE_TUN_IFACE}[${ue}]

Get UERANSIM Tunnel Interface
    [Documentation]  Name of the tunnel interface of the UERANSIM UE in ${container} for its
    ...    ims PDU session if ${ims} is true, else for its internet PDU session. UERANSIM names
    ...    the interfaces uesimtun0, uesimtun1, ... in the order the PDU sessions come up, so
    ...    the session is told by the interface's IPv4 address: the ims session has one of
    ...    the IMS pool UE_IMS_IP_SUBNET, the internet session one outside of it.
    [Arguments]  ${container}=${UE_CONTAINER}  ${ims}=${False}
    ${subnet} =  Get Env  UE_IMS_IP_SUBNET
    ${result} =  Run Process  docker  exec  ${container}  ip  -4  -o  addr  show
    Should Be Equal  ${result.rc}  ${0}  ${result.stderr}
    @{ifaces} =  Get Regexp Matches  ${result.stdout}  ^\\d+: (uesimtun\\d+)\\s+inet ([0-9.]+)/
    ...    1  2  flags=MULTILINE
    FOR  ${iface}  IN  @{ifaces}
        ${in_pool} =  Evaluate  ipaddress.ip_address($iface[1]) in ipaddress.ip_network($subnet)
        ...    modules=ipaddress
        IF  ${in_pool} == ${ims}  RETURN  ${iface}[0]
    END
    ${session} =  Set Variable If  ${ims}  ims  internet
    Fail  no ${session} PDU session interface in ${container}, IMS pool ${subnet}:\n${result.stdout}

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
    Container Log Should Match Regexp  ${AMF_CONTAINER}  5GMM-REGISTERED\\s+\\|\\s+${imsi}

Open5GS AMF Log Should Show UE Registered
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  ${AMF_CONTAINER}  \\[imsi-${imsi}\\] Registration complete

OAI SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  ${SMF_CONTAINER}  Received a SM context create request from AMF
    Container Log Should Match Regexp  ${SMF_CONTAINER}  PDU Session Create SM Context Request
    Container Log Should Match Regexp  ${SMF_CONTAINER}  PDU_SESSION_ESTABLISHMENT_ACCEPT, encode starting
    Container Log Should Match Regexp  ${SMF_CONTAINER}
    ...    Set PDU Session Status to PDU Session Status Establishment Pending
    Container Log Should Match Regexp  ${SMF_CONTAINER}  PDU_SESSION_ESTABLISHMENT_UE_REQUESTED
    Container Log Should Match Regexp  ${SMF_CONTAINER}  Set PDU Session Status to PDU Session Status Active

Open5GS SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  ${SMF_CONTAINER}  \\[Added\\] Number of SMF-Sessions is now
    Container Log Should Match Regexp  ${SMF_CONTAINER}  UE SUPI\\[imsi-\\d+\\] DNN\\[.*\\] IPv4\\[\\d

Free5GC AMF Log Should Show UE Registered
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  ${AMF_CONTAINER}  supi:SUPI:imsi-${imsi}.*Handle Registration Complete

Free5GC SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  ${SMF_CONTAINER}  Receive Create SM Context Request
    Container Log Should Match Regexp  ${SMF_CONTAINER}  In HandlePDUSessionEstablishmentRequest
    Container Log Should Match Regexp  ${SMF_CONTAINER}  Sending PFCP Session Establishment Request
    Container Log Should Match Regexp  ${SMF_CONTAINER}  Received PFCP Session Establishment Accepted Response

Ellacore AMF Log Should Show UE Registered
    [Documentation]  Ella Core is an all-in-one core: the AMF and SMF are components of a
    ...    single 'ellacore' container, so this and the SMF keyword both read that
    ...    container's structured (JSON) log rather than separate 'amf'/'smf' containers.
    [Arguments]  ${imsi}
    ${regex} =  Catenate  SEPARATOR=${EMPTY}
    ...    "component":"AMF".*  "msg":"UE registration accepted".*  "supi":"imsi-${imsi}"
    Container Log Should Match Regexp  ellacore  ${regex}

Ellacore SMF Log Should Contain PDU Session Setup
    Container Log Should Match Regexp  ellacore  "component":"SMF".*"msg":"PDU session established".*"result":"accept"

srsEPC Log Should Show UE Attached
    [Documentation]  Assert the UE with the given IMSI progressed through NAS security to a completed attach.
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  epc  Attach request -- IMSI: ${imsi}
    Container Log Should Match Regexp  epc  Security Mode Command Complete -- IMSI: ${imsi}
    Container Log Should Match Regexp  epc  UL NAS: Received Attach Complete

srsEPC Default Bearer Should Be Established
    [Documentation]  Assert the SPGW allocated an address to the UE and the MME activated the bearer.
    Container Log Should Match Regexp  epc  SPGW Allocated IP \\d+\\.\\d+\\.\\d+\\.\\d+ to IMSI \\d+
    Container Log Should Match Regexp  epc  Activated EPS Bearer: Bearer id \\d+

Open5GS MME Log Should Show UE Attached
    [Documentation]  Assert the MME completed the attach for the given IMSI.
    [Arguments]  ${imsi}
    Container Log Should Match Regexp  mme  \\[${imsi}\\] Attach complete

Open5GS SMF Log Should Contain Default Bearer
    Container Log Should Match Regexp  ${SMF_CONTAINER}  \\[Added\\] Number of SMF-Sessions is now
    Container Log Should Match Regexp  ${SMF_CONTAINER}  UE IMSI\\[\\d+\\] APN\\[.*\\] IPv4\\[\\d
