# update-arch developer Makefile
#
# Follows the "help-first, verbs required" pattern: `make` alone prints help.
# Every target is a thin wrapper over an existing script — the Makefile
# doesn't own any logic, it just gives them predictable names.

VERSION := $(shell grep '^VERSION=' update.sh | sed -E 's/VERSION="([^"]*)".*/\1/')
DIST    := dist
TARBALL := $(DIST)/update-arch-$(VERSION).tar.gz

.DEFAULT_GOAL := help

.PHONY: help test install uninstall list version package publish clean

help:
	@echo 'update-arch developer targets (v$(VERSION))'
	@echo ''
	@echo '  make test        Run the lamp-check against the repo copy'
	@echo '  make list        List modules with metadata'
	@echo '  make version     Show version banner'
	@echo '  make install     Install from this working tree (./deploy.sh --install)'
	@echo '  make uninstall   Uninstall (./deploy.sh --uninstall --yes)'
	@echo '  make package     Build $(TARBALL) from HEAD'
	@echo '  make publish     Create a GitHub release (requires gh CLI)'
	@echo '  make clean       Remove $(DIST)/'
	@echo ''
	@echo 'Run `make <target>` to execute one. Nothing runs without a target.'

test:
	./update.sh --test

list:
	./update.sh --list

version:
	./update.sh --version

install:
	./deploy.sh --install

uninstall:
	./deploy.sh --uninstall --yes

package: $(TARBALL)

$(TARBALL):
	@mkdir -p $(DIST)
	git archive --format=tar.gz --prefix=update-arch-$(VERSION)/ \
		-o $(TARBALL) HEAD
	@echo 'Created $(TARBALL)'

publish: package
	@if ! command -v gh >/dev/null; then \
		echo 'gh CLI not installed. Upload $(TARBALL) manually to a GitHub release.'; \
		exit 1; \
	fi
	gh release create v$(VERSION) $(TARBALL) \
		--title 'v$(VERSION)' \
		--generate-notes

clean:
	rm -rf $(DIST)
