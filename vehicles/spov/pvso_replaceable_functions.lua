--[[
	Functions placed here are in key locations in the pvso where I believe people would want to place vso specific actions
	these will typically be empty, but are called at points in the main loop

	they're meant to be replaced in the vso itself to have it have said specific actions happen
]]
---------------------------------------------------------------------------------------------------------------------------------

-- to have something in the main loop rather than a state loop
function p.update(dt)
end

-- the standard state called when a state's script is undefined
function p.standardState()
end

-- the pathfinding function called if a state doesn't have its own pathfinding script
function p.pathfinding(dt)
end

-- for letting out prey, some VSOs might wand more specific logic regarding this
function p.letout(id)
	local id = id
	if id == nil then
		id = p.occupant[p.occupants.total].id
	end
	return p.doTransition( "escape", {id = id} )
end

-- warp in/out effect should be replaceable if needed
function p.warpInEffect()
	world.spawnProjectile( "vsowarpineffect", mcontroller.position(), entity.id(), {0,0}, true)
end
function p.warpOutEffect()
	world.spawnProjectile( "vsowarpouteffect", mcontroller.position(), p.driver or entity.id(), {0,0}, true)
end

-- each VSO may need to modify which tags are replaced when getting smolpreydata
function p.fixSmolPreyPathTags(path, skin, settings)
	return p.directoryPath..sb.replaceTags(path, {
		skin = skin,
		fullbrightDirectives = settings.fullbrightDirectives or "",
		directives = settings.directives or "",
		bap = "",
		frame = "1",
		bellyoccupants = "0",
		cracks = tostring(settings.cracks) or "0"
	})
end


---------------------------------------------------------------------------------------------------------------------------------
--[[these are called when handling the effects applied to the occupants, called for each one and give the occupant index,
the entity id, health, and the status checked in the options]]

-- to have any extra effects applied to those in digest locations
function p.extraBellyEffects(i, eid, health, status)
end

-- to have effects applied to other locations, for example, womb if the vso does unbirth
function p.otherLocationEffects(i, eid, health, status)
end

---------------------------------------------------------------------------------------------------------------------------------
