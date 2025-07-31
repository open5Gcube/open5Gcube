docker-build-srsran: docker-build-srsran-4g docker-build-srsran-project
docker-build-srsran-4g docker-build-srsran-project: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p srsran/$(word 4,$(subst -, ,$@)) --target proxy
	$(call docker-build-remotely,${DOCKER_RAN_HOSTS})
docker-build-srsran-4g-at-% docker-build-srsran-project-at-%:
	${DOCKER_BUILD} -m o5gc -p srsran/$(word 4,$(subst -, ,$@)) --host $*
	
OPEN5GS_VERSIONS = $(filter-out latest,$(call image_versions,open5gs))
docker-build-open5gs: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p open5gs --version-arg OPEN5GS_VERSION $(foreach ver,${OPEN5GS_VERSIONS}, --version ${ver})

OAI_RAN_VERSIONS = $(call image_versions,oai-ran)
docker-build-oai-ran: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p oai -i ran -a VERSION="%version%"              \
	    --target proxy $(foreach ver,${OAI_RAN_VERSIONS}, --version ${ver})
	$(call docker-build-remotely,${DOCKER_RAN_HOSTS})
docker-build-oai-ran-at-%:
	${DOCKER_BUILD} -m o5gc -p oai -i ran -a VERSION="%version%"              \
	    --host $* $(foreach ver,${OAI_RAN_VERSIONS}, --version ${ver})

OAI_CORE_IMAGES = amf ausf lmf nrf smf udm udr upf
docker-build-oai-core:
	$(MAKE) ${PARALLEL_JOBS} RUN_PARALLEL=1 $(foreach img,${OAI_CORE_IMAGES},docker-build-oai-${img})

OAI_CN5G_VERSIONS = $(sort $(foreach img,${OAI_CORE_IMAGES},$(filter-out latest,$(call image_versions,oai-${img}))))
docker-build-oai-cn5g-base: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p oai -i cn5g-base -a OAI_CN5G_VERSION="%version%" $(foreach ver,${OAI_CN5G_VERSIONS}, --version ${ver})
	${DOCKER_BUILD} -m o5gc -p oai -i cn5g-base

docker-build-oai-amf docker-build-oai-ausf docker-build-oai-lmf               \
docker-build-oai-nrf docker-build-oai-smf docker-build-oai-udm                \
docker-build-oai-udr docker-build-oai-upf: docker-build-oai-cn5g-base
	${DOCKER_BUILD} -m o5gc -p oai -i $@ -a OAI_CN5G_VERSION="%version%" $(foreach ver,${OAI_CN5G_VERSIONS}, --version ${ver})

OSMOCOM_IMAGES = base hlr mgw stp msc bts trx bsc ggsn sgsn pcu cbc
docker-build-osmocom: $(foreach img,${OSMOCOM_IMAGES},docker-build-osmocom-${img})
	docker images o5gc/osmocom-* | (read h; echo "$$h"; LC_ALL=C sort)
docker-build-osmocom-base: docker-build-o5gc-base
	$(call docker-build-remotely,localhost ${DOCKER_RAN_HOSTS})
docker-build-osmocom-msc docker-build-osmocom-bsc: docker-build-osmocom-hlr docker-build-osmocom-mgw docker-build-osmocom-stp
docker-build-osmocom-sgsn: docker-build-osmocom-hlr docker-build-osmocom-ggsn
docker-build-osmocom-%: docker-build-osmocom-base
	${DOCKER_BUILD} -m o5gc -p osmocom -i $*
docker-build-osmocom-trx: docker-build-osmocom-base
	${DOCKER_BUILD} -m o5gc -p osmocom -i trx --target proxy
	$(call docker-build-remotely,${DOCKER_RAN_HOSTS})
docker-build-osmocom-base-at-% docker-build-osmocom-trx-at-%:
	${DOCKER_BUILD} -m o5gc -p osmocom -i $(word 4,$(subst -, ,$@)) --host $*

docker-build-volte: docker-build-volte-kamailio docker-build-volte-fhoss      \
                    docker-build-volte-dns docker-build-volte-rtpengine
	docker image ls o5gc/volte-*
docker-build-volte-%: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p volte/$*

docker-build-ueransim docker-build-simcard docker-build-packetrusher          \
docker-build-mysql docker-build-free5gc: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p $@

docker-build-misc-falcon docker-build-misc-sigdigger                          \
docker-build-misc-gr-osmosdr docker-build-misc-ltesniffer                     \
docker-build-misc-swagger: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p misc -i $@

