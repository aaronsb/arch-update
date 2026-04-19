# update-arch developer Makefile
#
# Follows the "help-first, verbs required" pattern: `make` alone prints help.
# Every target is a thin wrapper over an existing script — the Makefile
# doesn't own any logic, it just gives them predictable names.

VERSION  := $(shell grep '^VERSION=' update.sh | sed -E 's/VERSION="([^"]*)".*/\1/')
DIST     := dist
TARBALL  := $(DIST)/update-arch-$(VERSION).tar.gz
NOTES    := $(DIST)/release-notes-$(VERSION).md

# Most recent semver tag that isn't the version we're about to publish.
# Empty on the very first release (no tags yet).
PREV_TAG := $(shell git tag --sort=-version:refname 2>/dev/null | grep -v '^v$(VERSION)$$' | head -n 1)

# Browser URL for this repo — translate git@github.com:... into https://...
REPO_URL := $(shell git remote get-url origin 2>/dev/null | sed -E 's|git@github.com:|https://github.com/|; s|\.git$$||')

.DEFAULT_GOAL := help

.PHONY: help test install uninstall list version package notes publish clean

help:
	@echo 'update-arch developer targets (v$(VERSION))'
	@echo ''
	@echo '  make test        Run the lamp-check against the repo copy'
	@echo '  make list        List modules with metadata'
	@echo '  make version     Show version banner'
	@echo '  make install     Install from this working tree (./deploy.sh --install)'
	@echo '  make uninstall   Uninstall (./deploy.sh --uninstall --yes)'
	@echo '  make package     Build $(TARBALL) from HEAD'
	@echo '  make notes       Generate $(NOTES) from commits since $(PREV_TAG)'
	@echo '  make publish     Build tarball + notes, cut a GitHub release (requires gh CLI)'
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

# ---------------------------------------------------------------------------
# Release artifacts
# ---------------------------------------------------------------------------

package: $(TARBALL)

$(TARBALL):
	@mkdir -p $(DIST)
	git archive --format=tar.gz --prefix=update-arch-$(VERSION)/ \
		-o $(TARBALL) HEAD
	@echo 'Created $(TARBALL)'

# Always regenerate: commit set can change without the file existing.
notes:
	@mkdir -p $(DIST)
	@if [ -z '$(PREV_TAG)' ]; then \
		printf '# v%s\n\nInitial release.\n' '$(VERSION)' > $(NOTES); \
	else \
		{ \
			printf '# v%s\n\n' '$(VERSION)'; \
			printf '## Changes since %s\n\n' '$(PREV_TAG)'; \
			git log '$(PREV_TAG)..HEAD' --reverse \
				--format='### %s%n%n%b'; \
			printf '\n---\n\n'; \
			printf '**Full changelog**: %s/compare/%s...v%s\n' \
				'$(REPO_URL)' '$(PREV_TAG)' '$(VERSION)'; \
		} > $(NOTES); \
	fi
	@echo 'Release notes → $(NOTES)'

publish: package notes
	@if ! command -v gh >/dev/null; then \
		echo 'gh CLI not installed. Upload $(TARBALL) with $(NOTES) manually.'; \
		exit 1; \
	fi
	@echo ''
	@echo '=== release notes preview ==='
	@cat $(NOTES)
	@echo '=== end preview ==='
	@echo ''
	gh release create v$(VERSION) $(TARBALL) \
		--title 'v$(VERSION)' \
		--notes-file $(NOTES)

clean:
	rm -rf $(DIST)
