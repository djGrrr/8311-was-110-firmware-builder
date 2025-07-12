local require = require
local string = string
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local pairs = pairs

module "8311.tools"

local util = require "luci.util"
local math = require "math"
local fs = require "nixio.fs"
local bit = require "nixio.bit"
local table = require "table"

function html_escape(text)
	if text == nil then text = "" end
	text = "" .. text

	return text:gsub("%S+", {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&#039;"
	})
end

function nl2br(text)
	if text == nil then text = "" end
	return string.gsub("" .. text, "\n", "<br />\n")
end

function fw_getenv(t)
	setmetatable(t, {__index={key=nil, default=nil, base64=false}})

	return fwenv_get(
		t[1] or t.key,
		t[2] or t.default,
		false,
		t[3] or t.base64
	)
end

function fw_getenv_8311(t)
	setmetatable(t, {__index={key=nil, default=nil, base64=false}})

	return fwenv_get(
		t[1] or t.key,
		t[2] or t.default,
		true,
		t[3] or t.base64
	)
end

function fwenv_get(key, default, _8311, base64)
	if not key then return false end

	local _8311_arg, base64_arg, default_arg = "", "", ""
	if _8311 then _8311_arg = "--8311 " end
	if base64 then base64_arg = "--base64 " end
	if default then default_arg = " " .. util.shellquote(default) end

	return string.gsub(util.exec("fwenv_get " .. _8311_arg .. base64_arg .. util.shellquote(key) .. default_arg), '[\r\n]+$', "")
end

function fw_getenvs_8311()
	local fwenvs = {}
	for k, v in string.gmatch(util.exec('echo ; fw_printenv | grep "^8311_"'), '\n8311_([^\n=]+)=([^\r\n]+)') do
		fwenvs[k] = v
	end

	return fwenvs
end

function fw_setenv(t)
	setmetatable(t, {__index={key=nil, value=nil, base64=false}})

	return fwenv_set(
		t[1] or t.key,
		t[2] or t.value,
		false,
		t[3] or t.base64
	)
end

function fw_setenv_8311(t)
	setmetatable(t, {__index={key=nil, value=nil, base64=false}})

	return fwenv_set(
		t[1] or t.key,
		t[2] or t.value,
		true,
		t[3] or t.base64
	)
end

function fwenv_set(key, value, _8311, base64)
	if not key then return false end

	local _8311_arg, base64_arg = "", ""
	if _8311 then _8311_arg = "--8311 " end
	if base64 then base64_arg = "--base64 " end

	util.exec("fwenv_set " .. _8311_arg .. base64_arg .. util.shellquote(key) .. " " .. util.shellquote(value))
end

function number_format(number, decimals)
	return string.format("%." .. decimals .."f", number)
end

function metrics()
        local _, _, ploam_status = string.find(util.exec("pon psg"):trim(), " current=(%d+) ")
        local cpu1_temp = (tonumber((fs.readfile("/sys/class/thermal/thermal_zone0/temp") or ""):trim()) or 0) / 1000
        local cpu2_temp = (tonumber((fs.readfile("/sys/class/thermal/thermal_zone1/temp") or ""):trim()) or 0) / 1000

        local eep51 = fs.readfile("/sys/class/pon_mbox/pon_mbox0/device/eeprom51", 256)

        local optic_temp = eep51:byte(97) + eep51:byte(98) / 256
        local voltage = (bit.lshift(eep51:byte(99), 8) + eep51:byte(100)) / 10000
        local tx_bias = (bit.lshift(eep51:byte(101), 8) + eep51:byte(102)) / 500
        local tx_mw = (bit.lshift(eep51:byte(103), 8) + eep51:byte(104)) / 10000
        local rx_mw = (bit.lshift(eep51:byte(105), 8) + eep51:byte(106)) / 10000

	return {
		ploam_state = (tonumber(ploam_status) or 0),
		rx_power_dBm = 10 * math.log10(rx_mw),
		tx_power_dBm = 10 * math.log10(tx_mw),
		cpu1_tempC = cpu1_temp,
		cpu2_tempC = cpu2_temp,
		optic_tempC = optic_temp,
		tx_bias_mA = tx_bias,
		module_voltage = voltage,
	}
end

function sorted_keys(t)
	local tkeys = {}
	-- populate the table that holds the keys
	for k in pairs(t) do table.insert(tkeys, k) end
	-- sort the keys
	table.sort(tkeys)

	return tkeys
end
