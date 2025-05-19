BASE_DIR := $(realpath $(dir $(realpath $(firstword $(MAKEFILE_LIST)))))

topology.svg: topology.mmd
	docker run --rm --user `id -u`:`id -g` --volume $(BASE_DIR):/data         \
		minlag/mermaid-cli -i $< -o $@
