#!/usr/bin/env bash

set -eo pipefail

# Check for required commands
REQUIRED_COMMANDS=(whiptail ncat pv ssh du fuser tar)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' is not installed." >&2
        exit 2
    fi
done

JOBS=()
# Close background jobs on exit
function cleanup {
    echo "Cleaning up..."
    for i in "${JOBS[@]}"; do
        if ! kill "$i" 2>/dev/null; then
            echo "PID $i still alive or not found" >&2
        fi
    done
    trap - EXIT SIGINT SIGTERM
}

# check passed arguments
while getopts s:r:p:u:d:l:qh flag; do
    case "${flag}" in
        s) SOURCE_PATH=${OPTARG};;
        r) RECEIVER=${OPTARG};;
        p) PORT=${OPTARG};;
        u) USERNAME=${OPTARG};;
        d) DESTINATION_PATH=${OPTARG};;
        l) RATE_LIMIT=${OPTARG};;
        q) BE_QUIET=true;;
        h) echo "Usage : $(basename "$0") -s path_to_data_dir -r receiver_host -p port_number -u user_name_for_receiver_host -d destination_path -l rate_limit -q" >&2; exit 0;;
        '*') echo "Invalid flag: ${flag}" >&2; echo "Help : $(basename "$0") -h" >&2; exit 6;;
        '?') ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.
if [ $# -ne 0 ]; then
    echo "Invalid arguments: $*" >&2
    echo "Usage : $(basename "$0") -s path_to_data_dir -r receiver_host -p port_number -u user_name_for_receiver_host -d destination_path -l rate_limit -q" >&2
    exit 6
fi

# Check if SOURCE_PATH is empty and BE_QUIET is not passed as an argument
if [ -z "${SOURCE_PATH}" ] && [ -z "${BE_QUIET}" ]; then
    # By default whiptail passes the input entered to the standard error console, and in a usual shell we will be able see the entered text on the terminal after we exit from the whiptail window.
    # But if we want to use the entered input by storing it in some variable, we will have to go about a few manipulations as there is no direct way of doing it in whiptail.
    SOURCE_PATH=$(whiptail --inputbox "Directory path to transfer?" 9 69 /data --title "Enter path" 3>&1 1>&2 2>&3)
fi

# Check if SOURCE_PATH is still empty
if [ -z "${SOURCE_PATH}" ]; then
    echo "No path to data provided."
    exit 11
fi

# Check if path exists
if [ ! -d "${SOURCE_PATH}" ]; then
    echo "The path ${SOURCE_PATH} does not exist."
    exit 13
fi

# Check if RECEIVER is empty and BE_QUIET is not passed as an argument
if [ -z "${RECEIVER}" ] && [ -z "${BE_QUIET}" ]; then
    RECEIVER=$(whiptail --inputbox "Receiver address?" 9 69 192.168.0.2 --title "Enter receiver" 3>&1 1>&2 2>&3)
fi

# Check if RECEIVER is still empty
if [ -z "${RECEIVER}" ]; then
    echo "No receiver address provided."
    exit 21
fi

# Check if USERNAME is empty and BE_QUIET is not passed as an argument
if [ -z "${USERNAME}" ] && [ -z "${BE_QUIET}" ]; then
    USERNAME=$(whiptail --inputbox "Enter Username?" 9 69 ${USER} --title "${RECEIVER}" 3>&1 1>&2 2>&3)
fi

# Check if USERNAME is still empty
if [ -z "${USERNAME}" ]; then
    echo "No username provided."
    exit 31
fi

# Check if DESTINATION_PATH is empty and BE_QUIET is not passed as an argument
if [ -z "${DESTINATION_PATH}" ] && [ -z "${BE_QUIET}" ]; then
    DESTINATION_PATH=$(whiptail --inputbox "Destination path?" 9 69 /data --title "Enter destination path on the receiver" 3>&1 1>&2 2>&3)
fi

# Check if DESTINATION_PATH is still empty
if [ -z "${DESTINATION_PATH}" ]; then
    echo "No destination path provided."
    exit 41
fi

# Check if PORT is empty and BE_QUIET is not passed as an argument
if [ -z "${PORT}" ] && [ -z "${BE_QUIET}" ]; then
    PORT=$(whiptail --inputbox "Port number?" 9 69 12345 --title "Enter port" 3>&1 1>&2 2>&3)
fi

# Check if PORT is still empty
if [ -z "${PORT}" ]; then
    echo "No port number provided."
    exit 51
fi

# Validate port number
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1024 ] || [ "${PORT}" -gt 65535 ]; then
    echo "Invalid port number: ${PORT}. Must be between 1024-65535."
    exit 52
