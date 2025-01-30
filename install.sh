#!/usr/bin/env bash

set -euo pipefail

NORMAL="\e[0m"
ERROR="\e[31m"
SUCCESS="\e[32m"
WARNING="\e[33m"
PRIMARY="\e[34m"

exit_error() {
    echo -e "${ERROR}ERROR:${NORMAL} $1" >&2
    exit 1
}

exit_success() {
    echo -e "${SUCCESS}SUCCESS:${NORMAL} $1"
    exit 0
}

exit_warning() {
    echo -e "${WARNING}WARNING:${NORMAL} $1" >&2
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    exit_warning "This script must be run as root."
fi

if [[ ! -f "/etc/os-release" ]]; then
    exit_warning "File /etc/os-release not found."
fi

if [[ ! -r "/etc/os-release" ]]; then
    exit_warning "File /etc/os-release not readable."
fi

check_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        exit_warning "Command '$cmd' not found. Please install it and retry."
    fi
}

check_cmd "curl"
check_cmd "gpg"
check_cmd "apt-get"

run_cmd() {
    local action="$1"
    shift

    local error="$1"
    shift

    echo -en "${PRIMARY}ACTION:${NORMAL} $action"

    set +e
    local output
    output=$("$@" 2>&1)
    local status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo -e "${SUCCESS}DONE${NORMAL}"
    else
        echo
        echo "$output"
        exit_error "$error"
    fi
}

source "/etc/os-release"

ARCH=$(dpkg --print-architecture)
PKG_NAME="terraform"
REP_NAME="hashicorp"
GPG_LINK="https://apt.releases.hashicorp.com/gpg"
GPG_PATH="/usr/share/keyrings/$REP_NAME.gpg"
REP_LINK="https://apt.releases.hashicorp.com"
REP_PATH="/etc/apt/sources.list.d/$REP_NAME.list"
REP_INFO="deb [arch=$ARCH signed-by=$GPG_PATH] $REP_LINK $VERSION_CODENAME main"

run_cmd "Downloading $REP_NAME key... " \
    "Failed to download $REP_NAME key." \
    curl -fsLS "$GPG_LINK" -o "/tmp/$REP_NAME"

run_cmd "Installing $REP_NAME key... " \
    "Failed to install $REP_NAME key." \
    gpg --dearmor --yes -o "$GPG_PATH" "/tmp/$REP_NAME"

run_cmd "Removing $REP_NAME key... " \
    "Failed to remove $REP_NAME key." \
    rm -f "/tmp/$REP_NAME"

run_cmd "Adding $REP_NAME repository... " \
    "Failed to add $REP_NAME repository." \
    bash -c "echo $REP_INFO | tee $REP_PATH >/dev/null"

run_cmd "Updating package list... " \
    "Failed to update package list." \
    apt-get update -qq

run_cmd "Installing $PKG_NAME... " \
    "Failed to install $PKG_NAME." \
    apt-get install -qq "$PKG_NAME"

exit_success "$PKG_NAME has been installed successfully."
