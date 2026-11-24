#!/usr/bin/env bash
#
# Lab toolbox. `lab init` configures both fresh routers for the lab, then exits.
# `lab ros` runs RouterOS commands over SSH, `lab script` loads a script.

set -Eeuo pipefail
shopt -s inherit_errexit

readonly ROUTERS=(routeros7 routeros6)
readonly ROS_USER='admin'
readonly ROS_PASSWORD='admin'
readonly BOOT_TIMEOUT=900
readonly SCRIPT_NAME='BackupAndUpdate'
readonly SSH=(sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

log_prefix=''

log() {
  printf 'lab: %s%s\n' "${log_prefix}" "$*" >&2
}

trap 'log "error: command failed at line ${LINENO}"' ERR

# Usage: ssh_as PASSWORD HOST [COMMAND...]
ssh_as() {
  local password="$1" host="$2"
  shift 2
  SSHPASS="${password}" "${SSH[@]}" "${ROS_USER}@${host}" "$@"
}

# Runs a RouterOS command, or opens a session without one.
# Usage: ros HOST [COMMAND...]
ros() {
  ssh_as "${ROS_PASSWORD}" "$@"
}

# While admin's password is empty, RouterOS accepts any password, so this works
# before and after the password is set. timeout covers SSH stalling during boot.
wait_boot() {
  local host="$1" deadline=$((SECONDS + BOOT_TIMEOUT))
  until [[ "$(timeout 30 lab ros "${host}" ':put ok' 2>/dev/null)" == *ok* ]]; do
    if ((SECONDS >= deadline)); then
      log "error: no SSH answer within ${BOOT_TIMEOUT}s"
      return 1
    fi
    sleep 2
  done
}

# On v6 this also clears the "password expired" flag, which otherwise turns the
# first terminal login into a "Change your password" prompt.
set_password() {
  local host="$1" status=0
  ros "${host}" ":do { /password old-password=\"\" new-password=\"${ROS_PASSWORD}\" confirm-new-password=\"${ROS_PASSWORD}\" } on-error={}" >/dev/null
  # Only a rejected wrong password proves the password is set. sshpass exits 5 on that.
  ssh_as wrong-password "${host}" ':put ok' >/dev/null 2>&1 || status=$?
  if ((status != 5)); then
    log "error: a wrong password was not rejected (sshpass exit ${status})"
    return 1
  fi
}

configure_router() {
  local host="$1" version addr tls got
  version="$(ros "${host}" ':put [/system resource get version]')"
  version="${version//$'\r'/}"
  # v6 rejects the v7 parameter names at parse time, so pick them here.
  case "${version}" in
    7.*) addr=server tls=tls ;;
    6.*) addr=address tls=start-tls ;;
    *)
      log "error: unexpected RouterOS version '${version}'"
      return 1
      ;;
  esac
  # target=disk keeps the log across reboots, such as the one in an OS update cycle.
  ros "${host}" "/tool e-mail set ${addr}=mailpit port=1025 from=routeros@lab.test ${tls}=no;
    /system logging action set memory target=disk"
  # RouterOS SSH exits 0 even when a command fails, so read the settings back.
  got="$(ros "${host}" ":put ([/tool e-mail get ${addr}] . \" \" . [/system logging action get memory target])")"
  got="${got//$'\r'/}"
  if [[ "${got}" != 'mailpit disk' ]]; then
    log "error: settings not applied, ${addr} and log target read back as '${got}'"
    return 1
  fi
  log "RouterOS ${version}: e-mail goes to mailpit:1025, log is kept on disk"
}

# The first interactive login asks "Do you want to see the software license?".
# RouterOS remembers the answer, so give it here and `make ssh` goes straight
# to the prompt.
answer_license_prompt() {
  # shellcheck disable=SC2016 # $env(HOST) is expanded by expect.
  HOST="$1" expect -c '
    set timeout 30
    log_user 0
    spawn lab ros $env(HOST)
    expect {
      -ex "Y/n" { send "n"; exp_continue }
      -ex "admin@" { send "/quit\r" }
      timeout { exit 1 }
    }
    expect eof
  '
  log "license prompt answered"
}

setup_router() {
  local host="$1"
  log_prefix="${host}: "
  log "waiting for RouterOS"
  wait_boot "${host}"
  set_password "${host}"
  configure_router "${host}"
  answer_license_prompt "${host}"
}

init() {
  local host pid failed=0
  local -a pids=()
  for host in "${ROUTERS[@]}"; do
    setup_router "${host}" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    wait "${pid}" || failed=1
  done
  if ((failed)); then
    log "error: a router was not configured"
    exit 1
  fi
}

# Replaces the script with the source read from stdin.
# Usage: load_script HOST
load_script() {
  local host="$1" input escaped want got
  input="$(cat)"
  want="$(wc -l <<<"${input}")"
  # Escape for a RouterOS string literal and keep one line per source line, so
  # error line numbers match the file.
  escaped="$(jq -Rrs 'gsub("\r"; "") | gsub("(?<c>[\\\\\"$?])"; "\\\(.c)") | gsub("\n"; "\\n")' <<<"${input}")"
  ros "${host}" "/system script remove [find name=${SCRIPT_NAME}];
    /system script add name=${SCRIPT_NAME} source=\"${escaped}\""
  # :put adds a line break after the source's own last one.
  got="$(($(ros "${host}" ":put [/system script get [find name=${SCRIPT_NAME}] source]" | wc -l) - 1))"
  if ((got != want)); then
    log "error: ${SCRIPT_NAME} on ${host} has ${got} lines, expected ${want}"
    exit 1
  fi
  log "${SCRIPT_NAME} loaded into ${host}, ${got} lines"
}

case "${1:-}" in
  init)
    init
    ;;
  ros)
    # exec, so Ctrl+C, docker stop and timeout reach ssh. bash as PID 1 would ignore them.
    SSHPASS="${ROS_PASSWORD}" exec "${SSH[@]}" "${ROS_USER}@${2:?usage: lab ros HOST [COMMAND]}" "${@:3}"
    ;;
  script)
    load_script "${2:?usage: lab script HOST}"
    ;;
  *)
    log "usage: lab init | lab ros HOST [COMMAND] | lab script HOST <SOURCE"
    exit 64
    ;;
esac
