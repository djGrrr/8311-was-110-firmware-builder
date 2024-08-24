module("luci.controller.8311", package.seeall)

local tools = require "8311.tools"
local util = require "luci.util"
local ltemplate = require "luci.template"
local http = require "luci.http"
local formvalue = http.formvalue
local dispatcher = require "luci.dispatcher"
local sys = require "luci.sys"
local i18n = require "luci.i18n"
local translate = i18n.translate
local base64 = require "base64"

local firmwareOutput = ''

function index()
	entry({"admin", "8311"}, firstchild(), translate("8311"), 99).dependent=false
	entry({"admin", "8311", "config"}, call("action_config"), translate("Configuration"), 1)
	entry({"admin", "8311", "pon_status"}, call("action_pon_status"), translate("PON Status"), 2)
	entry({"admin", "8311", "pon_explorer"}, call("action_pon_explorer"), translate("PON ME Explorer"), 3)

	entry({"admin", "8311", "save"}, post_on({ data = true }, "action_save"))
	entry({"admin", "8311", "pontop"}, call("action_pontop")).leaf=true
	entry({"admin", "8311", "pon_dump"}, call("action_pon_dump")).leaf=true

	entry({"admin", "8311", "firmware"}, call("action_firmware"), translate("Firmware"), 4);
end

function pontop_page_details()
	return {{
			id="status",
			page="Status",
			label=translate("Status")
		},{
			id="cap",
			page="Capability and Configuration",
			label=translate("Capability")
		},{
			id="lan",
			page="LAN Interface Status & Counters",
			label=translate("LAN Info"),
			display=false
		},{
			id="alarms",
			page="Active alarms",
			label=translate("Alarms")
		},{
			id="gem",
			page="GEM/XGEM Port Status",
			label=translate("GEM Status")
		},{
			id="gem_stats",
			page="GEM/XGEM Port Counters",
			label=translate("GEM Stats")
		},{
			id="gem_ds",
			page="GEM/XGEM port DS Counters",
			label=translate("GEM DS"),
			display=false
		},{
			id="gem_us",
			page="GEM/XGEM port US Counters",
			label=translate("GEM US"),
			display=false
		},{
			id="eth_ds",
			page="GEM/XGEM port Eth DS Cnts",
			label=translate("ETH DS Stats"),
		},{
			id="eth_us",
			page="GEM/XGEM port Eth US Cnts",
			label=translate("ETH US Stats")
		},{
			id="fec",
			page="FEC Status & Counters",
			label=translate("FEC Info")
		},{
			id="gtc",
			page="GTC/XGTC Status & Counters",
			label=translate("GTC Info")
		},{
			id="power_save",
			page="Power Save Status",
			label=translate("PS Status")
		},{
			id="psm",
			page="PSM Configuration",
			label=translate("PSM")
		},{
			id="alloc_stats",
			page="Allocation Counters",
			label=translate("Alloc Stats")
		},{
			id="ploam_ds",
			page="PLOAM Downstream Counters",
			label=translate("PLOAM DS")
		},{
			id="ploam_us",
			page="PLOAM Upstream Counters",
			label=translate("PLOAM US")
		},{
			id="optical",
			page="Optical Interface Status",
			label=translate("Optical Status")
		},{
			id="optical_info",
			page="Optical Interface Info",
			label=translate("Optical Info")
		},{
			id="debug_burst",
			page="Debug Burst Profile",
			label=translate("Burst Profile")
		},{
			id="cqm",
			page="CQM ofsc",
			label=translate("CQM")
		},{
			id="cqm_map",
			page="CQM Queue Map",
			label=translate("CQM Q Map")
		},{
			id="datapath_ports",
			page="Datapath Ports",
			label=translate("DP Ports")
		},{
			id="datapath_qos",
			page="Datapath QOS",
			label=translate("DP QoS")
		},{
			id="pp4_buffers",
			page="PPv4 Buffer MGR HW Stats",
			label=translate("PPv4 Buffers")
		},{
			id="pp4_pps",
			page="PPv4 QoS Queue PPS",
			label=translate("PPv4 PPS")
		},{
			id="pp4_stats",
			page="PPv4 QoS Queues Stats",
			label=translate("PPv4 Stats")
		},{
			id="pp4_tree",
			page="PPv4 QoS Tree",
			label=translate("PPv4 Tree")
		},{
			id="pp4_qstats",
			page="PPv4 QoS QStats",
			label=translate("PPv4 QStats")
		}
	}
end


function pontop_pages()
	local details = pontop_page_details()
	local pages = {}
	for _, page in pairs(details) do
		pages[page.id] = page.page
	end

	return pages
