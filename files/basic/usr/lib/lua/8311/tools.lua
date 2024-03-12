
local require = require

module "8311.tools"

local util = require "luci.util"

function html_escape(text)
	if text == nil then text = "" end

	return text:gsub("%S+", {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&#039;"
	})
end

function fw_getenv(key)
	return util.trim(util.exec("fw_printenv -n " .. util.shellquote(key) .. " 2>/dev/null"))
end

function fw_getenv_8311(key)
	return fw_getenv("8311_" .. key)
end

function fw_setenv(key, value)
	if not key then return false end

	for i=0,1 do
		util.exec("fw_setenv " .. util.shellquote(key) .. " " .. util.shellquote(value))
	end
end

function fw_setenv_8311(key, value)
	return fw_setenv("8311_" .. key, value)
end
