-- Красивые числа: 1500 -> 1.5K, 2300000 -> 2.3M.

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

function Format.percent(fraction)
	local percent = fraction * 100
	if percent >= 10 then
		return string.format("%d%%", math.floor(percent + 0.5))
	elseif percent >= 1 then
		return string.format("%.1f%%", percent)
	elseif percent >= 0.01 then
		return string.format("%.2f%%", percent)
	end
	return string.format("1 к %s", Format.number(math.floor(1 / fraction + 0.5)))
end

function Format.time(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
	if hours > 0 then
		return string.format("%d ч %02d мин", hours, minutes % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

return Format
