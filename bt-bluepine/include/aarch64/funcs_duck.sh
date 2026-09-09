#!/bin/bash
# Duckyscript Switch Functions for BluePine with supporting GPS Functions
# Author: cncartist
# Version: 1.6
# 
# check_rfkill
# check_pygnss
# gps_collect_stop
# gps_collect_start
# gps_verify_deb
# 
# gpsgetfunc
# logfunc
# ringtonefunc
# confdialogfunc
# waitbtnfunc
# promptfunc
# alertfunc
# errdiagfunc
# textpickfunc
# numbpickfunc
# 

shopt -s expand_aliases
# blank out funcs
alias PAYLOAD_GET_CONFIG=':'
alias PAYLOAD_SET_CONFIG=':'
alias PAYLOAD_DEL_CONFIG=':'
alias LED=':'
alias DO_A_BARREL_ROLL=':'
alias GPS_GET='gpsgetfunc'
# active funcs
alias LOG='logfunc'
alias RINGTONE='ringtonefunc'
alias CONFIRMATION_DIALOG='confdialogfunc'
alias WAIT_FOR_BUTTON_PRESS='waitbtnfunc'
alias PROMPT='promptfunc'
alias ALERT='alertfunc'
alias ERROR_DIALOG='errdiagfunc'
alias NUMBER_PICKER='numbpickfunc'
alias MAC_PICKER='textpickfunc'
alias TEXT_PICKER='textpickfunc'
alias IP_PICKER='textpickfunc'
	
DUCKYSCRIPT_USER_CONFIRMED='y'
DUCKYSCRIPT_CANCELLED='n'
DUCKYSCRIPT_REJECTED='n'

# gps defaults
gps_enabled=0
gps_pid_loop=0
gps_pid_main=0
gps_fifo_pipe=""
gps_coord_cache_file=""


# check_rfkill - test for bluetooth down on system level
check_rfkill() {
	# upkeep or start
	local checktype="$1"
	local devicecurrnt="$2"
	if [[ -z "$1" ]]; then
		checktype="upkeep"
	fi
	if [[ -z "$2" ]]; then
		devicecurrnt="$BLE_IFACE"
	fi
	RF_STATUS=$(rfkill list bluetooth)
	# Check if the word "yes" appears next to blocked status
	if echo "$RF_STATUS" | grep -qE "Soft blocked: yes|Hard blocked: yes"; then
		# Attempt to restore and bring up Bluetooth
		rfkill unblock bluetooth 2>/dev/null
		sleep 1
		hciconfig "$devicecurrnt" up 2>/dev/null
		sleep 0.5
		if [[ "$checktype" == "start" ]]; then
			NEW_RF_STATUS=$(rfkill list bluetooth)
			if echo "$NEW_RF_STATUS" | grep -q "Soft blocked: yes"; then
				LOG red "WARNING: Failed to soft-unblock Bluetooth!"
			elif echo "$NEW_RF_STATUS" | grep -q "Hard blocked: yes"; then
				LOG red "WARNING: Bluetooth is HARD blocked!"
				LOG red "Please flip your physical hardware switch or use your devices Fn key."
			fi
		fi
	fi
}


