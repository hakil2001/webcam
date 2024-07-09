#!/bin/bash

apt update
apt full-upgrade -y

echo "dtoverlay=dwc2,dr_mode=otg" | sudo tee -a /boot/firmware/config.txt
apt -y install git meson libcamera-dev libjpeg-dev
git clone https://gitlab.freedesktop.org/camera/uvc-gadget.git
cd uvc-gadget

make uvc-gadget
cd build
meson install
ldconfig
cd ..
cd ..
echo "dwc2" | sudo tee -a /etc/modules
echo "libcomposite" | sudo tee -a /etc/modules

chmod +x usb.sh

bash mic
