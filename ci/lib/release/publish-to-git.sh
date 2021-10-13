#!/bin/bash
set -o nounset -o pipefail -o errexit

# full path to dir of current script
SCRIPT_DIR=$(readlink -e $(dirname ${BASH_SOURCE[0]}))

# full path to root of PF sources
PF_SRC_DIR=$(echo ${SCRIPT_DIR} | grep -oP '.*?(?=\/ci\/)')

# path to all functions
FUNCTIONS_FILE=${PF_SRC_DIR}/ci/lib/common/functions.sh

source ${FUNCTIONS_FILE}

configure_and_check() {
    CI_PIPELINE_ID=${CI_PIPELINE_ID:-}
    GIT_USER_NAME=${GIT_USER_NAME:-John Doe}
    GIT_USER_MAIL=${GIT_USER_MAIL:-johndoe@example.com}
    GIT_USER_PASSWORD=${GIT_USER_PASSWORD:-secret}
    GIT_REPO=${GIT_REPO:-git.example.com/user/repo.git}
    GIT_CLONE_METHOD=${GIT_CLONE_METHOD:-https://}
    GIT_LOCAL_PATH=$(mktemp -d)

    GIT_REPO_URL=${GIT_CLONE_METHOD}${GIT_USER_NAME}:${GIT_USER_PASSWORD}@${GIT_REPO}
    
    generate_git_config
    #declare -p RESULT_DIR PF_MINOR_RELEASE BRANCH_TYPE
}

generate_git_config() {
    git config --global user.name "${GIT_USER_NAME}"
    git config --global user.email "${GIT_USER_MAIL}"
    # to store credentials in memory for a short period of time
    git config credential.helper cache
}

clone_git_repository() {
    git clone ${GIT_REPO_URL} ${GIT_LOCAL_PATH}
}

update_git_repository() {
    local src_file="${PF_SRC_DIR}/$1"
    local dst_file="${GIT_LOCAL_PATH}/$2"
    declare -p ${src_file} ${dst_file}
    
    cp -v ${src_file} ${dst_file}
    git -C ${GIT_LOCAL_PATH} commit -am "Automatic update by pipeline ${CI_PIPELINE_ID}"
    #git -C ${GIT_LOCAL_PATH} push
}

log_section "Configure and check"
configure_and_check

clone_git_repository
update_git_repository $1 $2
