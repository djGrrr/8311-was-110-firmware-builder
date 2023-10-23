# Bell WAS-110 Firmware Builder

## custom fwenvs
```
bell_internet_vlan=0
bell_services_vlan=34
console_en=1
equipment_id=5690
ethtool_speed=speed 2500 autoneg off duplex full
failsafe_delay=30
img_version=SGC830007C
mib_file=/etc/mibs/prx300_1V.ini
root_pwhash=$1$BghTQV7M$ZhWWiCgQptC1hpUdIfa0e.
version=Fast5689EBell
```

## custom uci settings
`uci -qc /ptconf/8311 show`  
```
dropbear.rsa_key=key
dropbear.rsa_key.value='BASE64 of the RSA server key'
dropbear.public_key=key
dropbear.public_key.value='ssh-rsa public key' 
```
