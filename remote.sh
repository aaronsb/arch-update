#!/bin/bash
#
# Minimal GitHub read-only client for update-arch.
#
# Exposes:
#   json_field <field>           (stdin → stdout)   extract a top-level string field
#   upstream_latest_ref                             tag name (or branch when channel=branch)
#   upstream_commit <ref>                           sha for a ref
#   upstream_release_body <tag>                     release notes body (empty if none)
#   print_release_notes <tag>                       headered + indented version of above
#
# All calls require curl. REPO_OWNER, REPO_NAME, UPDATE_CHANNEL, UPDATE_BRANCH
# come from read_upstream_config in utils.sh — callers are expected to have
# already sourced it.
#
# No state, no side effects beyond stdout. Safe to source.

# Extract a top-level JSON string field from stdin. Good enough for GitHub
# API responses, not a general JSON parser.
json_field() {
    local field="$1"
    grep -oE "\"${field}\":[[:space:]]*\"[^\"]+\"" \
        | head -n1 \
        | sed -E "s/.*\"${field}\":[[:space:]]*\"([^\"]+)\".*/\1/"
}

# Resolve the upstream ref to follow. For UPDATE_CHANNEL=tag, returns the
# latest release tag (or "main" when no release exists). For =branch,
# returns UPDATE_BRANCH directly.
upstream_latest_ref() {
    local api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
    if [[ "$UPDATE_CHANNEL" == "branch" ]]; then
        echo "$UPDATE_BRANCH"
    else
        local tag
        tag=$(curl -fsSL "${api_base}/releases/latest" 2>/dev/null | json_field tag_name)
        echo "${tag:-main}"
    fi
}

# Resolve a ref (tag, branch, or sha) to a full commit sha.
upstream_commit() {
    local ref="$1"
    local api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
    curl -fsSL "${api_base}/commits/${ref}" 2>/dev/null | json_field sha
}

# Fetch the release body (notes) for a tag. Empty if the tag has no release
# (e.g., UPDATE_CHANNEL=branch, or an untagged commit). Not a fatal error.
#
# GitHub returns the body as a JSON string. Walk character-by-character in
# awk, unescaping the handful of sequences that commonly appear in notes.
upstream_release_body() {
    local tag="$1"
    [[ -z "$tag" ]] && return 0
    local api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
    curl -fsSL "${api_base}/releases/tags/${tag}" 2>/dev/null \
        | awk '
            BEGIN { in_body = 0; out = "" }
            /"body":[[:space:]]*"/ {
                sub(/^.*"body":[[:space:]]*"/, "")
                in_body = 1
            }
            in_body {
                line = $0
                while (length(line) > 0) {
                    c = substr(line, 1, 1)
                    if (c == "\\" && length(line) > 1) {
                        n = substr(line, 2, 1)
                        if      (n == "n")  out = out "\n"
                        else if (n == "r")  { }                 # swallow CR
                        else if (n == "t")  out = out "\t"
                        else if (n == "\"") out = out "\""
                        else if (n == "\\") out = out "\\"
                        else                out = out n
                        line = substr(line, 3)
                    } else if (c == "\"") {
                        in_body = 0
                        line = ""
                    } else {
                        out = out c
                        line = substr(line, 2)
                    }
                }
            }
            END { print out }
        '
}

# Print release notes with a header. Silent if the tag has no release body
# (branch channel, untagged commits, API error).
#
# If a markdown renderer is present on PATH, use it for nicer output —
# checked in preference order: glow > mdcat > bat. Plain indented text is
# always a valid fallback. Optional: install `glow` for the best result.
print_release_notes() {
    local tag="$1"
    local body
    body=$(upstream_release_body "$tag")
    [[ -z "$body" ]] && return 0

    echo
    print_header "${ICONS[info]} release notes: $tag"

    # Only render when stdout is a real terminal. When we're being tee'd
    # into a log (--run), or piped anywhere else, produce plain text —
    # ANSI escape codes in log files are garbage.
    if [[ -t 1 ]] && command -v glow &>/dev/null; then
        glow -s auto - <<< "$body"
    elif [[ -t 1 ]] && command -v mdcat &>/dev/null; then
        mdcat <<< "$body"
    elif [[ -t 1 ]] && command -v bat &>/dev/null; then
        bat --language=markdown --style=plain --paging=never <<< "$body"
    else
        sed 's/^/  /' <<< "$body"
    fi
    echo
}