# check_pygnss - Check GPS dependencies - python, pip3, and pygnssutils + pyserial
check_pygnss() {
	# check python3
	if ! command -v python3 &> /dev/null; then
		LOG "Installing python3..."
		LOG "Please wait..."
		apt install python3 -y
		LOG green "python3 Installed!"
	fi
	# check pip
	if ! command -v pip3 &> /dev/null; then
		LOG "Installing pip3..."
		LOG "Please wait..."
		apt install python3-pip -y
		LOG green "python3-pip Installed!"
	fi
	# check dependencies
	if python3 -c "import pygnssutils, serial" 2>/dev/null || python3 -m pip show pygnssutils &> /dev/null; then
		if [[ "$silent_action" -eq 0 ]] ; then LOG green "Success: pygnssutils is already installed."; fi
		# check device exists first
		gps_verify_deb
		# gps_enabled=1
		
		# if script doesn't run with serial installed, need correct serial package installed for root (pyserial)
		# 1. Uninstall the incorrect 'serial' package from root's environment
			# pip3 uninstall serial -y --break-system-packages
		# 2. Uninstall pyserial just to ensure a clean state
			# pip3 uninstall pyserial -y --break-system-packages
		# 3. Reinstall the correct 'pyserial' package 
			# pip3 install pyserial --break-system-packages
		
		# test script runs as root and regular user
			# VENV_PYTHON="python3"
			# gps_selport="/dev/ttyAMA0"
			# gps_selbaud=9600
			# gps_scriptloc="/home/admin/paybash/bt-bluepine/include/aarch64/gps_stream.py"
			# "$VENV_PYTHON" -u "$gps_scriptloc" --port "$gps_selport" --baud $gps_selbaud
		
	else
		if [[ "$silent_action" -eq 0 ]] ; then LOG "Installing pygnssutils..."; fi
		# --break-system-packages needed to access as root
		pip3 install --upgrade pygnssutils pyserial --break-system-packages &> /dev/null
		if [ $? -eq 0 ]; then
			if [[ "$silent_action" -eq 0 ]] ; then LOG green "Success: pygnssutils and dependencies installed successfully."; fi
			# check device exists first
			gps_verify_deb
			# gps_enabled=1
		else
			LOG red "Error: GPS Dependency installation failed."
			# exit 1
		fi		
	fi
}


gps_collect_stop() {
	# Central cleanup function to kill background tasks and wipe RAM files
	# Check if the tracking processes are still running before killing
	if [[ "$gps_pid_loop" -gt 0 ]] && kill -0 "$gps_pid_loop" 2>/dev/null; then
		# echo "killing gps_pid_loop: $gps_pid_loop"
		kill "$gps_pid_loop" 2>/dev/null
	# else
		# echo "gps_pid_loop: $gps_pid_loop NOT RUNNING"
	fi
	if [[ "$gps_pid_main" -gt 0 ]] && kill -0 "$gps_pid_main" 2>/dev/null; then
		# echo "killing gps_pid_main: $gps_pid_main"
		kill "$gps_pid_main" 2>/dev/null
		wait "$gps_pid_main" 2>/dev/null
	# else
		# echo "gps_pid_main: $gps_pid_main NOT RUNNING"
	fi
	gps_pid_loop=0
	gps_pid_main=0
	sudo rm -f "$gps_fifo_pipe"
	sudo rm -f "$gps_coord_cache_file"
}


