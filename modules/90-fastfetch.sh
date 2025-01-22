#!/bin/bash
#
# Display system information using fastfetch
# This is a post-update status module that runs without privileges

MODULE_TYPE="status"

check_supported() {
    command -v fastfetch &>/dev/null
    return $?
}

run_update() {
    fastfetch
    return $?
}
