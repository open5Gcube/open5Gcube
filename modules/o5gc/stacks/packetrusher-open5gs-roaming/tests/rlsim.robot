*** Settings ***
Documentation   PacketRusher 5G SA roaming between two Open5GS cores, radio link simulation
...
...             The UE of the home network attaches to the gNB of the visited network;
...             the two cores are connected over N32 by their SEPPs, the PDU session
...             breaks out locally at the visited UPF.
Test Tags       Emulated  packetrusher  open5gs  roaming
Resource        ../../../../../tests/common.resource
Suite Setup     Setup Stack
Suite Teardown  Teardown Stack


*** Variables ***
${STACK}          packetrusher-open5gs-roaming
${UE_TYPE}        packetrusher
${CORE_TYPE}      open5gs
# PacketRusher runs the gNB and the UE in a single container
${UE_CONTAINER}   gnb-ue
# The UE registers at the visited network, which also establishes its PDU session
${AMF_CONTAINER}  visited-amf
${SMF_CONTAINER}  visited-smf
@{CONTAINERS}     home-upf  home-smf  home-amf  home-nrf  home-ausf  home-udr  home-udm
...               home-pcf  home-bsf  home-nssf  home-scp  home-pcrf  home-sepp
...               visited-upf  visited-smf  visited-amf  visited-nrf  visited-ausf  visited-udr
...               visited-udm  visited-pcf  visited-bsf  visited-nssf  visited-scp  visited-pcrf
...               visited-sepp  gnb-ue
@{FILES_TO_SAVE}  gnb-ue:/o5gc/PacketRusher/config/config.yml


*** Test Cases ***
Verify Successful Startup
    Containers Should Be Running  @{CONTAINERS}
    No Running Container Should Be  unhealthy
    No Running Container Should Be  starting
    No Container Should Be Failed

Verify N32 Connection Between The SEPPs
    ${home_sepp} =  SEPP FQDN Regexp  HOME
    ${visited_sepp} =  SEPP FQDN Regexp  VISITED
    Container Log Should Match Regexp  home-sepp  \\[${visited_sepp}\\] SEPP established
    Container Log Should Match Regexp  visited-sepp  \\[${home_sepp}\\] SEPP established

Verify Visited AMF Uses Home AUSF And UDM
    ${mcc} =  Get Env  HOME_MCC
    ${mnc03} =  Get Env  HOME_MNC03
    FOR  ${nf}  IN  ausf  udm
        Container Log Should Match Regexp  ${AMF_CONTAINER}
        ...    Setup NF EndPoint\\(fqdn\\) \\[${nf}\\.5gc\\.mnc${mnc03}\\.mcc${mcc}\\.3gppnetwork\\.org
    END

Verify Roaming UE Is Registered At Visited AMF
    ${mcc} =  Get Env  HOME_MCC
    ${mnc} =  Get Env  HOME_MNC
    ${msin} =  Get Env  UE_SOFT_MSIN
    Open5GS AMF Log Should Show UE Registered  ${mcc}${mnc}${msin}

Verify UE Connectivity
    UE Should Reach The Internet

Verify PDU Session Establishment At Visited SMF
    SMF Log Should Contain PDU Session Setup


*** Keywords ***
SEPP FQDN Regexp
    [Documentation]  Regexp of the FQDN of the SEPP of the HOME or VISITED network.
    [Arguments]  ${network}
    ${mcc} =  Get Env  ${network}_MCC
    ${mnc03} =  Get Env  ${network}_MNC03
    RETURN  sepp\\.5gc\\.mnc${mnc03}\\.mcc${mcc}\\.3gppnetwork\\.org