gps_collect_start() {
	# check device exists first
	gps_verify_deb
	# gps_enabled=1
	if [[ "$gps_enabled" -eq 1 ]] ; then
		# Dynamically locate the Python virtual environment interpreter
		VENV_PYTHON="$PYTHONVENV_FILE/bin/python3"
		if [ ! -f "$VENV_PYTHON" ]; then
			VENV_PYTHON="python3" # Fallback to standard python if venv isn't found
		fi

		# Create a unique Named Pipe (FIFO) in RAM for the python stream
		# TEMPLATE must contain at least 3 consecutive 'X's in last component.
		# -u, --dry-run (do not create anything; merely print a name)
		gps_fifo_pipe=$(mktemp -u /tmp/gps_pipe.XXXXXX)
		mkfifo "$gps_fifo_pipe"
		# echo "gps_fifo_pipe: $gps_fifo_pipe"

		# Create a regular file in RAM to store only the *latest* single coordinate
		# This serves as a quick-lookup memory variable for your main app
		gps_coord_cache_file=$(mktemp /tmp/gps_coord.XXXXXX)
		echo "0 0" > "$gps_coord_cache_file"
		# echo "gps_coord_cache_file: $gps_coord_cache_file"

		# echo "Starting GPS tracking background process..."
		# echo "using VENV_PYTHON: $VENV_PYTHON, gps_scriptloc: $gps_scriptloc, gps_selport: $gps_selport, gps_selbaud: $gps_selbaud"

		# 1. Launch the python tracker to feed the RAM Pipe
		# stdbuf -oL "$VENV_PYTHON" -u "$gps_scriptloc" 2>/dev/null > "$gps_fifo_pipe" &
		# stdbuf -oL "$VENV_PYTHON" -u "$gps_scriptloc" --port "$gps_selport" --baud $gps_selbaud --once 2>/dev/null > "$gps_fifo_pipe" &
		stdbuf -oL "$VENV_PYTHON" -u "$gps_scriptloc" --port "$gps_selport" --baud $gps_selbaud 2>/dev/null > "$gps_fifo_pipe" &
		gps_pid_main=$!  # Save the process ID of our pipe
		# echo "gps_pid_main: $gps_pid_main"

		# 2. RUN THE ENTIRE TRACKING LOOP IN THE BACKGROUND
		# Wrapping this in ( ... ) & puts the parsing loop itself into the background
		(
			# Open the RAM Pipe safely for reading inside this subshell
			exec 3<> "$gps_fifo_pipe"
			# START_TIME=$(date +%s)
			
			while true; do
				# Stop tracking after 10 seconds pass
				# if [ $(( $(date +%s) - START_TIME )) -ge 10 ]; then break; fi

				# Read lines incoming from the pipe
				if read -t 1 -u 3 line; then
					clean_line=$(echo "$line" | tr -d '\r\n')
					if [[ ! "$clean_line" =~ ^Listening ]] && [ ! -z "$clean_line" ]; then
						# Overwrite the cache file so it only ever holds the newest single line
						echo "$clean_line" > "$gps_coord_cache_file"
					fi
				else
					# If the pipe is temporarily empty, pause slightly to prevent high CPU usage
					sleep 0.5
				fi
			done
			exec 3<&-
		) &
		gps_pid_loop=$!  # Save the process ID of our background while loop
		
		# echo "SUCCESS: The loop is tracking in the BG. Main script continues instantly!"
		# Grab it again later:
		# LATEST_POSITION=$(cat "$gps_coord_cache_file")
		# echo "Checking final GPS position: $LATEST_POSITION"
	fi
}


gps_verify_deb() {
	# LOG "Verify GPS Debian"
	if [[ -c "$gps_selport" && -r "$gps_selport" ]]; then
		gps_enabled=1
		# return 1
	else
		gps_enabled=0
		# return 0
	fi
}


gpsgetfunc() {
	# echo "gps_enabled: $gps_enabled - "
	# echo "gps_coord_cache_file: $gps_coord_cache_file - "
	if [[ "$gps_enabled" -eq 1 ]] ; then
		local gpslatlon=$(cat "$gps_coord_cache_file")
		[ -z "$gpslatlon" ] && echo "0 0 0 0" || echo "$gpslatlon 0 0"
	else
		echo "0 0 0 0"
	fi
}

logfunc() {
	local color="$1"
	local text="$2"
	local NC='\033[0m' # No Color
	local colorcode='\033[1;97m' # white default
	if [[ -n "$text" ]] ; then
		# echo "Color $color is set"
		color="${color,,}"
		case "$color" in
			"red") colorcode='\033[1;91m' ;;
			"blue") colorcode='\033[1;94m' ;;
			"cyan") colorcode='\033[1;96m' ;;
			"magenta") colorcode='\033[1;95m' ;;
			"green") colorcode='\033[1;92m' ;;
			*)
			colorcode='\033[1;97m' # white default
			;;
		esac 
		echo -e "${colorcode}${2}${NC}"
	else
		echo -e "${colorcode}${1}${NC}"
	fi
}