run-oai-5g-basic: .create-running-env  ##
	export OAI_CN5G_TYPE=basic;                                               \
	$(call run_stack,o5gc,oai-5g-basic,gnb core)
stop-oai-5g-basic:  ##
	export OAI_CN5G_TYPE=basic;                                               \
	$(call stop_stack,o5gc,oai-5g-basic,gnb core)
run-oai-5g-basic-gnb run-oai-5g-basic-core run-oai-5g-basic-ue: .create-running-env
	export OAI_CN5G_TYPE=basic;                                               \
	$(call run_stack,o5gc,oai-5g-basic,$(subst run-oai-5g-basic-,,$@))
run-oai-5g-basic-rfsim: .create-running-env
	export OAI_RFSIM_ENABLE=1; export OAI_CN5G_TYPE=basic;                    \
	$(call run_stack,o5gc,oai-5g-basic,gnb core ue)

run-oai-5g-minimalist: .create-running-env  ##
	export OAI_CN5G_TYPE=minimalist;                                          \
	$(call run_stack,o5gc,oai-5g-minimalist,gnb core)
stop-oai-5g-minimalist:  ##
	export OAI_CN5G_TYPE=minimalist;                                          \
	$(call stop_stack,o5gc,oai-5g-minimalist,gnb core)
run-oai-5g-minimalist-gnb run-oai-5g-minimalist-core run-oai-5g-minimalist-ue: .create-running-env
	export OAI_CN5G_TYPE=minimalist;                                          \
	$(call run_stack,o5gc,oai-5g-minimalist,$(subst run-oai-5g-minimalist-,,$@))
run-oai-5g-minimalist-rfsim: .create-running-env
	export OAI_RFSIM_ENABLE=1; OAI_CN5G_TYPE=minimalist;                      \
	$(call run_stack,o5gc,oai-5g-minimalist,gnb core ue)

run-oairan-open5gs-5g: .create-running-env  ##
	$(call run_stack,o5gc,oairan-open5gs-5g,core gnb)
stop-oairan-open5gs-5g:  ##
	$(call stop_stack,o5gc,oairan-open5gs-5g,core gnb)
run-oairan-open5gs-5g-gnb run-oairan-open5gs-5g-core: .create-running-env
	$(call run_stack,o5gc,oairan-open5gs-5g,$(subst run-oairan-open5gs-5g-,,$@))

run-oairan-free5gc-5g: .create-running-env  ##
	$(call run_stack,o5gc,oairan-free5gc-5g,core gnb)
stop-oairan-free5gc-5g:  ##
	$(call stop_stack,o5gc,oairan-free5gc-5g,core gnb)
run-oairan-free5gc-5g-gnb run-oairan-free5gc-5g-core: .create-running-env
	$(call run_stack,o5gc,oairan-free5gc-5g,$(subst run-oairan-free5gc-5g-,,$@))

run-osmocom-2g: .create-running-env  ##
	$(call run_stack,o5gc,osmocom-2g,osmocom)
stop-osmocom-2g:  ##
	$(call stop_stack,o5gc,osmocom-2g,osmocom)

run-srsran-4g-emu: .create-running-env
	$(call run_stack,o5gc,srsran-4g-emu,enb core ue)
stop-srsran-4g-emu: .create-running-env
	$(call stop_stack,o5gc,srsran-4g-emu,enb core ue)

run-srsran-open5gs-4g: .create-running-env  ##
	$(call run_stack,o5gc,srsran-open5gs-4g,enb core)
stop-srsran-open5gs-4g: .create-running-env  ##
	$(call stop_stack,o5gc,srsran-open5gs-4g,enb core)
run-srsran-open5gs-4g-enb run-srsran-open5gs-4g-core: .create-running-env
	$(call run_stack,o5gc,srsran-open5gs-4g,$(subst run-srsran-open5gs-4g-,,$@))

run-srsran-open5gs-4g-volte: ${ENV_DIR}/srsran-open5gs-4g-volte.env .create-running-env  ##
	$(call run_stack,o5gc,srsran-open5gs-4g-volte,enb core volte                   \
	    $(if $(subst SMS-over-SGs,,$(call get_env,SMS_DOMAIN,$<)),smsc,osmocom))
stop-srsran-open5gs-4g-volte: .create-running-env  ##
	$(call stop_stack,o5gc,srsran-open5gs-4g-volte,enb core volte)
