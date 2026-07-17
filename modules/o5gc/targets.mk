docker-build-srsran: docker-build-srsran-4g docker-build-srsran-project
docker-build-srsran-4g docker-build-srsran-project: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p srsran/$(word 4,$(subst -, ,$@)) --target proxy
	$(call docker-build-remotely,${DOCKER_RAN_HOSTS})
docker-build-srsran-4g-at-% docker-build-srsran-project-at-%:
	${DOCKER_BUILD} -m o5gc -p srsran/$(word 4,$(subst -, ,$@)) --host $*

docker-build-ocudu: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p ocudu
docker-build-ocudu-at-%:
	${DOCKER_BUILD} -m o5gc -p ocudu --host $*


OPEN5GS_VERSIONS = $(filter-out latest,$(call image_versions,open5gs))
docker-build-open5gs: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p open5gs --version-arg OPEN5GS_VERSION $(foreach ver,${OPEN5GS_VERSIONS}, --version ${ver})
	${DOCKER_BUILD} -m o5gc -p open5gs

OAI_RAN_VERSIONS = $(call image_versions,oai-ran)
docker-build-oai-ran: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p oai -i ran --version-arg VERSION                \
	    --target proxy $(foreach ver,${OAI_RAN_VERSIONS}, --version ${ver})
	$(call docker-build-remotely,${DOCKER_RAN_HOSTS})
docker-build-oai-ran-at-%:
	${DOCKER_BUILD} -m o5gc -p oai -i ran --version-arg VERSION                \
	    --host $* $(foreach ver,${OAI_RAN_VERSIONS}, --version ${ver})

OAI_CORE_IMAGES = amf ausf lmf nrf smf udm udr upf
docker-build-oai-core:
	$(MAKE) ${PARALLEL_JOBS} RUN_PARALLEL=1 $(foreach img,${OAI_CORE_IMAGES},docker-build-oai-${img})
	$(call docker_image_ls,oai-*)

OAI_CN5G_VERSIONS = $(sort $(foreach img,${OAI_CORE_IMAGES},$(filter-out latest,$(call image_versions,oai-${img}))))
docker-build-oai-cn5g-base: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p oai -i cn5g-base --version-arg OAI_CN5G_VERSION $(foreach ver,${OAI_CN5G_VERSIONS}, --version ${ver})
	${DOCKER_BUILD} -m o5gc -p oai -i cn5g-base

docker-build-oai-amf docker-build-oai-ausf docker-build-oai-lmf               \
docker-build-oai-nrf docker-build-oai-smf docker-build-oai-udm                \
docker-build-oai-udr docker-build-oai-upf: docker-build-oai-cn5g-base
	${DOCKER_BUILD} -m o5gc -p oai -i $@ --version-arg OAI_CN5G_VERSION $(foreach ver,${OAI_CN5G_VERSIONS}, --version ${ver})
	${DOCKER_BUILD} -m o5gc -p oai -i $@

OSMOCOM_IMAGES = base hlr mgw stp msc bts trx bsc ggsn sgsn pcu cbc
docker-build-osmocom: $(foreach img,${OSMOCOM_IMAGES},docker-build-osmocom-${img})
	$(call docker_image_ls,osmocom-*)
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

docker-build-ueransim docker-build-packetrusher                               \
docker-build-mysql docker-build-free5gc: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p $@

docker-build-ellacore: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p ellacore

docker-build-misc-falcon docker-build-misc-sigdigger                          \
docker-build-misc-gr-osmosdr docker-build-misc-ltesniffer                     \
docker-build-misc-swagger: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p misc -i $@
docker-build-misc-nrscope: docker-build-o5gc-base
	${DOCKER_BUILD} -m o5gc -p srsran/4g --target develop --version develop
	${DOCKER_BUILD} -m o5gc -p misc -i nrscope

# Most stacks are started/stopped via the generated run-/stop- targets
# (see 'make list-stacks'); their default profiles come from the top-level
# 'x-o5gc-profiles:' key in the stack's docker-compose.yaml.  Only targets
# that need extra environment variables or dynamic profiles are listed here.

run-oai-5g-basic-rfsim:
	export OAI_RFSIM_ENABLE=1;                                                \
	$(call run_stack,o5gc,oai-5g-basic,gnb core ue)
run-oai-5g-minimalist-rfsim:
	export OAI_RFSIM_ENABLE=1;                                                \
	$(call run_stack,o5gc,oai-5g-minimalist,gnb core ue)

run-srsran-open5gs-4g-volte: ${ENV_DIR}/srsran-open5gs-4g-volte.env  ##
	$(call run_stack,o5gc,srsran-open5gs-4g-volte,enb core volte                   \
	    $(if $(subst SMS-over-SGs,,$(call get_env,SMS_DOMAIN,$<)),smsc,osmocom))
stop-srsran-open5gs-4g-volte:  ##
	$(call stop_stack,o5gc,srsran-open5gs-4g-volte,enb core volte)
run-srsran-open5gs-4g-volte-core: ${ENV_DIR}/srsran-open5gs-4g-volte.env
	$(call run_stack,o5gc,srsran-open5gs-4g-volte,core volte                       \
	    $(if $(subst SMS-over-SGs,,$(call get_env,SMS_DOMAIN,$<)),smsc,osmocom))

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

DOCKER_RUN_SRSRAN_4G = docker run --rm --privileged --tty                     \
    --entrypoint /bin/bash --volume="/dev/bus/usb:/dev/bus/usb" o5gc/srsran-4g
run-srsran-4g-cell_search: ${O5GC_ENV}  ##
	source ${O5GC_ENV};                                                       \
	${DOCKER_RUN_SRSRAN_4G} -xc "build/lib/examples/cell_search               \
	    -b $${EUTRA_BAND} -s $${EUTRA_ARFCN_DL} -e $$((EUTRA_ARFCN_DL+1))"
run-srsran-4g-cell_search-band: ${O5GC_ENV}  ##
	source ${O5GC_ENV};                                                       \
	${DOCKER_RUN_SRSRAN_4G} -xc "build/lib/examples/cell_search               \
	    -b $${EUTRA_BAND}"
run-srsran-4g-cell_measurement: ${O5GC_ENV}  ##
	source ${O5GC_ENV};                                                       \
	${DOCKER_RUN_SRSRAN_4G} -xc "build/lib/examples/cell_measurement -d       \
	    -f $$(scripts/band_helper.py earfcn_to_freq_dl $${EUTRA_BAND} $${EUTRA_ARFCN_DL})"

run-sigdigger run-osmocom_fft run-swagger-ui: .xhost  ##
	cd modules/o5gc/docker/misc;                                              \
	$(DOCKER_COMPOSE) --profile=$(subst run-,,$@) up

develop-srsran-4g-build develop-srsran-4g-start develop-srsran-4g-stop        \
develop-srsran-4g-tag-latest develop-srsran-4g-untag-latest                   \
develop-open5gs-build develop-open5gs-start develop-open5gs-stop              \
develop-open5gs-tag-latest develop-open5gs-untag-latest:
	$(MAKE) .$@
