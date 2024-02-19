HUGO_VERSION ?= 0.123.8
BUILD_OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
BUILD_ARCH := $(shell uname -m)
OPEN_CMD := xdg-open

ifeq ($(BUILD_OS),darwin)
OPEN_CMD = open
endif

ifeq ($(BUILD_ARCH),x86_64)
BUILD_ARCH := amd64
else ifeq ($(BUILD_ARCH),aarch64)
BUILD_ARCH := arm64
endif
ifeq ($(BUILD_OS),darwin)
BUILD_ARCH = universal
endif

.PHONY: hugo
hugo: bin/hugo-$(HUGO_VERSION)-$(BUILD_ARCH)

bin/hugo-$(HUGO_VERSION)-$(BUILD_ARCH):
	mkdir -p bin
	curl -L https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/hugo_extended_$(HUGO_VERSION)_$(BUILD_OS)-$(BUILD_ARCH).tar.gz | tar -xz hugo
	mv hugo bin/hugo-$(HUGO_VERSION)-$(BUILD_ARCH)
	ln -sf hugo-$(HUGO_VERSION)-$(BUILD_ARCH) bin/hugo

.PHONY: serve-local
serve-local: hugo
	bin/hugo -D server

.PHONY: build
build: hugo
	bin/hugo
