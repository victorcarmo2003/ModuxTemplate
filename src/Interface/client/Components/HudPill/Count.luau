--!strict
-- Count text with thousands separators: 20000 -> "20,000" (gem prices and balances, TASK-308: the x75 gem economy).
-- Whole numbers only; negative keeps the sign.

return function(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	while true do
		const replaced, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return (if value < 0 then "-" else "") .. text
end
