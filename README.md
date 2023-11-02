# 8311 WAS-110 Firmware Builder

## custom fwenvs
```
8311_fix_vlans=1
8311_internet_vlan=0
8311_services_vlan=36

8311_ipaddr=192.168.11.1
8311_netmask=255.255.255.0
8311_gateway=192.168.11.254

8311_console_en=1
8311_ethtool_speed=speed 2500 autoneg off duplex full
8311_failsafe_delay=30
8311_root_pwhash=$1$BghTQV7M$ZhWWiCgQptC1hpUdIfa0e.

8311_equipment_id=5690
8311_gpon_sn=SMBSXXXXXXXX
8311_hw_ver=Fast5689EBell
8311_mib_file=/etc/mibs/prx300_1V.ini
8311_sw_verA=SGC830007C
8311_sw_verB=SGC830006E
8311_vendor_id=SMBS
```

## custom uci settings
`uci -qc /ptconf/8311 show`  
```
dropbear.rsa_key=key
dropbear.rsa_key.value='BASE64 of the RSA server key'
dropbear.public_key=key
dropbear.public_key.value='ssh-rsa public key' 
```

## Scripts

### build.sh
Tool for building new modded WAS-110 firmware images
```
Usage: ./build.sh [options]

Options:
-i --image <filename>           Specify stock local upgrade image file.
-I --image-dir <dir>            Specify stock image directory (must contain bootcore.bin, kernel.bin, and rootfs.img).
-o --image-out <filename>       Specify local upgrade image to output.
-h --help                       This help text
```

### create.sh
Tool for creating new WAS-110 local upgrade images
```
Usage: ./create.sh [options]

Options:
-i --image <filename>           Specify local upgrade image file to create (required).
-H --header <filename>          Specify filename of image header to base image off of (default: header.bin).
-b --bootcore <filename>        Specify filename of bootcore image to place in created image (default: bootcore.bin).
-k --kernel <filename>          Specify filename of kernel image to place in created image (default: kernel.bin).
-r --rootfs <filename>          Specify filename of rootfs image to place in created image (default: rootfs.img).
-V --image-version <version>    Specify version string to set on created image (14 characters max).
-h --help                       This help text
```


### extract.sh
Tool for extracting stock WAS-110 local upgrade images
```
Usage: ./extract.sh [options]

Options:
-i --image <filename>           Specify local upgrade image file to extract (required).
-H --header <filename>          Specify filename to extract image header to (default: header.bin).
-b --bootcore <filename>        Specify filename to extract bootcore image to (default: bootcore.bin).
-k --kernel <filename>          Specify filename to extract kernel image to (default: kernel.bin).
-r --rootfs <filename>          Specify filename to extract rootfs image to (default: rootfs.img).
-h --help                       This help text
```
