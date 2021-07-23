#!/bin/sh

. /etc/initrd.defaults
. /etc/initrd.scripts

GK_INIT_LOG_PREFIX=${0}
if [ -n "${SSH_CLIENT_IP}" ] && [ -n "${SSH_CLIENT_PORT}" ]
then
	GK_INIT_LOG_PREFIX="${0}[${SSH_CLIENT_IP}:${SSH_CLIENT_PORT}]"
fi

if [ -f "${ZFS_ENC_ENV_FILE}" ]
then
	. "${ZFS_ENC_ENV_FILE}"
else
	bad_msg "${ZFS_ENC_ENV_FILE} does not exist! Did you boot without 'dozfs' kernel command-line parameter?"
	exit 1
fi

main() {
	if ! hash zfs >/dev/null 2>&1
	then
		bad_msg "zfs program is missing. Was initramfs built without --zfs parameter?"
		exit 1
	elif ! hash zpool >/dev/null 2>&1
	then
		bad_msg "zpool program is missing. Was initramfs built without --zfs parameter?"
		exit 1
	elif [ -z "${ROOTFSTYPE}" ]
	then
		bad_msg "Something went wrong. ROOTFSTYPE is not set!"
		exit 1
	elif [ "${ROOTFSTYPE}" != "zfs" ]
	then
		bad_msg "ROOTFSTYPE of 'zfs' required but '${ROOTFSTYPE}' detected!"
		exit 1
	elif [ -z "${REAL_ROOT}" ]
	then
		bad_msg "Something went wrong. REAL_ROOT is not set!"
		exit 1
	fi

	if [ "$(zpool list -H -o feature@encryption "${REAL_ROOT%%/*}" 2>/dev/null)" != 'active' ]
	then
		bad_msg "Root device ${REAL_ROOT} is not encrypted!"
		exit 1
	fi

	local ZFS_ENCRYPTIONROOT="$(get_zfs_property "${REAL_ROOT}" encryptionroot)"
	if [ "${ZFS_ENCRYPTIONROOT}" = '-' ]
	then
		bad_msg "Failed to determine encryptionroot for ${REAL_ROOT}!"
		exit 1
	fi

	local ZFS_KEYSTATUS=
	while true
	do
		if [ -e "${ZFS_ENC_OPENED_LOCKFILE}" ]
		then
			good_msg "${REAL_ROOT} device meanwhile was opened by someone else."
			break
		fi
		# Do we need to run our GPG command?
		# "${GPG_CMD}" zfs load-key "${ZFS_ENCRYPTIONROOT}"
		echo "gpg..."
		gpg -q -d --no-symkey-cache /keyfile.asc | zfs load-key "${ZFS_ENCRYPTIONROOT}"
		#zfs load-key "${ZFS_ENCRYPTIONROOT}"

		ZFS_KEYSTATUS="$(get_zfs_property "${REAL_ROOT}" keystatus)"
		if [ "${ZFS_KEYSTATUS}" = 'available' ]
		then
			run touch "${ZFS_ENC_OPENED_LOCKFILE}"
			good_msg "ZFS device ${REAL_ROOT} opened"
			break
		else
			bad_msg "Failed to open ZFS device ${REAL_ROOT}"

			# We need to stop here with a non-zero exit code to prevent
			# a loop when invalid keyfile was sent.
			exit 1
		fi
	done

	if [ "${ZFS_KEYSTATUS}" = 'available' ]
	then
		# Kill any running load-key prompt.
		run pkill -f "load-key" >/dev/null 2>&1
	fi
}

main

exit 0
