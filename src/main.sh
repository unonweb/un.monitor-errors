#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

# IMPORTS
source "${SCRIPT_DIR}/lib/alert.sh"
source "${SCRIPT_DIR}/lib/log.sh"

function main {

	# CHECK root
	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r "${PATH_CONFIG}" ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# CHECK internal dependencies
	for fctn in log alert; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	exit 1
    	fi
	done
	
	# CHECK external dependencies
	for cmd in mail; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	exit 1
    	fi
	done

	# CHECK vars
	for var in STATE_DIR JOURNAL_PRIORITY; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			exit 1
		fi
	done

	# VARS
	local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	local alert_msg=""
	local cursor_file="${STATE_DIR}/journal_cursor.txt"
	local last_alert_msg_file="${STATE_DIR}/last_alert.txt"
	local last_alert_timestamp_file="${STATE_DIR}/last_alert_timestamp.txt"
	local last_alert_timestamp

	# DEBUG
	log "<7> Using PATH_CONFIG: ${PATH_CONFIG}"
	log "<7> Using STATE_DIR: ${STATE_DIR}"
	log "<7> Using cursor_file: ${cursor_file}"

	# MKDIR
	mkdir -p "${STATE_DIR}"

	# last_alert_timestamp
	if [[ -f "${last_alert_timestamp_file}" ]]; then
		last_alert_timestamp=$(cat "${last_alert_timestamp_file}")
	else
		last_alert_timestamp="start of records"
	fi

	# JOURNALCTL
	while read -r line; do
		[[ -z "${line}" ]] && continue
		[[ "${line}" =~ .*"-- No entries --".* ]] && continue

		# CHECK ignore
		local ignore=false
		for pattern in "${IGNORE_MESSAGES[@]}"; do
			if echo "${line}" | grep --extended-regexp --quiet "${pattern}"; then
				# --extended-regexp
				# allows the use of wildcards like .*
				ignore=true
				break # Exit the pattern loop early if a match is found
			fi
		done
		
		# Skip this log line entirely if it matched any ignore pattern
		if [[ "${ignore}" == "true" ]]; then
			continue
		else
			alert_msg+="${line}\n"
		fi
	done < <(journalctl --cursor-file=${cursor_file} --priority "${JOURNAL_PRIORITY}")
	# --cursor-file=FILE
	# If FILE exists and contains a cursor, start showing entries after this location. 
	# Otherwise, show entries according to the other given options. 
	# At the end, write the cursor of the last entry to FILE. 
	# Use this option to continually read the journal by sequentially calling journalctl

	# ALERT & LOG
	if [[ -n "${alert_msg}" ]]; then
		
		local num_lines=$(echo -e "${alert_msg}" | wc --lines)
		local alert_msg_header=""
		alert_msg_header+="HOST: 			$(hostname)\n"
		alert_msg_header+="ERROR PRIORITY: 	${JOURNAL_PRIORITY}\n"
		alert_msg_header+="ALERT: 			${num_lines} new errors since ${last_alert_timestamp}\n\n"

		log "<5> Got ${num_lines} of alert messages"
		alert "${num_lines} new errors" "${alert_msg_header}${alert_msg}"

		log "<6> Writing alert to file: ${last_alert_msg_file}"
		echo -e "${alert_msg}" > "${last_alert_msg_file}"
		echo -e "${timestamp}" > "${last_alert_timestamp_file}"
	else
		log "<6> No new errors found since ${last_alert_timestamp} with priority ${JOURNAL_PRIORITY}"
	fi
}

main