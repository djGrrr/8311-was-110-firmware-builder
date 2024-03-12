module("luci.controller.8311", package.seeall)

local tools = require "8311.tools"
local util = require "luci.util"
local ltemplate = require "luci.template"
local http = require "luci.http"
local formvalue = http.formvalue
local dispatcher = require "luci.dispatcher"

function index()
	entry({"admin", "8311"}, firstchild(), "8311", 99).dependent=false
	entry({"admin", "8311", "pontop"}, call("action_pontop")).leaf=true
	entry({"admin", "8311", "pon_status"}, call("action_pon_status"), "PON Status", 1)
	entry({"admin", "8311", "config"}, call("action_config"), "Configuration", 2)
	entry({"admin", "8311", "save"}, post_on({ data = true }, "action_save"))
end

function pontop_order()
	return {
		"status",
		"cap",
--		"lan",
		"alarms",
		"gem",
		"gem_stats",
--		"gem_ds",
--		"gem_us",
--		"eth_ds",
--		"eth_us",
		"fec",
		"gtc",
		"power_save",
		"psm",
		"alloc_stats",
		"ploam_ds",
		"ploam_us",
		"optical",
		"optical_info",
--		"debug_burst",
		"cqm",
		"cqm_map",
		"datapath_ports",
		"datapath_qos",
		"pp4_buffers",
		"pp4_pps",
		"pp4_stats",
		"pp4_tree",
		"pp4_qstats"
	}
end

function pontop_labels()
	return {
		status="Status",
		cap="Capability",
		lan="LAN Info",
		alarms="Alarms",
		gem="GEM Status",
		gem_stats="GEM Stats",
		gem_ds="GEM DS",
		gem_us="GEM US",
		eth_ds="ETH DS Stats",
		eth_us="ETH US Stats",
		fec="FEC Info",
		gtc="GTC Info",
		power_save="PS Info",
		psm="PSM",
		alloc_stats="Alloc Stats",
		ploam_ds="PLOAM DS",
		ploam_us="PLOAM US",
		optical="Optical Status",
		optical_info="Optical Info",
		debug_burst="Burst Profile",
		cqm="CQM",
		cqm_map="CQM Q Map",
		datapath_ports="DP Ports",
		datapath_qos="DP QoS",
		pp4_buffers="PPv4 Buffers",
		pp4_pps="PPv4 PPS",
		pp4_stats="PPv4 Stats",
		pp4_tree="PPv4 Tree",
		pp4_qstats="PPv4 QStats"
	}
end

function pontop_modes()
	return {
		status="Status",
		cap="Capability and Configuration",
		lan="LAN Interface Status & Counters",
		alarms="Active alarms",
		gem="GEM/XGEM Port Status",
		gem_stats="GEM/XGEM Port Counters",
		gem_ds="GEM/XGEM port DS Counters",
		gem_us="GEM/XGEM port US Counters",
		eth_ds="GEM/XGEM port Eth DS Cnts",
		eth_us="GEM/XGEM port Eth US Cnts",
		fec="FEC Status & Counters",
		gtc="GTC/XGTC Status & Counters",
		power_save="Power Save Status",
		psm="PSM Configuration",
		alloc_stats="Allocation Counters",
		ploam_ds="PLOAM Downstream Counters",
		ploam_us="PLOAM Upstream Counters",
		optical="Optical Interface Status",
		optical_info="Optical Interface Info",
		debug_burst="Debug Burst Profile",
		cqm="CQM ofsc",
		cqm_map="CQM Queue Map",
		datapath_ports="Datapath Ports",
		datapath_qos="Datapath QOS",
		pp4_buffers="PPv4 Buffer MGR HW Stats",
		pp4_pps="PPv4 QoS Queue PPS",
		pp4_stats="PPv4 QoS Queues Stats",
		pp4_tree="PPv4 QoS Tree",
		pp4_qstats="PPv4 QoS QStats"
	}
end

