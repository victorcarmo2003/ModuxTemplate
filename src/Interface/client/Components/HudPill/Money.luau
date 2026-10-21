--!strict
-- Money text for the HUD and the shift summary: 1234 -> "$1,234"; negative -> "-$20".
-- Whole dollars only (FEAT-014: "dinheiro inteiro").

local function digits(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	while true do
		const replaced, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return text
end

return function(value: number): string
	return (if value < 0 then "-$" else "$") .. digits(value)
end
