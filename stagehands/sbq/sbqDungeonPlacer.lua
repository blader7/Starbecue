---@diagnostic disable: undefined-field
function update()
	local position = stagehand.position()
	if world.regionActive({position[1]-1,position[2]-1,position[1]+1,position[2]+1}) then

		local data = config.getParameter("randomSelection") or {}
		if type(data) == "string" then
			data = root.assetJson(data)
		end
		local gotData = false
		if data[1] == nil then
			gotData = true
		end
		while not gotData and data[1] ~= nil do
			local i = math.random(#data)
			if data[i].dungeon and (data[i].spawnOnce and world.getProperty(data[i].dungeon.."Placed")) or (not checkRequirements(data[i].checkRequirements or {})) then
				table.remove(data,i)
			else
				data = data[i]
				gotData = true
			end
		end

		if not checkRequirements(config.getParameter("checkRequirements") or {}) then return stagehand.die() end

		local dungeon = data.dungeon or config.getParameter("dungeon")
		if type(dungeon) == "string" then
			local offset = data.placeOffset or config.getParameter("placeOffset") or {0,0}
			world.setTileProtection( data.dungeonId or config.getParameter("dungeonId") or 0, data.protect or config.getParameter("protect") or false )
			world.placeDungeon( dungeon, {position[1]+offset[1],position[2]+offset[2]}, data.dungeonId or config.getParameter("dungeonId") or 0 )
			world.setProperty( dungeon.."Placed", true)
		end
		stagehand.die()
	end
end

function checkRequirements(data)
	if data.checkItems then
		for i, item in ipairs(data.checkItems) do
			if not root.itemConfig(item) then return end
		end
	end
	if data.checkJson then
		if not pcall(root.assetJson, data.checkJson) then return end
	end
	if data.checkImage then
		success, notEmpty = pcall(root.nonEmptyRegion, data.checkImage)
		if not (success and notEmpty ~= nil) then return end
	end
	return true
end
