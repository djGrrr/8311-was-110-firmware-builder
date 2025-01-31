# 8311 WAS-110 Firmware Builder
## 国内优化版，目前没做太多更改
### 主要特性如下：
- 修改bypass脚本，适配国内运营商，不会瞎把internet绑定到默认GEM1的tr096上（这个因地区而异，在我的印象里大部分运营商GEM1一般是tr096，GEM2一般是internet，GEM3一般是iptv，如果你们地区有很逆天的配置，比如一个GEM走N个VLAN，请告诉我）
- 初步SNMP支持

## Custom fwenvs

8311_fix_vlans=1
8311_internet_vlan=0
8311_services_vlan=36

8311_ipaddr=192.168.11.1
8311_netmask=255.255.255.0
8311_gateway=192.168.11.254
8311_ping_ip=192.168.11.2

8311_console_en=1
8311_ethtool_speed=speed 2500 autoneg off duplex full
8311_failsafe_delay=30
8311_persist_root=0
8311_root_pwhash=$1$BghTQV7M$ZhWWiCgQptC1hpUdIfa0e.
8311_rx_los=0

8311_cp_hw_ver_sync=1
8311_device_sn=DM222XXXXXXXXXX
8311_equipment_id=5690
8311_gpon_sn=SMBSXXXXXXXX
8311_hw_ver=Fast5689EBell
8311_mib_file=/etc/mibs/prx300_1V.ini
8311_reg_id_hex=00
8311_sw_verA=SGC830007C
8311_sw_verB=SGC830006E
8311_vendor_id=SMBS

### ISP Fix fwenvs
`8311_fix_vlans` - **Fix VLANs**  
Set to `0` to disable the automatic fixes that are applied to VLANs.  

`8311_internet_vlan` - **Internet VLAN**  
Set the local VLAN ID to use for the Internet or `0` to make the Internet untagged (and also remove VLAN 0) (0 to 4095). Defaults to `0` (untagged).  

`8311_services_vlan` - **Services VLAN**  
Set the local VLAN ID to use for Services (ie TV/Home Phone) (1 to 4095). This fixes multi-service on Bell.  


### Management fwenvs
`8311_ipaddr` - **IP Address**  
Set the management IP address. Defaults to `192.168.11.1`  

`8311_netmask` - **Subnet Mask**  
Set the management subnet mask. Defaults to `255.255.255.0`  

`8311_gateway` - **Gateway**  
Set the management gateway. Defaults to the IP address (ie. no default gateway)  

`8311_ping_ip` - **Ping IP**  
Sets an IP address to ping every 5 seconds, this can helps with reaching the stick. Defaults to the 2nd ip address in the configured management network (ie. 192.168.11.2).  


### Device fwenvs
`8311_console_en` - **Serial console**  
Set to `1` to enable the serial console, this will cause TX_FAULT to be asserted as it shares the same SFP pin.  

`8311_ethtool_speed` - **Ethtool Speed Settings**  
Set ethtool speed settings on the eth0_0 interface (ethtool -s).  

`8311_factory_mode` - **Factory Mode**  
Set to 1 to enable factory mode, otherwise factory mode will be automatically disabled on boot.  

`8311_failsafe_delay` - **Failsafe Delay**  
Sets the number of seconds that we will delay the startup of omcid for at bootup (30 to 300). Defaults to 30 seconds.  

`8311_lct_mac` - **LCT MAC Address**  
Set the MAC address on the LCT management interface.  

`8311_persist_root` - **Persist RootFS**  
Set to `1` to allow the root file system to stay persistent (would also require that you modify the bootcmd fwenv). This is not recommended and should only be used for debug/testing purposes.  

`8311_root_pwhash` - **Root password hash**  
Allows you to set a custom root password by setting the hash.  

`8311_rx_los` - **RX_LOS Workaround**  
Set to `0` to monitor the status of the RX_LOS pin to disable it any time it gets enabled. This will allow the stick to be accessible in devices which disable access to the port if RX_LOS is being asserted.  


### PON fwenvs
`8311_cp_hw_ver_sync` - **Sync Circuit Pack Version**  
When set to `1` and `8311_hw_ver` is also set, will modify the configured mib file to set the Version field of any Circuit Pack MEs to match the Hardware version.  

`8311_device_sn` - **Device Serial Number**  
Sets the physical device S/N, this is more or less display only.  

`8311_equipment_id` - **Equipment ID**  
Sets the PON Equipment ID field in the ONU2-G ME (257).  

`8311_gpon_sn` - **GPON Serial Number / ONT ID**  
Sets the GPON Serial Number sent to the OLT in various MEs (4 letters, followed by 8 hex digits).  

`8311_hw_ver` - **Hardware Version**  
Set the Hardware version string sent to the OLT in various MEs (up to 14 characters).  

`8311_iphost_domain` - **IP Host Domain Name**  
Set the domain name sent to the OLT in ME 134 (up to 25 characters).  

`8311_iphost_hostname` - **IP Host Hostname**  
Set the hostname sent to the OLT in ME 134 (up to 25 characters).  

`8311_iphost_mac` - **IP Host MAC Address**  
Set the MAC address sent to the OLT in ME 134.  

`8311_loid` - **Logical ONU ID**  
Sets the Logical ONU ID presented to the OLT in ME 256 (up to 24 characters).  

`8311_lpwd` - **Logical Password**  
Sets the Logical Password prsented to the OLT in ME 256 (up to 12 characters).  

`8311_mib_file` - **MIB File**  
Sets the MIB file used by omcid. Defaults to `/etc/mibs/prx300_1U.ini`  

`8311_pon_slot` - **PON Slot**  
Sets the slot number that the UNI port is presented on, needed on some ISPs.  

`8311_reg_id_hex` - **Registration ID**  
Sets the Registration ID (up to 36 characters [72 hex]) sent to the OLT in hex format. This is where you would set a ploam password (which is contained in the last 12 characters).  

`8311_sw_verA` / `8311_sw_verB` - **Software Versions**  
Sets the image specific software versions sent in the Software image MEs (7).  

`8311_vendor_id` - **Vendor ID**  
Sets the PON Vendor ID sent to the OLT, automatically derived from the GPON Serial Number if not set (4 letters).  



## Authentication
SSH host keys (all of `/etc/dropbear`) and authorized_keys (all of `/root/.ssh`) are now stored persistently.
Previous UCI settings will be automatically migrated.

The current root password (change with `passwd`) can be persisted using the `8311-persist-root-password.sh` command



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
