#!/bin/bash
#
# update-arch bootstrap installer.
#
# Fetchable directly from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/aaronsb/arch-update/main/install.sh | bash
#
# What it does:
#   1. Queries GitHub for the latest release tag (or takes $UPDATE_ARCH_REF)
#   2. Downloads the source tarball
#   3. Extracts to a temp dir
#   4. Runs deploy.sh --install from the extracted copy
#   5. Cleans up
#
# No git required on the target machine. Only curl + tar.
#
# Forkers: override repo coordinates via env, e.g.:
#   UPDATE_ARCH_REPO_OWNER=someone UPDATE_ARCH_REPO_NAME=arch-update bash install.sh

set -euo pipefail

: "${UPDATE_ARCH_REPO_OWNER:=aaronsb}"
: "${UPDATE_ARCH_REPO_NAME:=arch-update}"
: "${UPDATE_ARCH_REF:=}"   # empty → resolve to latest release tag (or main)

have() { command -v "$1" &>/dev/null; }
die()  { echo "install.sh: $*" >&2; exit 1; }

have curl || die "curl is required"
have tar  || die "tar is required"

API_BASE="https://api.github.com/repos/${UPDATE_ARCH_REPO_OWNER}/${UPDATE_ARCH_REPO_NAME}"
ARCHIVE_BASE="https://github.com/${UPDATE_ARCH_REPO_OWNER}/${UPDATE_ARCH_REPO_NAME}/archive"

# Minimal JSON extractor: GitHub returns well-formed JSON where the fields
# we want appear on their own line. Good enough for this bootstrap.
json_field() {
    local field="$1"
    grep -oE "\"${field}\":[[:space:]]*\"[^\"]+\"" | head -n1 | sed -E "s/.*\"${field}\":[[:space:]]*\"([^\"]+)\".*/\1/"
}

resolve_ref() {
    if [[ -n "$UPDATE_ARCH_REF" ]]; then
        echo "$UPDATE_ARCH_REF"
        return
    fi
    local latest
    latest=$(curl -fsSL "${API_BASE}/releases/latest" 2>/dev/null | json_field tag_name || true)
    echo "${latest:-main}"
}

resolve_commit() {
    local ref="$1"
    curl -fsSL "${API_BASE}/commits/${ref}" 2>/dev/null | json_field sha || true
}

REF=$(resolve_ref)
COMMIT=$(resolve_commit "$REF")

echo "update-arch: installing ${REF}${COMMIT:+ (${COMMIT:0:7})}"

TMPDIR=$(mktemp -d -t update-arch-install.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

TARBALL_URL="${ARCHIVE_BASE}/${REF}.tar.gz"
echo "  fetching ${TARBALL_URL}"
curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMPDIR"

SRCDIR=$(find "$TMPDIR" -maxdepth 1 -mindepth 1 -type d | head -n1)
[[ -d "$SRCDIR" ]] || die "extraction produced no source directory"

cd "$SRCDIR"
[[ -x ./deploy.sh ]] || die "deploy.sh not found in downloaded source"

export UPDATE_ARCH_INSTALL_FROM="tarball"
export UPDATE_ARCH_INSTALL_REF="$REF"
export UPDATE_ARCH_INSTALL_COMMIT="$COMMIT"

./deploy.sh --install
