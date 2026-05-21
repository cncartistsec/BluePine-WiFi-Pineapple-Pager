# Compile instructions for Bluez bdaddr - AArch64/ARM64
The following commands were used to compile bdaddr and then copied to the BluePine lib for AArch64/ARM64 support, the file is included already compiled but you can compile it yourself if you'd like.

Compiled on Clockwork Pi CM4.  Bluez latest version downloaded from: https://www.kernel.org/pub/linux/bluetooth/


# Commands
mkdir -p ~/bluez-build && cd ~/bluez-build

wget https://www.kernel.org/pub/linux/bluetooth/bluez-5.85.tar.xz

tar -xJf bluez-5.85.tar.xz

cd bluez-5.85

sudo apt update

sudo apt install build-essential libbluetooth-dev libdbus-1-dev check wget tar

sudo apt install libglib2.0-dev libudev-dev libical-dev libreadline-dev libsystemd-dev

./configure --with-udevdir=/lib/udev --with-systemdsystemunitdir=/lib/systemd/system --with-systemduserunitdir=/usr/lib/systemd/user --enable-deprecated --enable-tools

make -j4


# After make, the bdaddr binary can be found here: 
~/bluez-build/bluez-5.85/tools
