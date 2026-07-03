# REQUIRES
# ========
# - ALERT_MAIL
# - MAIL_TO
# - MAIL_SUBJECT

function alert {
	local subject="${1}"
    local message="${2}"

	if (( ALERT_MAIL )); then

		if [[ -z "${MAIL_TO}" ]]; then
			log "<3> Required var not set: MAIL_TO"
			return 1
		else
			log "<6> Sending Mail-Alert to ${MAIL_TO}"

			echo -e "${message}" | \
			mail -s "${MAIL_SUBJECT} ALERT: ${subject}" "${MAIL_TO}" \
			&& log "<6> Mail-Alert sent to ${MAIL_TO}" \
			&& return 0
		fi
	fi
}