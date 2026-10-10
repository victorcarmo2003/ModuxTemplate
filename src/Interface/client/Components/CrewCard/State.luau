--!strict
-- What the "Crew" screen shows for one class (TASK-020; DEC-186, FEAT-028). Pure: no Vide, no network.
-- The client only presents: every value comes from the Profile packet, the server decides Buy and Select.
--   Selected  owned and the current SelectedClass
--   Owned     owned, can be selected
--   Buy       not owned, the player has the gems
--   NoGems    not owned, not enough gems (Buy disabled, TASK-020 acceptance)

export type State = "Selected" | "Owned" | "Buy" | "NoGems"

-- Main button of the screen for the focused class. `Enabled = false` never fires anything.
export type Button = {
	Text: string,
	Enabled: boolean,
	Kind: "Accent" | "Done" | "Off",
}

const State = {}

function State.Of(owned: boolean, selected: boolean, gems: number, price: number): State
	if owned then
		return if selected then "Selected" else "Owned"
	end
	return if gems >= price then "Buy" else "NoGems"
end

-- Text of the price/status tag on a card (placeholder text, ui-text.md has no "Crew" section yet).
function State.Tag(state: State, price: number): string
	if state == "Selected" then
		return "Selected"
	elseif state == "Owned" then
		return "Owned"
	end
	return `{price} Gems`
end

-- `busy`: a request is on its way (or the profile has not arrived): nothing can be pressed.
function State.Button(state: State, price: number, busy: boolean): Button
	if busy then
		return { Text = "...", Enabled = false, Kind = "Off" }
	elseif state == "Selected" then
		return { Text = "Selected", Enabled = false, Kind = "Done" }
	elseif state == "Owned" then
		return { Text = "Select", Enabled = true, Kind = "Accent" }
	elseif state == "Buy" then
		return { Text = `Buy · {price} Gems`, Enabled = true, Kind = "Accent" }
	end
	return { Text = `Need {price} Gems`, Enabled = false, Kind = "Off" }
end

return table.freeze(State)
