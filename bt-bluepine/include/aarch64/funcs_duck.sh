#!/bin/bash
# Duckyscript Switch Functions for BluePine
# Author: cncartist
# Version: 1.4
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
	
DUCKYSCRIPT_USER_CONFIRMED='y'
DUCKYSCRIPT_CANCELLED='n'
DUCKYSCRIPT_REJECTED='n'

gpsgetfunc() {
	echo "0 0 0 0"
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
	if [[ -e "$BEEP" ]] ; then
		((aplay "$BEEP" 2>/dev/null) &) > /dev/null 2>&1
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
