# Makefile for raspbian-ua-netinst

# configuration
BUILD_DEPEND = packages config scripts
IMAGE_DEPEND = bootfs

IMAGE = raspbian-ua-netinst-$(shell date +%Y%m%d)-git$(shell git rev-parse --short @{0}).img

BUILD_DEPEND_FILES = $(shell find $(BUILD_DEPEND) 2>/dev/null)
IMAGE_DEPEND_FILES = $(shell find $(IMAGE_DEPEND) 2>/dev/null)

# build targets
default: build

update:
packages: packages/updated
build: bootfs/config.txt
image: $(IMAGE)
clean:

.PHONY: default update build image clean

# rules
update:
	@$(MAKE) --always-make packages

packages/updated: update.sh
	@rm -f packages/updated
	./update.sh
	@touch packages/updated

bootfs/config.txt: build.sh packages/updated $(BUILD_DEPEND_FILES)
	./build.sh

$(IMAGE): buildroot.sh bootfs/config.txt $(IMAGE_DEPEND_FILES)
	sudo ./buildroot.sh

clean:
	./clean.sh
