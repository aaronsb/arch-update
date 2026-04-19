# update-arch developer Makefile
#
# Follows the "help-first, verbs required" pattern: `make` alone prints help.
# Every target is a thin wrapper over an existing script — the Makefile
# doesn't own any logic, it just gives them predictable names.

.DEFAULT_GOAL := help

.PHONY: help test install uninstall list version clean

help:
	@echo 'update-arch developer targets'
	@echo ''
	@echo '  make test        Run the lamp-check against the repo copy'
	@echo '  make list        List modules with metadata'
	@echo '  make version     Show version banner'
	@echo '  make install     Install from this working tree (./deploy.sh --install)'
	@echo '  make uninstall   Uninstall (./deploy.sh --uninstall --yes)'
	@echo '  make clean       Remove build artifacts (if any)'
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

clean:
	rm -rf dist/
