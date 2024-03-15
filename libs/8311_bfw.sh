#!/bin/sh

_lib_8311 2>/dev/null || . /lib/8311.sh

_set_8311_gpon_sn() {
	uci -qc /ptdata set "factory_conf.GponSN"="key"
	uci -qc /ptdata set "factory_conf.GponSN.encryflag"="0"
	uci -qc /ptdata set "factory_conf.GponSN.value"="$1"
	uci -qc /ptdata commit "factory_conf"
}

_set_8311_device_sn() {
	# this only really changes what's in load_cli and the webui
	uci -qc /ptdata set "factory_conf.SerialNumber"="key"
	uci -qc /ptdata set "factory_conf.SerialNumber.encryflag"="0"
	uci -qc /ptdata set "factory_conf.SerialNumber.value"="$1"
	uci -qc /ptdata commit "factory_conf"
}

_set_8311_vendor_id() {
	uci -qc /ptdata set "factory_conf.VendorCode"="key"
	uci -qc /ptdata set "factory_conf.VendorCode.encryflag"="0"
	uci -qc /ptdata set "factory_conf.VendorCode.value"="$1"
	uci -qc /ptdata commit "factory_conf"
}

_set_8311_reg_id_hex() {
	uci -qc /ptdata set "factory_conf.GPONPassWord"="key"
	uci -qc /ptdata set "factory_conf.GPONPassWord.encryflag"="1"
	uci -qc /ptdata set "factory_conf.GPONPassWord.value"="$(echo -n "$1" | sed 's/\([0-9A-F]\{2\}\)/\\\\\\x\1/gI' | xargs printf | base64)"
	uci -qc /ptdata commit "factory_conf"

	uci -qc /ptconf delete "usrconfig_conf.InternetGatewayDevice__DeviceInfo__.RegistrationID"
	uci -qc /ptconf commit "usrconfig_conf"
}

_set_8311_sw_ver() {
	uci -qc /ptconf set "sysinfo_conf.SoftwareVersion_$1"="key"
	uci -qc /ptconf set "sysinfo_conf.SoftwareVersion_$1.encryflag"="0"
	uci -qc /ptconf set "sysinfo_conf.SoftwareVersion_$1.value"="$2"
	uci -qc /ptconf commit "sysinfo_conf"
}

_set_8311_hw_ver() {
	uci -qc /ptrom/ptconf set "sysinfo_conf.HardwareVersion"="key"
	uci -qc /ptrom/ptconf set "sysinfo_conf.HardwareVersion.encryflag"="0"
	uci -qc /ptrom/ptconf set "sysinfo_conf.HardwareVersion.value"="$HW_VERSION"
	uci -qc /ptrom/ptconf commit "sysinfo_conf"

	uci -qc /ptdata set "factory_conf.HardwareVersion"="key"
	uci -qc /ptdata set "factory_conf.HardwareVersion.encryflag"="0"
	uci -qc /ptdata set "factory_conf.HardwareVersion.value"="$1"
	uci -qc /ptdata commit "factory_conf"
}

_set_8311_equipment_id() {
	(
		while [ ! -f "/tmp/deviceinfo" ]; do
			sleep 1
		done

		uci -qc /tmp set "deviceinfo.devicetype.value"="$1"
		uci -qc /tmp commit "deviceinfo"
	) &
}

_set_8311_ipaddr() {
    sed -r 's#(<param name="Ipaddr" .+ value=)"\S+"(></param>)#\1"'"$1"'"\2#g' -i "/ptrom/ptconf/param_ct.xml"
}

_set_8311_netmask() {
	sed -r 's#(<param name="SubnetMask" .+ value=)"\S+"(></param>)#\1"'"$1"'"\2#g' -i "/ptrom/ptconf/param_ct.xml"
}

_set_8311_gateway() {
	sed -r 's#(<param name="Gateway" .+ value=)"\S+"(></param>)#\1"'"$1"'"\2#g' -i "/ptrom/ptconf/param_ct.xml"
}

_set_8311_lct_mac() {
	uci -qc /ptdata set "factory_conf.brmac"="key"
	uci -qc /ptdata set "factory_conf.brmac.encryflag"="0"
	uci -qc /ptdata set "factory_conf.brmac.value"="$LCT_MAC"
	uci -qc /ptdata commit "factory_conf"
}

_set_8311_iphost_mac() {
	uci -qc /ptdata set "factory_conf.internetmac"="key"
	uci -qc /ptdata set "factory_conf.internetmac.encryflag"="0"
	uci -qc /ptdata set "factory_conf.internetmac.value"="$1"
	uci -qc /ptdata commit "factory_conf"
}
