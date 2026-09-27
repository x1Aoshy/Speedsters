local Availability = {}
-- Only count consecutive unlocks the normal evolve action can currently perform.
function Availability.Count(ordered, owned, level, rebirths)
	local count, first = 0, nil
	for _, suit in ordered do
		if not owned[suit.Id] then
			if level < (suit.RequiredLevel or 0) or rebirths < (suit.RequiredRebirths or 0) then break end
			count += 1
			first = first or suit.Id
		end
	end
	return count, first
end
return Availability
