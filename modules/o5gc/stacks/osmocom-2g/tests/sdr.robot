*** Settings ***
Documentation   Osmocom 2G GSM/GPRS network, SDR
Test Tags       SDR  osmocom
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack  ready_kw=BTS Startup Should Be Complete
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          osmocom-2g
@{CONTAINERS}     osmo-trx  osmo-bts  osmo-pcu  osmo-bsc  osmo-msc  osmo-mgw  osmo-hlr
...               osmo-stp  osmo-cbc  osmo-sgsn  osmo-ggsn
@{FILES_TO_SAVE}  osmo-trx:/etc/osmocom/osmo-trx-uhd.cfg  osmo-bts:/etc/osmocom/osmo-bts-trx.cfg
...               osmo-bsc:/etc/osmocom/osmo-bsc.cfg  osmo-msc:/etc/osmocom/osmo-msc.cfg


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify Transceiver Is Started
    Container Log Should Match Regexp  osmo-trx  Transceiver active with \\d+ channel
    Container Log Should Match Regexp  osmo-trx  Starting the transceiver

Verify BTS Is Connected To BSC
    Container Log Should Match Regexp  osmo-bsc  bootstrapping RSL on ARFCN \\d+

Verify BSC Is Connected To MSC
    Container Log Should Match Regexp  osmo-bsc  RESET ACK from MSC
    Container Log Should Match Regexp  osmo-bsc  BSSMAP association is up


*** Keywords ***
BTS Startup Should Be Complete
    [Documentation]  Readiness without a phone: the BTS has powered on the transceiver,
    ...    which then sends clock indications, and the BSC has reached the MSC.
    No Running Container Should Be  starting
    No Running Container Should Be  unhealthy
    Container Log Should Match Regexp  osmo-trx  Sending CLOCK indications
    Container Log Should Match Regexp  osmo-bsc  BSSMAP association is up
