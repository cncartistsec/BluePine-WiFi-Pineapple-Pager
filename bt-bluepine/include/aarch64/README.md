# BluePine Files for AArch64/ARM64/Debian Bash Support
This "aarch64" folder can be deleted if only using BluePine on the WiFi Pineapple Pager, but is required to run BluePine on AArch64/ARM64/Debian Bash.  

The only items missing in the AArch64 conversion are LED color changes (native to pager) and GPS integration.  Tested on ClockworkPi (Trixie) & Hackberry (Kali) and should work on other Raspberry Pi based systems.


# Custom Desktop Shortcut + Icon
Available in "desktop" folder with instructions.


# Bluetooth Notes
On the Pager, only CSR Bluetooth MAC address changing is available and supported here for AArch64/ARM64.

If USB/external hci1 adapter is not seen, ensure Bluetooth adapter is enabled by turning off Bluetooth and back on via desktop taskbar.

If you have a mouse or keyboard hooked up to the Bluetooth adapter you are scanning with, you will very briefly lose connectivity while the adapter is performing resets, and it will reconnect immediately afterwards.
