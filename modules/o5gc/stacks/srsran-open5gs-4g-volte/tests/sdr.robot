*** Settings ***
Documentation   srsRAN 4G LTE with Open5GS EPC and Kamailio IMS, SDR
Test Tags       SDR  srsran  open5gsepc  ims
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=eNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-open5gs-4g-volte
@{CONTAINERS}     mme  hss  sgwc  sgwu  smf  upf  pcrf  enb  volte-dns  mysql  fhoss
...               icscf  pcscf  scscf  smsc  rtpengine
@{FILES_TO_SAVE}  enb:/mnt/srsran/enb.conf


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify eNB Cell Is Configured
    Container Log Should Match Regexp  enb  Setting frequency: DL=[\\d.]+ Mhz, UL=[\\d.]+ MHz

Verify eNB Is Connected To MME
    # The eNB's startup probe of the MME also shows up as an eNB in the MME log,
    # which is removed again at once, so the last eNB count must be 1.
    Container Log Should Match Regexp  mme
    ...    Number of eNBs is now 1(?![\\s\\S]*Number of eNBs is now)

Verify IMS Diameter Links
    Wait Until Keyword Succeeds  30s  3s  Diameter Peer Should Be Open  icscf  hss
    Wait Until Keyword Succeeds  30s  3s  Diameter Peer Should Be Open  scscf  hss
    Wait Until Keyword Succeeds  30s  3s  Diameter Peer Should Be Open  pcscf  pcrf


*** Keywords ***
eNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the eNB has started and tuned the radio.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  enb  ==== eNodeB started ===
    Container Log Should Match Regexp  enb  Setting frequency:

Diameter Peer Should Be Open
    [Documentation]  Assert the Kamailio in ${container} has an open Diameter
    ...    connection to the peer whose FQDN starts with ${peer}.
    [Arguments]  ${container}  ${peer}
    ${result} =  Run Process  docker  exec  ${container}  kamcmd  cdp.list_peers
    Should Be Equal  ${result.rc}  ${0}  ${result.stderr}
    Should Match Regexp  ${result.stdout}  FQDN: ${peer}\\.\\S+\\s+Details: \\{\\s+State: I_Open
