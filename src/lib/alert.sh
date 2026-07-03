# REQUIRES
# ========
# - ALERT_MAIL
# - MAIL_TO
# - MAIL_SUBJECT

function alert {
	local subject="${1}"
    local message="${2}"

	if (( ! ALERT_MAIL )); then
		return 0
	fi

	# CHECK internal deps
	for fctn in log; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	return 1
    	fi
	done

	if [[ -z "${message}" ]]; then
		log "<7> No message to alert"
		return 0
	fi

	# CHECK external deps
	for cmd in mail; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	return 1
    	fi
	done

	# CHECK vars
	for var in ALERT_MAIL MAIL_TO; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			return 1
		fi
	done

	# ALERT
	log "<6> Sending Mail-Alert to ${MAIL_TO}"

	echo -e "${message}" | \
	mail -s "${MAIL_SUBJECT} ALERT: ${subject}" "${MAIL_TO}" \
	&& log "<6> Mail-Alert sent to ${MAIL_TO}" \
	&& return 0
}