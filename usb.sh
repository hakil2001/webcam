#!/bin/bash

echo "Creating composite mass-storage, serial, ethernet, HID, UVC, and audio..."
modprobe libcomposite

CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget"
VID="0x0525"
PID="0xa4a2"
SERIAL="0123456789"
MANUF=$(hostname)
PRODUCT="UVC Gadget"
BOARD=$(strings /proc/device-tree/model)
UDC=$(ls /sys/class/udc) # will identify the 'first' UDC

create_frame() {
	FUNCTION=$1
	WIDTH=$2
	HEIGHT=$3
	FORMAT=$4
	NAME=$5

	wdir=functions/$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p

	mkdir -p $wdir
	echo $WIDTH > $wdir/wWidth
	echo $HEIGHT > $wdir/wHeight
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	cat <<EOF > $wdir/dwFrameInterval
$6
EOF
}

create_uvc() {
	CONFIG=$1
	FUNCTION=$2

	echo "Creating UVC gadget functionality: $FUNCTION"
	mkdir functions/$FUNCTION

	create_frame $FUNCTION 640 480 uncompressed u "333333
416667
500000
666666
1000000
1333333
2000000
"
	create_frame $FUNCTION 1280 720 uncompressed u "1000000
1333333
2000000
"
	create_frame $FUNCTION 1920 1080 uncompressed u "2000000"
	create_frame $FUNCTION 640 480 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"
	create_frame $FUNCTION 1280 720 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"
	create_frame $FUNCTION 1920 1080 mjpeg m "333333
416667
500000
666666
1000000
1333333
2000000
"

	mkdir functions/$FUNCTION/streaming/header/h
	cd functions/$FUNCTION/streaming/header/h
	ln -s ../../uncompressed/u
	ln -s ../../mjpeg/m
	cd ../../class/fs
	ln -s ../../header/h
	cd ../../class/hs
	ln -s ../../header/h
	cd ../../class/ss
	ln -s ../../header/h
	cd ../../../control
	mkdir header/h
	ln -s header/h class/fs
	ln -s header/h class/ss
	cd ../../../

	mkdir -p configs/c.1/strings/0x409
	echo 250 > configs/c.1/MaxPower

	echo 2048 > functions/$FUNCTION/streaming_maxpacket

	ln -s functions/$FUNCTION configs/c.1
}

create_uac() {
	echo "Creating UAC gadget functionality"
	mkdir -p functions/uac2.usb0
	echo 48000 > functions/uac2.usb0/c_srate
	echo 48000 > functions/uac2.usb0/p_srate
	echo 2 > functions/uac2.usb0/c_ssize
	echo 2 > functions/uac2.usb0/p_ssize

	ln -s functions/uac2.usb0 configs/c.1/uac2.0
}

if [ ! -d $GADGET/g3 ]; then
	echo "Detecting platform:"
	echo "  Board: $BOARD"
	echo "  UDC: $UDC"

	echo "Creating the USB gadget"
	mkdir -p $GADGET/g3
	cd $GADGET/g3

	if [ $? -ne 0 ]; then
    	echo "Error creating USB gadget in configfs"
    	exit 1
	else
    	echo "OK"
	fi

	echo "Setting Vendor and Product IDs"
	echo $VID > idVendor
	echo $PID > idProduct
	echo "OK"

	echo "Setting English strings"
	mkdir -p strings/0x409
	echo $SERIAL > strings/0x409/serialnumber
	echo $MANUF > strings/0x409/manufacturer
	echo $PRODUCT > strings/0x409/product
	echo "OK"

	echo "Creating Config"
	mkdir configs/c.1
	mkdir configs/c.1/strings/0x409
	echo "Composite USB Gadget" > configs/c.1/strings/0x409/configuration

	echo "Creating functions..."
	create_uvc configs/c.1 uvc.0
	create_uac
	echo "OK"

	echo "Binding USB Device Controller"
	echo $UDC > UDC
	echo "OK"
fi


# Run uvc-gadget with libcamera as a source
tmux new -d 'uvc-gadget -c 0 uvc.0'
#arecord -D plughw:sndrpigooglevoi,0,0 -f S16_LE -r 44100 | aplay -D plughw:UAC2Gadget,0,0