function fwenvs_8311()
	return {
		{
			id="pon",
			category="PON",
			items={	{
					id="gpon_sn",
					name="PON Serial Number (ONT ID)",
					description="GPON Serial Number sent to the OLT in various MEs (4 letters, followed by 8 hex digits).",
					maxlength=12,
					pattern='^[A-Za-z0-9]{4}[A-F0-9]{8}$',
					type="text"
				},{
					id="vendor_id",
					name="Vendor ID",
					description="PON Vendor ID sent in various MEs, automatically derived from the PON Serial Number if not set (4 letters).",
					maxlength=4,
					pattern='^[A-Za-z0-9]{4}$',
					type="text"
				},{
					id="equipment_id",
					name="Equipment ID",
					description="PON Equipment ID field in the ONU2-G ME [257] (up to 20 characters).",
					maxlength=20,
					type="text"
				},{
					id="hw_ver",
					name="Hardware Version",
					description="Hardware version string sent in various MEs (up to 14 characters).",
					maxlength=14,
					type="text"
				},{
					id="cp_hw_ver_sync",
					name="Sync Circuit Pack Version",
					description="Modify the configured MIB file to set the Version field of any Circuit Pack MEs [6] to match the Hardware Version (if set).",
					type="checkbox",
					default=false
				},{
					id="sw_verA",
					name="Software Version A",
					description="Image specific software version sent in the Software image MEs [7] (up to 14 characters).",
					maxlength=14,
					type="text",
					default=tools.fw_getenv("img_versionA")
				},{
					id="sw_verB",
					name="Software Version B",
					description="Image specific software version sent in the Software image MEs [7] (up to 14 characters).",
					maxlength=14,
					type="text",
					default=tools.fw_getenv("img_versionB")
				},{
					id="reg_id_hex",
					name="Registration ID (HEX)",
					description="Registration ID (up to 36 characters [72 hex]) sent to the OLT in hex format. This is where you would set a ploam password (which is contained in the last 12 characters).",
					maxlength=72,
					pattern='^([A-Fa-f0-9]{2})*$',
					type="text"
				},{
					id="loid",
					name="Logical ONU ID",
					description="Logical ONU ID presented in the ONU-G ME [256] (up to 24 characters).",
					maxlength=24,
					type="text"
				},{
					id="lpwd",
					name="Logical Password",
					description="Logical Password presented in the ONU-G ME [256] (up to 12 characters).",
					maxlength=12,
					type="text"
				},{
					id="mib_file",
					name="MIB File",
					description="MIB file used by omcid. Defaults to /etc/mibs/prx300_1U.ini",
					maxlength=255,
					pattern='^(\\/etc\\/mibs\\/)?[A-Za-z0-9_.-]+\\.ini$',
					type="text"
				},{
					id="pon_slot",
					name="PON Slot",
					description="Change the slot number that the UNI port is presented on, needed on some ISPs.",
					maxlength=3,
					pattern='^[0-9]*$',
					type="text"
				},{
					id="iphost_mac",
					name="IP Host MAC Address",
					description="MAC address sent in the IP host config data ME [134] (XX:XX:XX:XX:XX:XX format).",
					maxlength=17,
					pattern='^[A-Fa-f0-9]{2}(:[A-Fa-f0-9]{2}){5}$',
					type="text",
					default=util.trim(util.exec("sh -c '. /lib/pon.sh; pon_mac_get host'")):upper()
				},{
					id="iphost_hostname",
					name="IP Host Hostname",
					description="Hostname sent in the IP host config data ME [134] (up to 25 characters).",
					maxlength=25,
					type="text"
				},{
					id="iphost_domain",
					name="IP Host Domain Name",
					description="Domain name sent in the IP host config data ME [134] (up to 25 characters).",
					maxlength=25,
					type="text"
				}
			}
		},{
			id="isp",
			category="ISP Fixes",
			items={	{
					id="fix_vlans",
					name="Fix VLANs",
					description="Apply automatic fixes to the VLAN configuration from the OLT.",
					type="checkbox",
					default=true
				},{
					id="internet_vlan",
					name="Internet VLAN",
					description="Set the local VLAN ID to use for the Internet or 0 to make the Internet untagged (and also remove VLAN 0) (0 to 4095). Defaults to 0 (untagged).",
					maxlength=4,
					pattern='^[0-9]+$',
					type="text",
					default="0"
				},{
					id="services_vlan",
					name="Services VLAN",
					description="Set the local VLAN ID to use for Services (ie TV/Home Phone) (1 to 4095). This fixes multi-service on Bell.",
					maxlength=4,
					pattern='^[0-9]+$',
					type="text",
					default="34|36"
				}
			}
		},{
			id="device",
			category="Device",
			items={ {
					id="console_en",
					name="Serial console",
					description="Enable the serial console. This will cause TX_FAULT to be asserted as it shares the same SFP pin.",
					type="checkbox",
					default=false
				},{
					id="dying_gasp_en",
					name="Dying Gasp",
					description="Enable dying gasp. This will cause the serial console input to break as it shares the same SFP pin.",
					type="checkbox",
					default=false
				},{
					id="rx_los",
					name="RX Loss of Signal",
					description="Enable the RX_LOS pin. Disable to allow stick to be accessible without the fiber connected in all devices.",
					type="checkbox",
					default=true
				},{
					id="root_pwhash",
					name="Root password hash",
					description="Custom password hash for the root user.",
					maxlength=255,
					type="text",
				},{
					id="ethtool_speed",
					name="Ethtool Speed Settings",
					description="Ethtool speed settings on the eth0_0 interface (ethtool -s).",
					maxlength=100,
					type="text"
				},{
					id="failsafe_delay",
					name="Failsafe Delay",
					description="Number of seconds that we will delay the startup of omcid for at bootup (10 to 300). Defaults to 15 seconds",
					maxlength=3,
					pattern='^[0-9]+$',
					type="text",
					default="15"
				},{
					id="persist_root",
					name="Persist RootFS",
					description="Allow the root file system to stay persistent (would also require that you modify the bootcmd fwenv). This is not recommended and should only be used for debug/testing purposes.",
					type="checkbox",
					default=false
				}
			}
		},{
			id="manage",
			category="Management",
			items={	{
					id="ipaddr",
					name="IP Address",
					description="Management IP address. Defaults to 192.168.11.1",
					maxlength=15,
					pattern='^[0-9]{1,3}(\\.[0-9]{1,3}){3}$',
					type="text",
					default="192.168.11.1"
				},{
					id="netmask",
					name="Subnet Mask",
					description="Management subnet mask. Defaults to 255.255.255.0",
					maxlength=15,
					pattern='^[0-9]{1,3}(\\.[0-9]{1,3}){3}$',
					type="text",
					default="255.255.255.0"
				},{
					id="gateway",
					name="Gateway",
					description="Management gateway. Defaults to the IP address (ie. no default gateway)",
					maxlength=15,
					pattern='^[0-9]{1,3}(\\.[0-9]{1,3}){3}$',
					type="text",
					default="192.168.11.1"
				},{
					id="ping_ip",
					name="Ping IP",
					description="IP address to ping every 5 seconds, this can helps with reaching the stick. Defaults to the 2nd ip address in the configured management network (ie. 192.168.11.2).",
					maxlength=15,
					pattern='^[0-9]{1,3}(\\.[0-9]{1,3}){3}$',
					type="text",
					default="192.168.11.2"
				},{
					id="lct_mac",
					name="LCT MAC Address",
					description="MAC address of the LCT management interface (XX:XX:XX:XX:XX:XX format).",
					maxlength=17,
					pattern='^[A-Fa-f0-9]{2}(:[A-Fa-f0-9]{2}){5}$',
					type="text",
					default=util.trim(util.exec("sh -c '. /lib/pon.sh; pon_mac_get lct'")):upper()
				}
			}
		}
	}