run-srsran-open5gs-4g-volte-core: ${ENV_DIR}/srsran-open5gs-4g-volte.env .create-running-env
	$(call run_stack,o5gc,srsran-open5gs-4g-volte,core volte                       \
	    $(if $(subst SMS-over-SGs,,$(call get_env,SMS_DOMAIN,$<)),smsc,osmocom))
run-srsran-open5gs-4g-volte-enb: .create-running-env
	$(call run_stack,o5gc,srsran-open5gs-4g-volte,enb)

run-srsran-open5gs-5g: .create-running-env  ##
	$(call run_stack,o5gc,srsran-open5gs-5g,gnb core)
stop-srsran-open5gs-5g: .create-running-env  ##
	$(call stop_stack,o5gc,srsran-open5gs-5g,gnb core)
run-srsran-open5gs-5g-gnb run-srsran-open5gs-5g-core: .create-running-env
	$(call run_stack,o5gc,srsran-open5gs-5g,$(subst run-srsran-open5gs-5g-,,$@))

run-ueransim-open5gs run-ueransim-free5gc run-ueransim-oai: .create-running-env  ##
	export OAI_CN5G_TYPE=basic;                                               \
	$(call run_stack,o5gc,$(subst run-,,$@),core gnb ue metrics)
stop-ueransim-open5gs stop-ueransim-free5gc stop-ueransim-oai:  ##
	$(call stop_stack,o5gc,$(subst stop-,,$@),core gnb ue metrics)

run-packetrusher-open5gs run-packetrusher-open5gs-roaming: .create-running-env  ##
	$(call run_stack,o5gc,$(subst run-,,$@),core gnb-ue metrics)
stop-packetrusher-open5gs stop-packetrusher-open5gs-roaming:  ##
	$(call stop_stack,o5gc,$(subst stop-,,$@),core gnb-ue metrics)

run-ltesniffer: .create-running-env  ##
	$(call run_stack,o5gc,ltesniffer,ltesniffer)
stop-ltesniffer:  ##
	$(call stop_stack,o5gc,ltesniffer,ltesniffer)

run-oai-spgwu-iperf:
	docker exec spgwu iperf3 -s

run-oai-ran-tracer-enb run-oai-ran-tracer-gnb:  ##
run-oai-ran-tracer-%:
	cd docker/oai; export OAI_TRACEE=$*;                                      \
	$(DOCKER_COMPOSE) --profile=oai-ran-tracer up

run-oai-ran-macpdu2wireshark-enb run-oai-ran-macpdu2wireshark-gnb:  ##
run-oai-ran-macpdu2wireshark-%:
	cd docker/oai; export OAI_TRACEE=$*;                                      \
	$(DOCKER_COMPOSE) --profile=oai-ran-macpdu2wireshark up

run-srsran-4g-cell_search: ${O5GC_ENV}  ##
	source ${O5GC_ENV};                                                       \
	docker run --rm --privileged --tty --entrypoint /bin/bash                 \
	    --volume="/dev/bus/usb:/dev/bus/usb"                                  \
	  o5gc/srsran -xc "build/lib/examples/cell_search                         \
	    -b $${EUTRA_BAND} -s $${EUTRA_ARFCN_DL} -e $$((EUTRA_ARFCN_DL+1))"

run-srsran-4g-cell_measurement: ${O5GC_ENV}  ##
	source ${O5GC_ENV};                                                       \
	docker run --rm --privileged --tty --entrypoint /bin/bash                 \
	    --volume="/dev/bus/usb:/dev/bus/usb"                                  \
	  o5gc/srsran -xc "build/lib/examples/cell_measurement -d                 \
	    -f $$(scripts/band_helper.py earfcn_to_freq_dl $${EUTRA_BAND} $${EUTRA_ARFCN_DL})"

run-sigdigger run-osmocom_fft run-swagger-ui: .xhost  ##
	cd modules/o5gc/docker/misc;                                              \
	$(DOCKER_COMPOSE) --profile=$(subst run-,,$@) up

lbgpsdo-list lbgpsdo-status lbgpsdo-detail:
	docker run --rm --privileged                                              \
	    --volume="/dev/bus/usb:/dev/bus/usb" --env LANG=C.UTF-8               \
	  o5gc/misc-lbgpsdo $(subst lbgpsdo-,,$@)

develop-srsran-build develop-srsran-start develop-srsran-stop                 \
develop-srsran-tag-latest develop-srsran-untag-latest                         \
develop-open5gs-build develop-open5gs-start develop-open5gs-stop              \
develop-open5gs-tag-latest develop-open5gs-untag-latest:
	$(MAKE) .$@