end

function fwenvs_8311()
	local zones = util.trim(util.exec("grep -v '^#' /usr/share/zoneinfo/zone.tab  | awk '{print $3}' | sort -uV ; echo UTC"))
	local timezones = {}
	for zone in zones:gmatch("[^\r\n]+") do
		table.insert(timezones, zone)
	end

	local ipv4_regex = "^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"

	return {{
			id="pon",
			category=translate("PON"),
			items={	{
					id="gpon_sn",
					name=translate("PON Serial Number (ONT ID)"),
					description=translate("GPON Serial Number sent to the OLT in various MEs (4 alphanumeric characters, followed by 8 hex digits)."),
					maxlength=12,
					pattern='^[A-Za-z0-9]{4}[A-F0-9]{8}$',
					type="text",
					required=true
				},{
					id="vendor_id",
					name=translate("Vendor ID"),
					description=translate("PON Vendor ID sent in various MEs, automatically derived from the PON Serial Number if not set (4 alphanumeric characters."),
					maxlength=4,
					pattern='^[A-Za-z0-9]{4}$',
					type="text"
				},{
					id="equipment_id",
					name=translate("Equipment ID"),
					description=translate("PON Equipment ID field in the ONU2-G ME [257] (up to 20 characters)."),
					maxlength=20,
					type="text"
				},{
					id="hw_ver",
					name=translate("Hardware Version"),
					description=translate("Hardware version string sent in various MEs (up to 14 characters)."),
					maxlength=14,
					type="text"
				},{
					id="cp_hw_ver_sync",
					name=translate("Sync Circuit Pack Version"),
					description=translate("Modify the configured MIB file to set the Version field of any Circuit Pack MEs [6] to match the Hardware Version (if set)."),
					type="checkbox",
					default=false
				},{
					id="sw_verA",
					name=translate("Software Version A"),
					description=translate("Image specific software version sent in the Software image MEs [7] (up to 14 characters)."),
					maxlength=14,
					type="text",
					default=tools.fw_getenv{"img_versionA"}
				},{
					id="sw_verB",
					name=translate("Software Version B"),
					description=translate("Image specific software version sent in the Software image MEs [7] (up to 14 characters)."),
					maxlength=14,
					type="text",
					default=tools.fw_getenv{"img_versionB"}
				},{
					id="fw_match_b64",
					name=translate("Firmware Version Match"),
					description=translate("PCRE pattern match for automatic updating of Software Versions when OLT uploads a firmware upgrade. Must contain a single sub-pattern match."),
					type="text",
					maxlength="255",
					base64=true
				},{
					id="fw_match_num",
					name=translate("Firmware Match Number"),
					description=translate("If there are multiple matches for the Firmware Version Match pattern, use this specific match number."),
					type="number",
					min=1,
					max=99,
					default="1"
				},{
					id="override_active",
					name=translate("Override active firmware bank"),
					description=translate("Override which software bank is marked as active in the Software image MEs [7]."),
					type="select",
					default="",
					options={
						"",
						"A",
						"B"
					}
				},{
					id="override_commit",
					name=translate("Override committed firmware bank"),
					description=translate("Override which software bank is marked as committed in the Software image MEs [7]."),
					type="select",
					default="",
					options={
						"",
						"A",
						"B"
					}
				},{
					id="pon_mode",
					name=translate("PON Mode"),
					description=translate("PON mode of operation. This is where you can choose between XGS-PON (the default) or XG-PON."),
					type="select_named",
					default="xgspon",
					options={
						{
							name="XGS-PON",
							value="xgspon"
						},{
							name="XG-PON",
							value="xgpon"
						}
					}
				},{
					id="omcc_version",
					name=translate("OMCC Version"),
					description=translate("The OMCC version to use in hexadecimal format between 0x80 and 0xBF. Default is 0xA3"),
					type="text",
					default="0xA3",
					maxlength=4,
					pattern='^0x[89AB][0-9A-F]$'
				},{
					id="reg_id_hex",
					name=translate("Registration ID (HEX)"),
					description=translate("Registration ID (up to 36 bytes) sent to the OLT, in hex format. This is where you would set a ploam password (which is contained in the last 12 bytes)."),
					maxlength=72,
					pattern='^([A-Fa-f0-9]{2})*$',
					type="text"
				},{
					id="loid",
					name=translate("Logical ONU ID"),
					description=translate("Logical ONU ID presented in the ONU-G ME [256] (up to 24 characters)."),
					maxlength=24,
					type="text"
				},{
					id="lpwd",
					name=translate("Logical Password"),
					description=translate("Logical Password presented in the ONU-G ME [256] (up to 12 characters)."),
					maxlength=12,
					type="text"
				},{
					id="mib_file",
					name=translate("MIB File"),
					description=translate("MIB file used by omcid. Defaults to /etc/mibs/prx300_1U.ini"),
					type="select",
					default="/etc/mibs/prx300_1U.ini",
					options={
						"/etc/mibs/prx300_1U.ini",
						"/etc/mibs/prx300_1U_telus.ini",
						"/etc/mibs/prx300_1V.ini",
						"/etc/mibs/prx300_1V_bell.ini",
						"/etc/mibs/prx300_2U.ini",
						"/etc/mibs/prx300_2U_voip.ini",
						"/etc/mibs/urx800_1U.ini",
						"/etc/mibs/urx800_1V.ini"
					}
				},{
					id="pon_slot",
					name=translate("PON Slot"),
					description=translate("Change the slot number that the UNI port is presented on, needed on some ISPs."),
					type="number",
					min=1,
					max=255
				},{
					id="iphost_mac",
					name=translate("IP Host MAC Address"),
					description=translate("MAC address sent in the IP host config data ME [134] (XX:XX:XX:XX:XX:XX format)."),
					maxlength=17,
					pattern='^[A-Fa-f0-9]{2}(:[A-Fa-f0-9]{2}){5}$',
					type="text",
					default=util.trim(util.exec(". /lib/pon.sh && pon_mac_get host")):upper()
				},{
					id="iphost_hostname",
					name=translate("IP Host Hostname"),
					description=translate("Hostname sent in the IP host config data ME [134] (up to 25 characters)."),
					maxlength=25,
					type="text"
				},{
					id="iphost_domain",
					name=translate("IP Host Domain Name"),
					description=translate("Domain name sent in the IP host config data ME [134] (up to 25 characters)."),
					maxlength=25,
					type="text"
				}
			}
		},{
			id="isp",
			category=translate("ISP Fixes"),
			items={	{
					id="fix_vlans",
					name=translate("Fix VLANs"),
					description=translate("Apply automatic fixes to the VLAN configuration from the OLT."),
					type="checkbox",
					default=true
				},{
					id="internet_vlan",
					name=translate("Internet VLAN"),
					description=translate("Set the local VLAN ID to use for the Internet or 0 to make the Internet untagged (and also remove VLAN 0) (0 to 4095). Defaults to 0 (untagged)."),
					type="number",
					min=0,
					max=4095,
					default="0"
				},{
					id="services_vlan",
					name=translate("Services VLAN"),
					description=translate("Set the local VLAN ID to use for Services (ie TV/Home Phone) (1 to 4095). This fixes multi-service on Bell."),
					type="number",
					min=1,
					max=4095,
					default="34|36"
				}
			}
		},{
			id="device",
			category=translate("Device"),
			items={ {
					id="bootdelay",
					name=translate("Boot Delay"),
					description=translate("Set the boot delay in seconds in which you can interupt the boot process over the serial console. With the Azores U-Boot, this also controls the number of times multicast upgrade is attempted and thus can have a significant impact in boot time. Default: 3, Recommended: 1"),
					type="select_named",
					default="3",
					base=true,
					options={
						{
							name=translate("0 (Fastest, disables multicast upgrade, not recommended)"),
							value="0"
						},{
							name=translate("1 (Fast Boot)"),
							value="1"
						},{
							name="2",
							value="2"
						},{
							name=translate("3 (Default)"),
							value="3"
						}
					}
				},{
					id="console_en",
					name=translate("Serial console"),
					description=translate("Enable the serial console. This will cause TX_FAULT to be asserted as it shares the same SFP pin."),
					type="checkbox",
					default=false
				},{
					id="dying_gasp_en",
					name=translate("Dying Gasp"),
					description=translate("Enable dying gasp. This will cause the serial console input to break as it shares the same SFP pin."),
					type="checkbox",
					default=false
				},{
					id="rx_los",
					name=translate("RX Loss of Signal"),
					description=translate("Enable the RX_LOS pin. Disable to allow stick to be accessible without the fiber connected in all devices."),
					type="checkbox",
					default=false
				},{
					id="root_pwhash",
					name=translate("Root password hash"),
					description=translate("Custom password hash for the root user. This can be set from System > Administration"),
					maxlength=255,
					type="text",
				},{
					id="ethtool_speed",
					name=translate("Ethtool Speed Settings"),
					description=translate("Ethtool speed settings on the eth0_0 interface (ethtool -s)."),
					maxlength=100,
					type="text"
				},{
					id="failsafe_delay",
					name=translate("Failsafe Delay"),
					description=translate("Number of seconds that we will delay the startup of omcid for at bootup (10 to 300). Defaults to 15 seconds"),
					type="number",
					min=10,
					max=300,
					default="15"
				},{
					id="hostname",
					name=translate("System Hostname"),
					description=translate("Set the system hostname visible over SSH/Console/WebUI."),
					maxlength=100,
					type="text",
					default="prx126-sfp-pon"
				},{
					id="timezone",
					name=translate("Time Zone"),
					description=translate("System Time Zone"),
					type="select",
					default="UTC",
					options=timezones
				},{
					id="ntp_servers",
					name=translate("NTP Servers"),
					description=translate("NTP server(s) to sync time from (space separated)."),
					maxlength=255,
					type="text"
				},{
					id="persist_root",
					name=translate("Persist RootFS"),
					description=translate("Allow the root file system to stay persistent (would also require that you modify the bootcmd fwenv). This is not recommended and should only be used for debug/testing purposes."),
					type="checkbox",
					default=false
				}
			}
		},{
			id="manage",
			category=translate("Management"),
			items={	{
					id="lct_vlan",
					name=translate("Management VLAN"),
					description=translate("Set the management VLAN ID (0 to 4095). Defaults to 0 (untagged)."),
					type="number",
					min=0,
					max=4095,
					default="0"
				},{
					id="ipaddr",
					name=translate("IP Address"),
					description=translate("Management IP address. Defaults to 192.168.11.1"),
					maxlength=15,
					pattern=ipv4_regex,
					type="text",
					default="192.168.11.1"
				},{
					id="netmask",
					name=translate("Subnet Mask"),
					description=translate("Management subnet mask. Defaults to 255.255.255.0"),
					maxlength=15,
					pattern=ipv4_regex,
					type="text",
					default="255.255.255.0"
				},{
					id="gateway",
					name=translate("Gateway"),
					description=translate("Management gateway. Defaults to the IP address (ie. no default gateway)"),
					maxlength=15,
					pattern=ipv4_regex,
					type="text",
					default=util.trim(util.exec(". /lib/8311.sh && get_8311_ipaddr"))
				},{
					id="dns_server",
					name=translate("DNS Server"),
					description=translate("Management DNS server."),
					maxlength=15,
					pattern=ipv4_regex,
					type="text"
				},{
					id="ping_ip",
					name=translate("Ping IP"),
					description=translate("IP address to ping every 5 seconds, this can help with reaching the stick. Defaults to the 2nd IP address in the configured management network (ie. 192.168.11.2)."),
					maxlength=15,
					pattern=ipv4_regex,
					type="text",
					default=util.trim(util.exec(". /lib/8311.sh && get_8311_default_ping_host"))
				},{
					id="lct_mac",
					name=translate("LCT MAC Address"),
					description=translate("MAC address of the LCT management interface (XX:XX:XX:XX:XX:XX format)."),
					maxlength=17,
					pattern='^[A-Fa-f0-9]{2}(:[A-Fa-f0-9]{2}){5}$',
					type="text",
					default=util.trim(util.exec(". /lib/pon.sh && pon_mac_get lct")):upper()
				},{
					id="https_redirect",
					name=translate("Redirect HTTP to HTTPs"),
					description=translate("Automatically redirect requests to the WebUI over HTTP to HTTPs. Defaults to on."),
					type="checkbox",
					default=true
				}
			}
		}
	}
