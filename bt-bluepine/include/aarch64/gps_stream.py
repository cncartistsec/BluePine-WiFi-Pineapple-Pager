# Python GPS Streamer
# by cncartist
#
# Built for BluePine ClockworkPi uConsole GPS Implementation
#
# To Run:
# python3 gps_stream.py
# OR
# python3 gps_stream.py -p /dev/ttyAMA0
# OR 
# python3 gps_stream.py -p /dev/ttyAMA0 -b 115200
# OR
# python3 gps_stream.py --once
#

import argparse
import sys
import time
import logging
import serial
from pygnssutils import GNSSReader, GNSSStreamError

# Force the internal library loggers to be completely silent
logging.getLogger("pygnssutils").setLevel(logging.CRITICAL)
logging.getLogger("pynmeagps").setLevel(logging.CRITICAL)
logging.getLogger("pyubx2").setLevel(logging.CRITICAL)

# Configure command-line argument parsing
parser = argparse.ArgumentParser(description="GPS coordinate streamer via CLI.")
parser.add_argument("-p", "--port", type=str, default="/dev/ttyAMA0", help="The serial port device path (default: /dev/ttyAMA0)")
parser.add_argument("-b", "--baud", type=int, default=9600, help="Serial baud rate (default: 9600)")
parser.add_argument("--once", action="store_true", help="Enable single-shot mode to exit after finding first coordinates")
args = parser.parse_args()

# Setup execution modes based on parsed inputs
port_path = args.port
baud_rate = args.baud
# Check if any command-line argument was passed to the script
# single_shot_mode = len(sys.argv) > 1
single_shot_mode = args.once

# Max seconds to wait for a valid coordinate in single-shot mode before failing
SINGLE_SHOT_TIMEOUT = 3.0

# Establish serial connection
# stream = serial.Serial("/dev/ttyAMA0", baudrate=9600, timeout=1.0)
# Establish serial connection using the dynamic port argument
try:
    stream = serial.Serial(port_path, baudrate=baud_rate, timeout=1.0)
except Exception as e:
    print(f"Error opening serial port {port_path} at {baud_rate} baud: {e}", file=sys.stderr)
    sys.exit(1)

reader = GNSSReader(stream)

if not single_shot_mode:
    print(f"Listening for GPS coordinates on {port_path} ({baud_rate} baud)...")

# Flush old, fragmented bytes out of the kernel buffer before parsing starts
stream.reset_input_buffer()

start_time = time.time()
found_coordinate = False
# Counter to keep track of empty sentences
empty_sentence_count = 0

try:
    while True:
        # Check overall script runtime if we are hunting for a single point
        if single_shot_mode and (time.time() - start_time) > SINGLE_SHOT_TIMEOUT:
            break

        # Check if bytes are sitting in the serial buffer to prevent blocking
        if stream.in_waiting == 0:
            time.sleep(0.1)
            continue

        try:
            # Read and parse a single sentence packet from the stream safely
            raw_data, parsed_data = reader.read()
        except (GNSSStreamError, Exception):
            # Catch and skip corrupted headers, fragmented bytes, or protocol noise
            continue

        # Safely determine the message type/sentence identity (e.g., GNGGA, GNRMC)
        msg_type = "UNKNOWN"
        if parsed_data:
            if hasattr(parsed_data, "identity"):
                msg_type = parsed_data.identity
            elif hasattr(parsed_data, "msgID"):
                msg_type = parsed_data.msgID

        # Check if the sentence has valid coordinates
        if parsed_data and hasattr(parsed_data, "lat") and parsed_data.lat:
            # print(f"[{msg_type}] Lat: {parsed_data.lat}, Lon: {parsed_data.lon}")
            print(f"{parsed_data.lat} {parsed_data.lon}")
            found_coordinate = True
            empty_sentence_count = 0 # Reset the counter after successful coordinate
            
            if single_shot_mode:
                break
        else:
            # Continuous streaming prints 0 0 for empty system sentences
            if not single_shot_mode and parsed_data:
                empty_sentence_count += 1
                # Only print "0 0" after XX consecutive empty packets
                if empty_sentence_count >= 45:
                    # print(f"[{msg_type}] 0 0")
                    print("0 0")
                    empty_sentence_count = 0 # Reset counter after printing

except KeyboardInterrupt:
    if not single_shot_mode:
        print("\nStreaming stopped.")
finally:
    # Final check for single shot mode execution
    if single_shot_mode and not found_coordinate:
        # print("[TIMEOUT] 0 0")
        print("0 0")

    stream.close()
