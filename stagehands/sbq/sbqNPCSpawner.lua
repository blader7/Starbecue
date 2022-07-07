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
		while not gotData do
			local i = math.random(#data)
			if (data[i].spawnOnce and world.getProperty(data[i].npc..data[i].npcTypeName.."Spawned")) or (not checkRequirements(data[i].checkRequirements or {})) then
				table.remove(data,i)
			else
				data = data[i]
				gotData = true
			end
		end

		if not checkRequirements(config.getParameter("checkRequirements") or {}) then return stagehand.die() end

		local npc = data.npc or config.getParameter("npc")
		if type(npc) == "string" then
			local success = pcall(root.assetJson, ("/species/" .. npc .. ".species"))
			if success then
				world.spawnNpc(position, npc, data.npcTypeName or config.getParameter("npcTypeName"), data.npcLevel or config.getParameter("npcLevel") or world.threatLevel(), data.npcSeed or config.getParameter("npcSeed"), data.npcParameters or config.getParameter("npcParameters"))
				world.setProperty( npc..(data.npcTypeName or config.getParameter("npcTypeName")).."Spawned", true)

			end
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