ringtonefunc() {
	local tone="$1"
	local BEEP=""
	tone="${tone,,}"
	case "$tone" in
		"achievement") BEEP="./include/aarch64/sounds/ScanFound.wav" ;;
		"sidebeam") BEEP="./include/aarch64/sounds/ScanNone.wav" ;;
		"glitchhack") BEEP="./include/aarch64/sounds/ScanReady.wav" ;;
		"scaletrill") BEEP="./include/aarch64/sounds/DetectNone.wav" ;;
		"warning") BEEP="./include/aarch64/sounds/DetectFound.wav" ;;
		"flutter") BEEP="./include/aarch64/sounds/Loaded.wav" ;;
		*)
		BEEP="./include/aarch64/sounds/ScanFound.wav" # default
		;;
	esac
	# echo "Tone: $tone - Beep: $BEEP";
	if [[ -e "$BEEP" ]] ; then
		# aplay does not respect volume of system, only use as fallback
		if command -v pw-play &> /dev/null; then
			# echo "YES pw-play"
			# fix for playing under root
			export XDG_RUNTIME_DIR="/run/user/1000" # 1000 is typically the first user's UID
			((pw-play "$BEEP" 2>/dev/null) &) > /dev/null 2>&1
		elif command -v aplay &> /dev/null; then
			# echo "YES aplay"
			((aplay "$BEEP" 2>/dev/null) &) > /dev/null 2>&1
		fi
	fi
}

confdialogfunc() {
	local text="$1"
	read -p "$text [y/N] " response
	if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] ; then echo "y"; else echo "n"; fi
}

waitbtnfunc() {
	local btn="$1"
	if [[ -n "$btn" ]] ; then
		if [[ "$btn" == "A" ]] ; then
			# read for enter or space
			while true; do
				IFS= read -r -s -n 1 key
				if [[ $key == "" ]]; then
					# echo "You pressed Enter"
					break
				elif [[ $key == " " ]]; then
					# echo "You pressed Space"
					break
				fi
			done
		fi
	else
		# read for enter or space or escape
		while true; do
			IFS= read -r -s -n 1 key
			if [[ $key == "" ]]; then
				# echo "You pressed Enter"
				break
			elif [[ $key == " " ]]; then
				# echo "You pressed Space"
				break
			elif [[ $key == $'\e' ]]; then
				# echo "You pressed ESC"
				break
			fi
		done
	fi
}

promptfunc() {
	local text="$1"
	local NC='\033[0m'
	local colorcode='\033[1;94m' # blue
	# echo "================================================="
	echo -e "${colorcode}=================================================${NC}"
	echo -e "${colorcode}==================== NOTICE =====================${NC}"
	echo -e "${colorcode}=================================================${NC}"
	echo -e "$1"
	echo -e "${colorcode}=================================================${NC}"
	echo "Press OK to continue..."
	waitbtnfunc
}
alertfunc() {
	local text="$1"
	local NC='\033[0m'
	local colorcode='\033[1;95m' # magenta
	echo -e "${colorcode}=================================================${NC}"
	echo -e "${colorcode}===================== ALERT =====================${NC}"
	echo -e "${colorcode}=================================================${NC}"
	echo -e "$1"
	echo -e "${colorcode}=================================================${NC}"
	echo "Press OK to confirm..."
	waitbtnfunc
}
errdiagfunc() {
	local text="$1"
	local NC='\033[0m'
	local colorcode='\033[1;91m' # red
	echo -e "${colorcode}=================================================${NC}"
	echo -e "${colorcode}===================== ERROR =====================${NC}"
	echo -e "${colorcode}=================================================${NC}"
	echo -e "$1"
	echo -e "${colorcode}=================================================${NC}"
	echo "Press OK to confirm..."
	waitbtnfunc
}

textpickfunc() {
	local text="$1"
	local value="$2"
	read -e -p "${1}: " -i "$2" output
	echo "$output"
}
numbpickfunc() {
	local text="$1"
	local value="$2"
	read -e -p "${1}: " -i "$2" output
	if [[ $output =~ ^[0-9]+$ ]]; then
		output=$((10#$output))
	fi
	echo "$output"
}