fi

# Check if RATE_LIMIT is empty and BE_QUIET is not passed as an argument
if [ -z "${RATE_LIMIT}" ] && [ -z "${BE_QUIET}" ]; then
    RATE_LIMIT=$(whiptail --inputbox "Speed Limit?" 9 69 1G --title "Maximum transfer speed" 3>&1 1>&2 2>&3)
fi

# Check if RATE_LIMIT is still empty
if [ -z "${RATE_LIMIT}" ]; then
    echo "No speed limit provided. Defaulting to 80M (Megabytes/second)."
    RATE_LIMIT="80M"
fi

# Validate rate limit format (pv accepts: K, M, G, T with optional suffix)
if ! [[ "${RATE_LIMIT}" =~ ^[0-9]+[KMGT]?[B]?$ ]]; then
    echo "Invalid rate limit format: ${RATE_LIMIT}. Use format like: 100M, 1G, 500K, etc."
    exit 53
fi

# extract base dir from path
PARENT_DIR=$(dirname "${SOURCE_PATH}")

# Check if there is no ssh connectivity
if ! ssh -l "${USERNAME}" -o BatchMode=yes -o ConnectTimeout=5 "${RECEIVER}" true &>/dev/null; then
    echo "SSH not available"
    SSH_AVAILABLE=false
else
    echo "SSH available"
    SSH_AVAILABLE=true
fi

if [ "${SSH_AVAILABLE}" = "true" ]; then
    # Check if DESTINATION_PATH exists on the RECEIVER
    if ! ssh "${USERNAME}@${RECEIVER}" -o BatchMode=yes -o ConnectTimeout=5 "test -d $(printf '%q' "$DESTINATION_PATH")"; then
        # Create destination directory on the receiver
        if ! ssh "${USERNAME}@${RECEIVER}" -o BatchMode=yes -o ConnectTimeout=5 "mkdir -p $(printf '%q' "$DESTINATION_PATH")"; then
            echo "ERROR: Can not create directory ${DESTINATION_PATH} on ${USERNAME}@${RECEIVER}"
            exit 73
        fi
        echo "Destination directory created"
    fi
    # Start netcat listener
    ssh "${USERNAME}@${RECEIVER}" -o BatchMode=yes -o ConnectTimeout=5 "/usr/bin/ncat -l -p ${PORT} < /dev/null | tar --sparse --extract --directory ${DESTINATION_PATH}" < /dev/null &
    
    JOBS=($!)
    trap cleanup EXIT SIGINT SIGTERM

    
fi

# Connect to the receiver and check if the /usr/bin/ncat is running in a while loop
TIMEOUT=10
while [ "$(ssh "${USERNAME}@${RECEIVER}" -o BatchMode=yes "fuser ${PORT}/tcp 2>/dev/null")" = "" ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT - 1))
    if [ $TIMEOUT -lt 1 ]; then
        whiptail --title "Start receiver" --msgbox "Manually execute the following command on the receiving node:\n/usr/bin/ncat -l -p ${PORT} | tar --sparse --extract --directory ${DESTINATION_PATH}" 9 78
        if ! whiptail --title "Confirm" --yesno "Is the receiver running?" 9 78; then
            echo "Exiting..."
            exit 1
        fi
        break
    fi
    echo "Attempts left: ${TIMEOUT}"
done

# Get size
SZ=$(du -bsc "${SOURCE_PATH}" | tail -n1 | cut -f 1)

# Get data basename
SOURCE_PATH_DIR=$(basename "${SOURCE_PATH}")

echo "Starting transfer of ${SOURCE_PATH} ---------------> ${RECEIVER}:${PORT} ${DESTINATION_PATH}"
# start transfer
if ! tar --sparse --directory "$PARENT_DIR" --create "${SOURCE_PATH_DIR}" | pv --progress --eta --timer --rate --bytes --cursor --size "$SZ" --force --name Transferring -L "${RATE_LIMIT}" | /usr/bin/ncat "${RECEIVER}" "${PORT}"; then
    echo "ERROR: Transfer failed." >&2
    exit 74
fi