end

function action_pontop(page)
	local cmd

	page = page or "status"

	local pages = pontop_pages()

	if not pages[page] then
		return false
	end

	cmd = { "/usr/bin/pontop", "-g", pages[page], "-b" }
	luci.http.prepare_content("text/plain; charset=utf-8")
	luci.sys.process.exec(cmd, luci.http.write)
end

function action_pon_status()
	local pages = pontop_page_details()

	ltemplate.render("8311/pon_status", {
		pages=pages,
	})
end

function populate_8311_fwenvs()
	local fwenvs = fwenvs_8311()
	local fwenvs_values = tools.fw_getenvs_8311()

	for catid, cat in pairs(fwenvs) do
		for itemid, item in pairs(cat.items) do
			if item.base then
				value = tools.fw_getenv{item.id}
			else
				value = fwenvs_values[item.id] or ''
			end
			if item.base64 and value ~= '' then
				value = base64.dec(value)
			end

			fwenvs[catid]["items"][itemid]["value"] = value
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
	if http.getenv('REQUEST_METHOD') == 'POST' then
		local fwenvs = populate_8311_fwenvs()

		for catid, cat in pairs(fwenvs) do
			for itemid, item in pairs(cat.items) do
				value = formvalue(item.id) or ''

				if item.type == 'checkbox' then
					if item.value == '' and ((item.default and value == '1') or (not item.default and (value == '0' or value == ''))) then
						value = ''
					elseif value == '' then
						value = '0'
					end
				elseif item.value == '' and item.default and value == item.default then
					value = ''
				end

				if item.value ~= value then
					if item.base64 and value ~= '' then
						value = base64.enc(value)
					end

					if item.base then
						tools.fw_setenv{item.id, value}
					else
						tools.fw_setenv_8311{item.id, value}
					end
				end
			end
		end
	end

	http.redirect(dispatcher.build_url("admin/8311/config"))
