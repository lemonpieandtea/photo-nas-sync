#!/bin/bash

# print_help
#
# description: Print the help message with script usage details
print_help() {
    echo -e "
$(c_yellow_regular NAME)

    photo-nas-sync - Sync desired directory with NAS conterpart (rsync).

$(c_yellow_regular SYNOPSIS)

    $(c_white_underline photo-nas-sync) [-i | --input LOCATION] -o | --output LOCATION
                   [-p, --port PORT] [-f, --password-file FILE]
                   [-t | --test] [-d | --debug] [-h | --help]

$(c_yellow_regular DESCRIPTION)

    Script runs rsync between input and output locations.

$(c_yellow_regular OPTIONS)

    -p, --port PORT
        SSH port to use. Default is 22.

    -f, --password-file FILE
        File with user SSH password.

    -i, --input LOCATION
        Input location to copy all media files from.

    -o, --output LOCATION
        Output location to store all media files to.

    -t, --test
        Test mode. No actual changes to the files would be made. Script will
        only print any planned changes. Useful for the test run.

    -d, --debug
        Debug mode. Print all debug information.

    -h, --help
        Print this help message.
"
}

# ctrl_c
#
# description: Handle CTRL+C interruption and exit the script gracefully
ctrl_c() {
    echo
    warn "Script canceled with CTRL+C"
    exit_failure
}

# parse_command_line arguments
#
# description: Parse command-line arguments and set global variables accordingly
parse_command_line() {
    local long_opts="port:,password-file,input:,output:,test,debug,help"
    local short_opts="p:f:i:o:tdh"
    local getopt_cmd
    getopt_cmd=$(getopt -o ${short_opts} --long "${long_opts}" -q -n $(basename ${0}) -- "${@}")

    if [[ ${?} -ne 0 ]]; then
        error "Getopt failed. Unsupported script arguments present: ${@}"
        print_help
        exit_failure
    fi

    eval set -- "${getopt_cmd}"

    while true; do
        case "${1}" in
            -p|--port) SSH_PORT="${2}";;
            -f|--password-file) PASSWORD_FILE="${2}";;
            -i|--input) INPUT_LOCATION="${2}";;
            -o|--output) OUTPUT_LOCATION="${2}";;
            -t|--test) TEST_MODE="true";;
            -d|--debug) SCRIPT_DEBUG="true";;
            -h|--help) print_help; exit 0;;
            --) shift; break;;
        esac
        shift
    done
}

# init_global_variables
#
# description: Initialize global variables with default values if not set
init_global_variables() {
    [[ ! "${SSH_PORT}" ]] && SSH_PORT="22"
    [[ ! "${PASSWORD_FILE}" ]] && PASSWORD_FILE="./password-file"
    if [[ ! "${OUTPUT_LOCATION}" ]]; then
        error "Output location is not provided! Exit."
        print_help
        exit_failure
    fi
    [[ ! "${INPUT_LOCATION}" ]] && INPUT_LOCATION="$(pwd)"
    [[ ! "${SCRIPT_DEBUG}" ]] && SCRIPT_DEBUG="false"
    [[ ! "${TEST_MODE}" ]] && TEST_MODE="false"

    debug "INPUT_LOCATION: ${INPUT_LOCATION}"
    debug "OUTPUT_LOCATION: ${OUTPUT_LOCATION}"
    debug "PASSWORD_FILE: ${PASSWORD_FILE}"
    debug "SSH_PORT: ${SSH_PORT}"
}

# sync_photos
#
# description: Sync photos from the desired location to NAS
sync_photos() {
    local extra_args=

    if [[ ${TEST_MODE} == "true" ]]; then
        extra_args="--dry-run"
    fi

    local sshpass_command="sshpass"

    if [[ -f "${PASSWORD_FILE}" ]]; then
        info "Using password file: ${PASSWORD_FILE}"
        sshpass_command="${sshpass_command} -f ${PASSWORD_FILE}"
    fi

    ${sshpass_command} \
        rsync -avz \
            -e "ssh \
                -p ${SSH_PORT} \
                -T" \
            --rsync-path="/bin/rsync" \
            --human-readable \
            --update \
            --progress \
            --recursive \
            --exclude="Thumbs.db" \
            ${extra_args} \
            ${INPUT_LOCATION} \
            ${OUTPUT_LOCATION}
}

# main
#
# description: Main script function
main() {
    trap ctrl_c INT
    parse_command_line "${@}"
    init_global_variables

    if [[ ${TEST_MODE} == "true" ]]; then
        warn "Test mode! No actual changes to the files would be made."
    fi

    sync_photos && exit_success || exit_failure
}

# Script helpers

# color_text color type text
#
# description: Log messages with optional color formatting
#
# Colors:
#   0 - black
#   1 - red
#   2 - green
#   3 - yellow
#   4 - blue
#   5 - purple
#   6 - cyan
#   7 - white
# Font types:
#   0 - regular
#   1 - bold
#   2 - tint
#   3 - italic
#   4 - underline
#   5, 6 - blink
#   7 - inverted
#   8 - ??? (black)
#   9 - cross out
color_text() {
    local color="${1}"
    local type="${2}"
    local text=$(echo "${@}" | cut -d ' ' -f 3-)
    local start_color="\e[0${type};3${color}m"
    local no_color="\e[00;00m"

    echo -en "${start_color}${text}${no_color}"
}

c_green_regular() { color_text 2 0 "${@}"; }
c_red_bold() { color_text 1 1 "${@}"; }
c_red_regular() { color_text 1 0 "${@}"; }
c_white_bold() { color_text 7 1 "${@}"; }
c_white_tint() { color_text 7 2 "${@}"; }
c_white_underline() { color_text 7 4 "${@}"; }
c_yellow_bold() { color_text 3 1 "${@}"; }
c_yellow_regular() { color_text 3 0 "${@}"; }

# log message
#
# description: Log messages with timestamp
log() {
    echo -e $(date '+%H:%M:%S.%3N') "${@}"
}

# debug message
#
# description: Log debug messages if debug mode is enabled
debug() {
    if [[ "${SCRIPT_DEBUG}" == "true" ]]; then
        log $(c_white_tint "D") $(c_white_tint "${@}")
    fi
}

# info message
#
# description: Log informational messages
info() {
    log $(c_white_bold "I") "${@}"
}

# warn message
#
# description: Log warning messages
warn() {
    log $(c_yellow_bold "W") "$(c_yellow_regular ${@})"
}

# error message
#
# description: Log error messages
error() {
    log $(c_red_bold "W") "$(c_red_regular ${@})"
}

# exit_failure
#
# description: Exit the script with a failure message
exit_failure() {
    log $(c_red_regular "Script FAILED ($(date -ud @${SECONDS} +%H:%M:%S))")
    exit 1
}

# exit_success
#
# description: Exit the script with a success message
exit_success() {
    log $(c_green_regular "Script SUCCEEDED ($(date -ud @${SECONDS} +%H:%M:%S))")
    exit 0
}

# Start main
main "${@}"
