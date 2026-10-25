*** Settings ***
Documentation   srsRAN 4G LTE with Open5GS EPC, SDR
Test Tags       SDR  srsran  open5gsepc
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=eNB Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          srsran-open5gs-4g
@{CONTAINERS}     mme  hss  sgwc  sgwu  smf  upf  nrf  pcrf  scp  enb
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


*** Keywords ***
eNB Startup Should Be Complete
    [Documentation]  Readiness without a UE: the eNB has started and tuned the radio.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  enb  ==== eNodeB started ===
    Container Log Should Match Regexp  enb  Setting frequency:
