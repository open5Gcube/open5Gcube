*** Settings ***
Documentation  Common keywords
Library        OperatingSystem
Library        Process
Library        String


*** Keywords ***
Wait
    [Arguments]  ${time}  ${msg}=
    Log To Console  Waiting ${time} ${msg}
    Sleep  ${time}

Get Suite Paths
    ${etc}  ${suite id}  ${_}  ${_} =  Split String From Right  ${SUITE SOURCE}  /  3
    Create Directory  ${OUTPUT_DIR}/${suite id}
    RETURN  ${etc}/${suite id}  ${OUTPUT_DIR}/${suite id}

Terminate All Containers
    Run Process  docker  ps  -aq  |  xargs  docker  kill  shell=True  stderr=STDOUT

Save Files From Container
    [Arguments]  @{files}
    ${_}  ${suite output dir} =  Get Suite Paths
    FOR  ${file}  IN  @{files}
        ${result} =  Run Process  docker  cp  ${file}  ${suite output dir}/
        Should Be Equal  ${result.rc}  ${0}
    END

Save Local Files
    [Arguments]  @{files}
    ${local dir}  ${suite output dir} =  Get Suite Paths
    FOR  ${file}  IN  @{files}
        Copy File  ${local dir}/${file}  ${suite output dir}/
    END

Save Container Logs
    ${_}  ${suite output dir} =  Get Suite Paths
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  logs  ${container}  stdout=${suite output dir}/${container}.log
        Should Be Equal  ${result.rc}  ${0}
    END

No Running Container Should Be
    [Arguments]  ${health_status}
    ${result} =  Run Process  docker  ps  --format  {{.Names}}: {{.Status}}
    ...          --filter  health\=${health_status}  shell=True  stderr=STDOUT
    Should Be Equal  ${result.rc}  ${0}
    Should Be Empty  ${result.stdout}

No Container Should Be Failed
    ${result} =  Run Process  docker  ps  --all  --format  {{.Names}}: {{.Status}}
    ...          --filter  status\=exited  |  grep  -v  Exited (0)  shell=True  stderr=STDOUT
    Should Be Empty  ${result.stdout}

Containers Should Running
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  ps  -q  --filter  status\=running  --filter  name\=${container}
        Should Be Equal  ${result.rc}  ${0}
        Should Not Be Empty  ${result.stdout}
    END

Container Log Should Match Regexp
    [Arguments]  ${container}  ${regex}
    ${result} =  Run Process  docker  logs  ${container}  stdout=${TEMPDIR}/o5gc.test.${container}.log
    Should Be Equal  ${result.rc}  ${0}
    Should Match Regexp  ${result.stdout}  ${regex}
    Remove File  ${TEMPDIR}/o5gc.test.${container}.log

Set Container Versions Metadata
    [Arguments]  @{containers}
    FOR  ${container}  IN  @{containers}
        ${result} =  Run Process  docker  exec  ${container}  cat  /etc/image_version
        Should Be Equal  ${result.rc}  ${0}
        Set Suite Metadata  Docker Container Versions  - ${container}: ${result.stdout}\n  append=True
    END

OAI UE Should Can Ping
    [Arguments]  ${addr}
    ${result} =  Run Process  docker  exec  ue  ping  -I  oaitun_ue1  -c  1  ${addr}
    Should Be Empty  ${result.stderr}
    Should Be Equal  ${result.rc}  ${0}
    Log  ${result.stdout}

OAI SMF Log Should Contain PDU Session Setup
    # see SMF verifySanityCheckDeployment.py
    Container Log Should Match Regexp  smf  Received a SM context create request from AMF
    Container Log Should Match Regexp  smf  PDU Session Create SM Context Request
    Container Log Should Match Regexp  smf  Encode PDU Session Establishment Accept
    Container Log Should Match Regexp  smf  Set PDU Session Status to PDU_SESSION_ESTABLISHMENT_PENDING
    Container Log Should Match Regexp  smf  PDU_SESSION_ESTABLISHMENT_UE_REQUESTED
    Container Log Should Match Regexp  smf  Set PDU Session Status to PDU_SESSION_ACTIVE
