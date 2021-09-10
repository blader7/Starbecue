function init()
end

function update(dt)
	if player.isLounging() then
		storage.timeUntilUnlock = 0.5
	end
	if player.getProperty( "vsoSeatType") ~= storage.lockType then
		if storage.lockType == "driver" then
			storage.lockType = player.getProperty( "vsoSeatType")
		else
			storage.timeUntilUnlock = 0
		end
	end
	if storage.timeUntilUnlock <= 0 then
		local clean
		while clean ~= true do
			clean = true
			local lockedItemList = player.getProperty("vsoLockedItems")
			for i, lockedItemData in pairs(lockedItemList) do
				player.giveItem(lockedItemData)
				table.remove(lockedItemList, i)
				clean = false
			end

			player.setProperty("vsoLockedItems", lockedItemList)

			if clean then
				for slotname, itemDescriptor in pairs(storage.lockedEssentialItems) do
					player.giveEssentialItem(slotname, itemDescriptor)
				end
			end
		end
	else
		storage.timeUntilUnlock = storage.timeUntilUnlock - dt
	end
end
