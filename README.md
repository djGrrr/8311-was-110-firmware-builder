# Bell WAS-110 Firmware Builder

## custom fwenvs
```
8311_internet_vlan=0
8311_services_vlan=36
8311_console_en=1
8311_equipment_id=5690
8311_ethtool_speed=speed 2500 autoneg off duplex full
8311_failsafe_delay=30
8311_sw_verA=SGC830007C
8311_sw_verB=SGC830006E
8311_mib_file=/etc/mibs/prx300_1V.ini
8311_root_pwhash=$1$BghTQV7M$ZhWWiCgQptC1hpUdIfa0e.
8311_hw_ver=Fast5689EBell
```

## custom uci settings
`uci -qc /ptconf/8311 show`  
```
dropbear.rsa_key=key
dropbear.rsa_key.value='BASE64 of the RSA server key'
dropbear.public_key=key
dropbear.public_key.value='ssh-rsa public key' 
```
