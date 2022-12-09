#!/bin/bash
#
# 自动重启操作系统 x 次
# 版权 2022 lixc@zoyatek.com.cn

# 一些变量定义
WAITING_TIME=30
TEMP_FILE_DIR=/opt/temp
LOG_FILE_DIR=/opt/logs
CURRENT_NUMBER_FILE=${TEMP_FILE_DIR}/current_number
MAX_NUMBER_FILE=${TEMP_FILE_DIR}/max_number
TEST_SUCCESS_FLAG=${TEMP_FILE_DIR}/test_success
LOG_FILE_NAME_FLAG=${TEMP_FILE_DIR}/log_file_name_flag

SERVICE_SCRIPT=${PWD}/reboot_test.service
SCRIPT_NAME=$0

function show_usage() {
    echo -e "\e[0;33mPlease specify the number of reboot when you first run !\e[0m"
    echo -e "\e[0;32m    Usage: $0 50 \e[0m"
    exit 0
}

function get_log_file_name() {
    mkdir -p "${LOG_FILE_DIR}"
    if [[ -s ${LOG_FILE_NAME_FLAG} ]]; then
        LOG_FILE_NAME="$(cat "${LOG_FILE_NAME_FLAG}")"
    else
        LOG_FILE_NAME="${LOG_FILE_DIR}/reboot-test-log-$(date +%Y%m%d%H%M)"
        echo "${LOG_FILE_NAME}" > "${LOG_FILE_NAME_FLAG}"
    fi
}

function quit_test() {
    echo "$(date +"%F %T"): Quit the reboot test . " >> "${LOG_FILE_NAME}"
    \rm -f "${MAX_NUMBER_FILE}" "${CURRENT_NUMBER_FILE}" "${TEST_SUCCESS_FLAG}" "${LOG_FILE_NAME_FLAG}"
    \rm -f /usr/bin/reboot_test.bash
    systemctl disable reboot_test
    \rm -f /lib/systemd/system/reboot_test.service
    exit 0
}

function init_test() {
    echo "$(date +"%F %T"): Initialize the reboot test . " >> "${LOG_FILE_NAME}"
    mkdir -p "${TEMP_FILE_DIR}"
    echo "$1" > "${MAX_NUMBER_FILE}"
    echo 0 > "${CURRENT_NUMBER_FILE}"
    \cp -rf "${SCRIPT_NAME}" /usr/bin/reboot_test.bash
    \cp -rf "${SERVICE_SCRIPT}" /lib/systemd/system/reboot_test.service
    systemctl daemon-reload
    systemctl enable reboot_test.service
}

function do_reboot() {
    sleep ${WAITING_TIME}
    echo "$1" > "${CURRENT_NUMBER_FILE}"
    echo "$(date +"%F %T"): This is the $1th reboot test." >> "${LOG_FILE_NAME}"

    # 重启设备
    systemctl reboot
}

function assert_success() {
    touch "${TEST_SUCCESS_FLAG}"
    echo "$(date +"%F %T"): Reboot test $1 times successfully." >> "${LOG_FILE_NAME}"
    quit_test
}

function main() {
    # 执行测试需要用户有root权限
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\e[0;31mYou must have root permission!\e[0m"
        exit 1
    fi

    if [[ ! -f ${MAX_NUMBER_FILE} ]]; then
        if [[ $# -eq 0 ]]; then
            show_usage
        else
            local REBOOT_TIMES="$1"
        fi
    fi

    get_log_file_name

    if [[ -f ${TEST_SUCCESS_FLAG} ]]; then
        quit_test
    fi

    if [[ ! -f ${CURRENT_NUMBER_FILE} ]]; then
        init_test "${REBOOT_TIMES}"
    fi

    local CURRENT_NUMBER
    CURRENT_NUMBER=$(($(cat "${CURRENT_NUMBER_FILE}") + 1))
    local MAX_NUMBER
    MAX_NUMBER=$(cat "${MAX_NUMBER_FILE}")

    if [[ ${CURRENT_NUMBER} -le ${MAX_NUMBER} ]]; then
        do_reboot "${CURRENT_NUMBER}"
    else
        assert_success "${MAX_NUMBER}"
    fi
}

main "$@"
