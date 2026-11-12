-- Pretty numbers: 1500 -> 1.5K, 2300000 -> 2.3M.

local S = require(script.Parent.Parent.Strings)

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.number(value)
	value = tonumber(value) or 0
	local negative = value < 0
	value = math.abs(value)

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text
	if index == 1 then
		text = tostring(math.floor(value))
	elseif value >= 100 then
		text = string.format("%d%s", math.floor(value), SUFFIXES[index])
	elseif value >= 10 then
		text = string.format("%.1f%s", math.floor(value * 10) / 10, SUFFIXES[index])
	else
		text = string.format("%.2f%s", math.floor(value * 100) / 100, SUFFIXES[index])
	end

	text = text:gsub("%.0+(%a)", "%1"):gsub("(%.%d-)0+(%a)", "%1%2")
	return (negative and "-" or "") .. text
end

function Format.coins(value)
	return "$" .. Format.number(value)
end

-- The chance is always in percent: Roblox does not accept "1 in N". Long fractions are rounded to 4 digits
-- after the first significant digit, and the odds.rounded note stands next to such chances.
function Format.percent(fraction)
	local percent = fraction * 100
	if percent <= 0 then
		return "0%"
	end
	local decimals = math.max(0, 4 - math.floor(math.log10(percent)))
	local text = string.format("%." .. decimals .. "f", percent)
	if decimals > 0 then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. "%"
end

function Format.time(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
	if hours > 0 then
		return S.t("format.hours", { hours = hours, minutes = string.format("%02d", minutes % 60) })
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

-- Short timers for the HUD plates, where a line holds about 15 letters on a phone (tests/layout.spec.luau):
-- timer "m:ss" or "h:mm:ss", clock "h:mm" (hours and minutes, for "come back in 23:59").
function Format.timer(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, math.floor(seconds / 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Format.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
end

return Format
