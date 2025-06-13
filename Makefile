SHELL := /bin/bash -o pipefail
BASE_DIR := $(realpath $(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
ENV_DIR = ${BASE_DIR}/var/etc
MODULES_DIR = ${BASE_DIR}/modules
DOCKER_HOST_BRIDGE := $(shell docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
DEFAULT_ROUTE_IFACE_IP := $(shell ip route | sed -n 's|.* src \(.*\) metric .*|\1|p' | uniq)
HOST_USER_GROUP_ID := $(shell echo $$(id -u):$$(id -g))

export BASE_DIR DOCKER_HOST_BRIDGE OAI_TRACER_ENABLE HOST_USER_GROUP_ID DEFAULT_ROUTE_IFACE_IP
EXPORT_ENV = export BASE_DIR=${BASE_DIR} DOCKER_HOST_BRIDGE=${DOCKER_HOST_BRIDGE} HOST_USER_GROUP_ID=${HOST_USER_GROUP_ID}

O5GC_ENV = ${ENV_DIR}/o5gc.env
get_env = $(shell env=$(or ${2},${O5GC_ENV}); make -s $${env}; source $${env}; echo $(foreach v,${1},$$${v}))

# thanks to https://news.ycombinator.com/item?id=11195539
help:  ## This help
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF }' $(MAKEFILE_LIST)

OCI_IMG_KEY = org.opencontainers.image

SYNC_CACHES = ccache sccache cargo-registry npm-cache go-cache-dl go-cache-build
CACHES = apt-cacher-ng git downloads ${SYNC_CACHES}

var/ssh/authorized_keys: var/ssh/id_ed25519
	cat $<.pub >> $@
var/ssh/id_ed25519:
	ssh-keygen -t ed25519 -N "" -C o5gc -f $@
.PRECIOUS: var/ssh/ssh_host_%_ed25519_key
var/ssh/ssh_host_%_ed25519_key:
	$(foreach keytype, rsa ecdsa ed25519,                                     \
	    ssh-keygen -N "" -t ${keytype} -f var/ssh/ssh_host_$*_${keytype}_key;)

.docker-build-prerequisites: var/ssh/id_ed25519

var/ssl/MOK.der:
	openssl req -nodes -new -x509 -newkey rsa:2048 -days 36500                \
	    -keyout var/ssl/MOK.priv -outform DER -out var/ssl/MOK.der -subj "/CN=o5gc"
	openssl x509 -inform der -in var/ssl/MOK.der -out var/ssl/MOK.pem
system-enroll-mok: var/ssl/MOK.der
	sudo mokutil --import $<
	@echo "--------------"
	@echo "Reboot system!"
	@echo "The device firmware should launch it's MOK manager and prompt to review the new key and confirm it's enrollment, using the one-time password."
	@echo "--------------"
system-test-mok: var/ssl/MOK.der
	sudo mokutil --test-key $<

docker-img-version = $$(${1} run --rm --entrypoint /bin/cat o5gc/${2} /etc/image_version)
docker-src-ip-for-remote = $(shell ip route get $$(getent hosts ${1} | cut -d " " -f1) | sed -n 's|.* src \([0-9.]*\) .*|\1|p')
define docker-build
    $(eval $@_PRJ = $(subst docker-build-,,${2}))
    $(eval $@_IMG = $(subst /,-,${$@_PRJ})$(if ${3},-$(subst docker-build-${2}-,,${3})))
    $(eval $@_TAG = ${$@_IMG}:$(or ${6},latest))
    $(eval $@_BUILD_HOST = $(if $(subst localhost,,${7}),${7}))
    $(eval $@_BUILD_CACHER = $(if ${$@_BUILD_HOST},$(call docker-src-ip-for-remote,${$@_BUILD_HOST}),${DOCKER_HOST_BRIDGE}))
    $(eval $@_DOCKER = docker $(if ${$@_BUILD_HOST},-H ssh://${$@_BUILD_HOST}))
    mkdir -p $(foreach cache,${SYNC_CACHES},var/cache/${cache}/$(if ${7},${7},localhost)/${$@_IMG})
    $(if ${$@_BUILD_HOST},tar -cf var/tmp/${$@_BUILD_HOST}-${$@_IMG}.tar -C modules/${1}/docker/${$@_PRJ} .)
    cd modules/${1}/docker/${$@_PRJ} &&                                       \
    DOCKER_BUILDKIT=1 ${$@_DOCKER} build                                      \
        --tag o5gc/${$@_TAG}                                                  \
		$(if ${5},--target=${5})                                              \
        $(foreach arg,${4},--build-arg $(arg))                                \
        --label ${OCI_IMG_KEY}.created="$(shell date --rfc-3339=seconds)"     \
        --secret id=id_ed25519,src=${BASE_DIR}/var/ssh/id_ed25519             \
        --secret id=id_ed25519.pub,src=${BASE_DIR}/var/ssh/id_ed25519.pub     \
        --add-host o5gc-build-cacher:${$@_BUILD_CACHER}                       \
        --file $(if ${3},$(subst docker-build-${2}-,,${3}).)Dockerfile        \
        $(if ${$@_BUILD_HOST},- < ${BASE_DIR}/var/tmp/${$@_BUILD_HOST}-${$@_IMG}.tar,.)
    $(if ${$@_BUILD_HOST},rm -f var/tmp/${$@_BUILD_HOST}-${$@_IMG}.tar)
    echo "FROM o5gc/${$@_TAG}" | ${$@_DOCKER} build                           \
        --tag "o5gc/${$@_TAG}"                                                \
        --label ${OCI_IMG_KEY}.version="$(call docker-img-version,${$@_DOCKER},${$@_TAG})" -
    ${$@_DOCKER} tag                                                          \
        o5gc/${$@_TAG}                                                        \
        o5gc/${$@_IMG}:$(call docker-img-version,${$@_DOCKER},${$@_TAG})
    ${$@_DOCKER} image ls o5gc/${$@_IMG}
endef

define docker-build-remotely
    $(foreach ver,$(if ${2},${2},latest),                                     \
        $(MAKE) ${PARALLEL_JOBS} RUN_PARALLEL=1 $(foreach host,${1},$@-${ver}@${host}) &&) true
endef
define parse-stem
    $(eval $@_V = $(firstword $(subst @, ,${1})))
    $(eval $@_H = $(lastword $(subst @, ,${1})))
endef

DOCKER_RAN_HOSTS = $(sort $(call get_env,ENB_HOSTNAME GNB_HOSTNAME))
DOCKER_ALL_HOSTS = $(sort localhost ${DOCKER_RAN_HOSTS})

DOCKER_BUILD_ALL = $(filter-out %-build-cacher,$(filter-out %-base,$(sort     \
    $(shell cd modules; find -L ./ -name *Dockerfile                          \
        | sed -E "s|./.*/docker/(.*)/([^.]*).?Dockerfile|docker-build-\1-\2|" \
        | sed -E "s|/|-|" | sed -E "s|(.*)-$$|\1|"))))
docker-build-all: clean build-cacher-restart docker-build-o5gc-base  ## Build all Docker images
	$(MAKE) ${PARALLEL_JOBS} RUN_PARALLEL=1 ${DOCKER_BUILD_ALL} pull-all-external-images
	$(MAKE) docker-cleanup
	docker image ls o5gc/* | (read h; echo "$$h"; LC_ALL=C sort)

pull-all-external-images:
	$(foreach img,$(filter-out o5gc/%,${IMAGES}),docker pull ${img};)

DEVLOP_IMAGES = $(shell docker images o5gc/*:develop --format "{{.Repository}}")
DEVELOP_VOLUMES = $(shell                                                     \
    for img in ${DEVLOP_IMAGES}; do                                           \
        id_latest=$$(docker images --format {{.ID}} $${img}:latest);          \
        id_develop=$$(docker images --format {{.ID}} $${img}:develop);        \
        prj=$${img/o5gc\//}; v=$${prj//-/_};                                  \
        [ "$${id_latest}" == "$${id_develop}" ] &&                            \
            echo DEVELOP_VOLUME_$${v^^}=develop:/o5gc/;                       \
    done;)
EXPORT_DEVELOP_VOLUMES := $(if ${DEVELOP_VOLUMES},export ${DEVELOP_VOLUMES},:)

DOCKER_COMPOSE = $(EXPORT_DEVELOP_VOLUMES); $(EXPORT_ENV);                    \
    export O5GC_STACK=$$(basename $${PWD});                                   \
    export MODULE=$$(realpath --relative-to=${BASE_DIR} $${PWD}|cut -d / -f2);\
    export ENV_FILE=${ENV_DIR}/$${MODULE}/$${O5GC_STACK}.env;                 \
    $(MAKE) -s -C ${BASE_DIR} $${ENV_FILE};                                   \
    docker compose --env-file=$${ENV_FILE}                                    \
        --file $$(ls | grep -E "docker-compose.yaml|services.yaml")           \
        --file ${BASE_DIR}/etc/networks.yaml

STACKS = $(shell find modules/*/stacks/ -name docker-compose.yaml -printf "%h ")
profiles = $(foreach p,$(shell cd ${1}; $(DOCKER_COMPOSE) config --profiles),--profile ${p})
IMAGES = $(eval IMAGES := $(sort $(foreach s,${STACKS},$(shell cd ${s}; $(DOCKER_COMPOSE) $(call profiles,${s}) config --images))))${IMAGES}
image_versions = $(sort $(foreach i,$(filter o5gc/$1:%,${IMAGES}),$(shell echo ${i} | sed "s|o5gc/$1:\(.*\)|\1|")))

DEFAULT_MODULES = base o5gc
DEFAULT_MODULE_TARGET_FILES = $(foreach module,${DEFAULT_MODULES},modules/${module}/targets.mk) 
MODULE_TARGET_FILES = ${DEFAULT_MODULE_TARGET_FILES} $(sort $(filter-out ${DEFAULT_MODULE_TARGET_FILES},$(wildcard modules/*/targets.mk)))
include ${MODULE_TARGET_FILES}

.develop-%-build:
	$(call docker-build,$*,,,develop)
.develop-%-tag-latest:
	docker tag o5gc/$*:develop o5gc/$*:latest
	docker images o5gc/$*
.develop-%-untag-latest:
	@rm -f docker/$(subst -,/,$*)/.build
	$(call docker-build,$*)
.develop-%-start: var/ssh/ssh_host_$$*_ed25519_key var/ssh/authorized_keys
	cd docker/$(subst -,/,$*);                                                \
	$(DOCKER_COMPOSE) --profile=develop up --detach
.develop-%-stop:
	cd docker/$(subst -,/,$*);                                                \
	$(DOCKER_COMPOSE) --profile=develop down

.SECONDEXPANSION:
${ENV_OVERRIDES_PATH}: ;
${ENV_DIR}/%.env:                                                             \
        ${BASE_DIR}/etc/settings.env ${BASE_DIR}/etc/networks.env             \
        ${BASE_DIR}/etc/o5gc.env ${BASE_DIR}/etc/local.env                    \
        $$(wildcard ${MODULES_DIR}/$$(firstword $$(subst /, ,$$*))/settings.env) \
        $$(wildcard ${MODULES_DIR}/$$(subst /,/stacks/,$$*)/settings.env)     \
        ${ENV_OVERRIDES_PATH} ${BASE_DIR}/etc/uedb.env
	mkdir -p $(dir $@)
	awk 1 $^ > $@
	$(if $(findstring ${BASE_DIR}/etc/local.env,$?),$(MAKE) ignore-localenv-changes)

ignore-localenv-changes:
ifneq ($(shell id -u), 0)
	git -C ${BASE_DIR} rev-parse --is-inside-work-tree &>/dev/null &&         \
	git update-index --skip-worktree ${BASE_DIR}/etc/local.env
endif

.create-running-env: docker-cleanup

.xhost:
	xhost local:root

run_stack = cd modules/${1}/stacks/${2}; $(DOCKER_COMPOSE) $(foreach p,${3},--profile ${p}) up $(if ${DETACHED},--detach)
stop_stack = cd modules/${1}/stacks/${2}; $(DOCKER_COMPOSE) $(foreach p,${3},--profile ${p}) down

uhd_image_loader:  ##
	scripts/uhd_image_loader.sh

docker-cleanup: ${O5GC_ENV}  ## Cleanup old Docker related artifacts
	$(MAKE) $(foreach host,${DOCKER_ALL_HOSTS},docker-cleanup-${host})
docker-cleanup-%:
	$(eval $@_HOST = $(if $(subst localhost,,$*),$*))
	$(eval $@_DOCKER = docker $(if ${$@_HOST},-H ssh://${$@_HOST}))
	${$@_DOCKER} system prune --filter label!=o5gc-bridge --force --volumes

docker-purge-old-images:
	@echo "Old images:";                                                      \
	images=$$(docker images o5gc/* --format "{{.Repository}}:{{.Tag}}"        \
	    | grep -v build-cacher | sort);                                       \
	for img in $${images}; do                                                 \
	  img_created=$$(docker inspect --format                                  \
	      '{{index .Config.Labels "${OCI_IMG_KEY}.created"}}' $${img});       \
	  age=$$((($$(date +%s)-$$(date +%s -d "$${img_created}") )/(60*60*24))); \
	  if [ $${age} -gt 0 ]; then                                              \
	    echo "$${img} build $${age} days ago";                                \
		old_images="$${old_images} $${img}";                                  \
	  fi;                                                                     \
	done;                                                                     \
	if [ -z "$${old_images}" ]; then exit 0; fi;                              \
	echo -n 'Purge? [y/n] '; read 'x';                                        \
	[ "$$x" == 'y' ] && docker image rm --force $${old_images}
	$(MAKE) docker-cleanup clean


docker-purge-all-images: build-cacher-stop webui-stop docker-etc-hosts-updater-stop ## purge all project related Docker images
	@echo -n 'Purge all o5gc images? [y/n] ' && read 'x' && [ $$x == 'y' ]
	images=$$(docker images o5gc/* -q | sort -u);                           \
	[ -z "$${images}" ] || docker image rm --force $${images}
	$(MAKE) docker-cleanup clean

clean:
	rm -f tests/.venv.build
	rm -f var/etc/*.env var/tmp/*

system-install-all: systemd-install-unit system-install-docker                \
    system-install-python3-virtualenv tests-install-venv scripts-install-venv \
    system-install-nfs-server

systemd-install-unit:
	sudo ln -sfv ${PWD}/scripts/o5gc.service -t /etc/systemd/system
	sudo systemctl enable o5gc
	sudo ./scripts/startup.sh

systemd-startup-unit:
	sudo ./scripts/startup.sh

systemd-verfiy-unit:
	systemd-analyze verify ./scripts/o5gc.service

.system-install-docker-localhost:
	sudo modules/base/docker/o5gc/install-docker.sh all
.system-install-docker-%:
	scp modules/base/docker/o5gc/install-docker.sh $*:/tmp
	ssh -t $* sudo /tmp/install-docker.sh all
system-install-docker: ${O5GC_ENV}
	$(MAKE) $(foreach host,${DOCKER_ALL_HOSTS},.$@-${host})

NFS_EXPORT_COMMENT = \# o5gc development share
NFS_EXPORT_ENTRY = /home 127.0.0.1(rw,async,no_subtree_check,crossmnt,all_squash,crossmnt,anonuid=$(shell id -u),anongid=$(shell id -g))
system-install-nfs-server:
	sudo apt install nfs-kernel-server
	grep -Fxq "$(NFS_EXPORT_COMMENT)" /etc/exports ||                         \
	    echo -e "\n$(NFS_EXPORT_COMMENT)\n$(NFS_EXPORT_ENTRY)\n" | sudo tee -a /etc/exports
	sudo exportfs -ra

system-install-python3-virtualenv:
	sudo apt update
	sudo apt install python3-virtualenv

scripts-install-venv: scripts/.venv.build
scripts-remove-venv:
	rm -rf scripts/.venv.build scripts/venv
scripts/.venv.build: scripts/requirements.txt
	test -d scripts/venv || virtualenv scripts/venv
	source scripts/venv/bin/activate; pip install -r $<
	@touch $@

ctop:
	docker run --rm --tty --interactive --name=ctop                           \
	    --volume /var/run/docker.sock:/var/run/docker.sock                    \
	  quay.io/vektorlab/ctop
lazydocker:
	docker run --rm --tty --interactive --name lazydocker                     \
	    --volume /var/run/docker.sock:/var/run/docker.sock                    \
	  lazyteam/lazydocker

lint:
	$(MAKE) --ignore-errors shellcheck yamllint codespell hadolint            \
	    markdownlint space-end-check cargo-machete

SHELLCHECK_FILES = $(filter-out %-healthcheck.sh %/wait-for-it.sh,            \
                       $(shell find modules/ etc/ scripts/ -name '*.sh' -not -path '*/node_modules/*'))
SHELLCHECK_IGNORE = SC1091 SC2016 SC2046 SC3037 SC2086 SC2059 SC2155 SC2153   \
                    SC2291 SC3040 SC1090 SC2317
shellcheck:
	@echo Running shellcheck
	@docker run --rm --volume="${PWD}:/mnt"                                   \
	    -e SHELLCHECK_OPTS="$(foreach rule,${SHELLCHECK_IGNORE},-e ${rule})"  \
	  koalaman/shellcheck:stable ${SHELLCHECK_FILES}

YAMLLINT_FILES = $(wildcard modules/*/stacks/*/docker-compose.yaml)           \
                 $(shell find modules/*/docker/ -name services.yaml)          \
                 etc/networks.yaml Doc/mkdocs.yml
YAMLLINT_CONFIG = "{extends: default, rules: {comments-indentation: disable,  \
    document-start: {present: false}, line-length: {max: 120}}}"
yamllint:
	@echo Running yamllint
	@docker run --rm --volume="${PWD}:/data"                                  \
	  cytopia/yamllint:latest                                                 \
	    -s -d ${YAMLLINT_CONFIG} ${YAMLLINT_FILES}

DOCKER_FILES = $(filter-out ${DOCKER_FILES_IGNORE},$(shell find ${BASE_DIR}/modules/*/docker/ -name *Dockerfile -not -path '*/node_modules/*'))
HADOLINT_IGNORE = DL3003 DL3007 DL3008 DL3009 SC3010 DL3013 DL3018 DL3059     \
                  DL4006  ${SHELLCHECK_IGNORE}
hadolint:
	@echo Running hadolint
	@docker run --rm --volume ${BASE_DIR}:${BASE_DIR}                         \
	  hadolint/hadolint hadolint                                              \
	    $(foreach rule,${HADOLINT_IGNORE},--ignore ${rule}) ${DOCKER_FILES}

MD_FILES = $(wildcard ${BASE_DIR}/Doc/*.md)
MD_IGNORE = ~MD001,~MD002,~MD022,~MD031,~MD032,~MD041
markdownlint:
	@echo Running markdownlint
	@docker run --rm -v ${BASE_DIR}:${BASE_DIR}                               \
	  markdownlint/markdownlint                                               \
	    --rules ${MD_IGNORE} --style=$(BASE_DIR)/Doc/.mdl.style ${MD_FILES}

cargo-machete:
	docker run -v $(BASE_DIR)/modules:/src ghcr.io/bnjbvr/cargo-machete:latest

CODESPELL_FILES += $(shell find etc/ -name *.env)                             \
                  ${SHELLCHECK_FILES} ${DOCKER_FILES} ${MD_FILES} ${YAMLLINT_FILES} Makefile
CODESPELL_IGNORE_WORDS = ue,ues,leas,bund,te
codespell: scripts-install-venv
	@echo Running codespell
	@source scripts/venv/bin/activate;                                        \
	codespell -L ${CODESPELL_IGNORE_WORDS} ${CODESPELL_FILES}

space-end-check:
	@echo "check for files that do not end with a newline"
	@! rg -g '!*.svg' -Ul '[^\n]\z' || false
	@echo "check for files with trailing whitespaces"
	@! grep -n '[[:blank:]]$$' ${CODESPELL_FILES}

print-%:
	@echo '$*=$($*)'

PARALLEL_JOBS = $(or $(filter -j%,${MAKEFLAGS}),-j2)
ifneq (${RUN_PARALLEL},1)
.NOTPARALLEL:
endif

.FORCE:
