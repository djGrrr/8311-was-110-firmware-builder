
local require = require
local string = string
local setmetatable = setmetatable

module "8311.tools"

local util = require "luci.util"

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

	return util.trim(util.exec("fwenv_get " .. _8311_arg .. base64_arg .. util.shellquote(key) .. default_arg))
end

function fw_getenvs_8311()
	local fwenvs = {}
	for k, v in string.gmatch(util.exec('echo ; fw_printenv | grep "^8311_"'), '\n8311_([^\n=]+)=([^\n]+)') do
		fwenvs[k] = util.trim(v)
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
