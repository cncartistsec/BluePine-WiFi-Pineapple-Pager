
# Node Support / Pine Needles:
-- Nodes provide extra support data for Bluetooth scans.

-- Nodes widen Bluetooth coverage, reveal more devices per scan, and detect AirTags and Meshtastic/MeshCore.

-- Nodes currently tested running on XIAO_ESP32-C5's.




# Node Support / Pine Needles:
-- Nodes running on XIAO_ESP32-C5's

-- -- - Nodes connect to the Pager Mgmt AP for Pager, Hotspot for Debian/AArch64

-- Pager Mgmt AP + Hotspot for Debian can be enabled at: "Preferences > Manage Pine Needles"

-- -- - Hotspot Interface (wlan0, wlan1, etc) can be selected at: "Preferences > Manage Pine Needles > Select Hotspot Interface"

-- Node Network is setup at: "Preferences > Manage Pine Needles"

-- To configure each Node:

-- -- - 1. Power on and flash Node Firmware via esptool, flash download tool, or similar flashing utility.

-- -- - You may have to hold boot button while connecting USB-C power and release after to enable boot/flashing mode.

-- -- - Flash Params: SPI SPEED: 40MHz (or 80MHz), SPI MODE: DIO, DoNotChgBin: Checked, BAUD: 921600 (or 460800)

-- -- - 2. Connect to AP "PineNeedle-Cfg", PW "MyNeedleNetwork", and go to "http://192.168.4.1" to configure the Node.

-- -- - Make sure to configure one Node at a time.

-- -- - They all use the same default AP Name and after configuration the credentials will be saved to the Node.

-- -- - 3. Save and Node will reboot and try to connect to Node Network Configured.

-- -- - If credentials fail after 45 seconds, Node will reboot into AP/Configuration mode again.

-- -- - When powered on Nodes try to connect for 45 seconds and if connection fails, the Node enters AP/Configuration mode 