end

function action_pon_explorer()
	local omci = util.exec("/usr/bin/luci-me-dump")

	ltemplate.render("8311/pon_me", {
		omci=omci
	})
end

function action_pon_dump(me_id, instance_id)
	cmd = { "/usr/bin/omci_pipe.sh", "meg", me_id, instance_id }
	luci.http.prepare_content("text/plain; charset=utf-8")
	luci.sys.process.exec(cmd, http.write)
end

function action_firmware()
	local version = require "8311.version"
	local altversion = {
		variant="unknown",
		version="unknown",
		revision="unknown"
	}

	version.bank = util.trim(util.exec(". /lib/8311.sh && active_fwbank"))
	altversion.bank = util.trim(util.exec(". /lib/8311.sh && inactive_fwbank"))

	for k, v in string.gmatch(util.exec("/usr/sbin/alternate_firmware_info"), '([^\n=]+)=([^\n]+)') do
		if k == "FW_VARIANT" then
			altversion.variant=v
		elseif k == "FW_VERSION" then
			altversion.version=v
		elseif k == "FW_REVISION" then
			altversion.revision=v
		end
	end

	
	local input_field = "firmware_file"
	local location = "/tmp"
	local file_name = "8311-local-upgrade.tar"
	local firmware_file = location .. "/" .. file_name
	local values = luci.http.formvalue()

	if not file_exists(firmware_file) then
		local ul = values[input_field]
	
		if ul ~= '' and ul ~= nil then
			setFileHandler(location, input_field, file_name)
		end
	end

	local firmware_file_exists = file_exists(firmware_file)
	local firmware_exec = nil
	local action = "validate"

	if firmware_file_exists then
		local cmd = {}
		action = values["action"] or "validate"

		if action == "cancel" then
			os.remove(firmware_file)
			firmware_file_exists = false
		elseif action == "install" then
			cmd = { "/usr/sbin/8311-firmware-upgrade.sh", "--yes", "--install", firmware_file }
			firmware_exec = luci.sys.process.exec(cmd, firmwareUpgradeOutput, firmwareUpgradeOutput)
		elseif action == "install_reboot" then
			cmd = { "/usr/sbin/8311-firmware-upgrade.sh", "--yes", "--install", "--reboot", firmware_file }	
			firmware_exec = luci.sys.process.exec(cmd, firmwareUpgradeOutput, firmwareUpgradeOutput)
		elseif action == "reboot" then
			sys.reboot()
		else
			-- validate
			cmd = { "/usr/sbin/8311-firmware-upgrade.sh", "--validate", firmware_file }
			firmware_exec = luci.sys.process.exec(cmd, firmwareUpgradeOutput, firmwareUpgradeOutput)
		end
	end


	ltemplate.render("8311/firmware", {
		version=version,
		altversion=altversion,
		firmware_file_exists=firmware_file_exists,
		firmware_exec=firmware_exec,
		firmware_output=firmwareOutput,
		firmware_action=action
	})
end

function file_exists(filename)
	local fp = io.open(filename, "r")
	if fp ~= nil then
		io.close(fp)
		return true
	else
		return false
	end
end

function firmwareUpgradeOutput(data)
	data = data or ''
	firmwareOutput = firmwareOutput .. data
end

--location: (string) The full path to where the file should be saved.
--input_name: (string) The name specified by the input html field.  <input type="submit" name="input_name_here" value="whatever you want"/>
--file_name: (string, optional) The optional name you would like the file to be saved as. If left blank the file keeps its uploaded name.
function setFileHandler(location, input_name, file_name)
	local fs = require "nixio.fs"
	local fp

	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				-- make sure the field name is the one we want
				if meta and meta.name == input_name then
					-- use the file name if specified
					file_name = file_name or meta.file

					fp = io.open(location .. "/" .. file_name, "w")
				end
			end

			-- actually write the uploaded file
			if chunk then
				fp:write(chunk)
			end

			if eof then
				fp:close()
			end
		end
	)
end