end

function action_pontop(mode)
	local cmd

	mode = mode or "status"

	local modes = pontop_modes()
	if not modes[mode] then
		return false
	end

	cmd = { "/usr/bin/pontop", "-g", modes[mode], "-b" }
	luci.http.prepare_content("text/plain; charset=utf-8")
	luci.sys.process.exec(cmd, luci.http.write)
end

function action_pon_status()
	local order = pontop_order()
	local labels = pontop_labels()
	local modes = pontop_modes()

	ltemplate.render("8311/pon_status", {
		order=order,
		labels=labels,
		modes=modes
	})
end

function populate_8311_fwenvs()
	local fwenvs = fwenvs_8311()

	for catid, cat in pairs(fwenvs) do
		for itemid, item in pairs(cat.items) do
			fwenvs[catid]["items"][itemid]["value"] = tools.fw_getenv_8311(item.id)
		end
	end

	return fwenvs
end

function action_config()
	local fwenvs = populate_8311_fwenvs()

	ltemplate.render("8311/config", {
		fwenvs=fwenvs
	})
end

function action_save()
	local value = nil

	local fwenvs = populate_8311_fwenvs()
	for catid, cat in pairs(fwenvs) do
		for itemid, item in pairs(cat.items) do
			value = formvalue(item.id)
			if value == nil then value = '' end

			if item.type == 'checkbox' then
				if item.value == '' and ((item.default and value == '1') or (not item.default and (value == '0' or value == ''))) then
					value = ''
				elseif value == '' then
					value = '0'
				end
			elseif item.value == '' and item.default and value == item.default then
				value = ''
			end

--			http.write(item.id .. " - '" .. tools.html_escape(value) .. "'<br />\n")

			if item.value ~= value then
--				http.write("Setting " .. item.id .. " to '" .. tools.html_escape(value) .. "'<br />\n")
				tools.fw_setenv_8311(item.id, value)
			end
		end
	end

	http.redirect(dispatcher.build_url("admin/8311/config"))
end
