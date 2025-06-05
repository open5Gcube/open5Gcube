BASE_O5GC_DIR = ${MODULES_DIR}/base/docker/o5gc

docker-build-o5gc-build-cacher:
	docker build --file ./modules/base/docker/o5gc/build-cacher.Dockerfile    \
	    --tag o5gc/build-cacher                                               \
	    --label ${OCI_IMG_KEY}.created="$(shell date --rfc-3339=seconds)"     \
	    --build-arg SYNC_CACHES="${SYNC_CACHES}"                              \
	  ./modules/base/docker/o5gc

build-cacher-start: docker-build-o5gc-build-cacher
	mkdir -p $(foreach cache,${CACHES},var/cache/${cache})
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=build-cacher up --detach
build-cacher-stop:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=build-cacher down || true
build-cacher-restart:
	$(MAKE) build-cacher-stop build-cacher-start
build-cacher-clean:
	rm -rf $(foreach cache,${CACHES},var/cache/${cache}/*)

O5GC_BASE_IMAGES = jammy focal
TZ=$(shell timedatectl show -p Timezone --value)
docker-build-o5gc-base:
	$(call docker-build-remotely,${DOCKER_ALL_HOSTS},${O5GC_BASE_IMAGES})
	docker image ls o5gc/o5gc-base
docker-build-o5gc-base-%: .docker-build-prerequisites
	$(call parse-stem,$*)
	$(call docker-build,base,o5gc,base,BUILD_HOST=${$@_H} BASE_IMG=${$@_V} TZ=$(TZ),,${$@_V},${$@_H})

docker-build-o5gc-mkdocs:
	$(call docker-build,base,o5gc,mkdocs)
docker-build-o5gc-webui: docker-build-o5gc-base Documentation-build
	rm -rf modules/base/docker/o5gc/webui/frontend/theme/*
	[ -z "$(call get_env,WEBUI_THEME)" ] ||                                   \
	    cp -a $(call get_env,WEBUI_THEME)/* modules/base/docker/o5gc/webui/frontend/theme/
	$(call docker-build,base,o5gc/webui)

docker-build-misc-lbgpsdo: docker-build-o5gc-base
	$(call docker-build,base,misc,lbgpsdo)

Documentation-build: docker-build-o5gc-mkdocs
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=docu run --no-TTY --rm                        \
	    --env DATE="Date: $(shell date +%Y-%m-%d)" documentation build #--strict
	rm Doc/html/mkdocs.yml
Documentation-serve-start: docker-build-core-mkdocs
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=docu up --detach
	@echo Live-reloading docs server available at                             \
	    http://${DEFAULT_ROUTE_IFACE_IP}:$(call get_host_port,documentation_serve)
Documentation-serve-stop:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=docu down || true

webui-start:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=webui up --detach
	@echo WebUI available at http://${DEFAULT_ROUTE_IFACE_IP}
webui-stop:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=webui down || true
webui-restart:
	$(MAKE) webui-stop webui-start

docker-etc-hosts-updater-start:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=docker-etc-hosts-updater up --detach
docker-etc-hosts-updater-stop:
	cd ${BASE_O5GC_DIR};                                                      \
	$(DOCKER_COMPOSE) --profile=docker-etc-hosts-updater down || true
docker-etc-hosts-updater-restart:
	$(MAKE) docker-etc-hosts-updater-stop docker-etc-hosts-updater-start

WEBUI_SRC_DIR = ${BASE_O5GC_DIR}/webui
CODESPELL_FILES += $(shell find ${WEBUI_SRC_DIR}/frontend/src/ -name *.ts)    \
                   $(shell find ${WEBUI_SRC_DIR}/frontend/src/ -name *.vue)   \
                   $(shell find ${WEBUI_SRC_DIR}/backend/src/ -name *.py)
