--This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 2.0 Generic License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
--https://creativecommons.org/licenses/by-nc-sa/2.0/  @

state = {}
controls = {}

p = {
	maxOccupants = { --basically everything I think we'd need
		total = 0
	},
	occupants = {
		total = 0
	},
	occupant = {},
	occupantOffset = 1,
	justAte = false,
	justLetout = false,
	monstercoords = {0,0},
	nextIdle = 0,
	swapCooldown = 0
}

p.settings = {}

p.movement = {
	jumps = 0,
	jumped = false,
	waswater = false,
	bapped = 0,
	downframes = 0,
	spaceframes = 0,
	groundframes = 0,
	airframes = 0,
	run = false,
	wasspecial1 = 10, -- Give things time to finish initializing, so it realizes you're holding special1 from spawning vap instead of it being a new press
	E = false,
	wasE = false,
	primaryCooldown = 0,
	altCooldown = 0,
	lastYVelocity = 0
}

p.clearOccupant = {
	id = nil,
	loungeStatList = {},
	statList = {},
	statPower = {},
	visible = nil,
	location = nil,
	species = nil,
	filepath = nil
}

p.clearSeat = {
	dx = 0,
	dy = 0,
	left = 0,
	right = 0,
	up = 0,
	down = 0,
	jump = 0,
	special1 = 0,
	special2 = 0,
	special3 = 0,
	species = nil,
	mass = 0,
	primaryHandItem = nil,
	altHandItem = nil,
	head = nil,
	chest = nil,
	legs = nil,
	back = nil,
	headCosmetic = nil,
	chestCosmetic = nil,
	legsCosmetic = nil,
	backCosmetic = nil,
	powerMultiplier = 1
}

require("/vehicles/spov/pvso_animation.lua")
require("/vehicles/spov/pvso_state_control.lua")
require("/vehicles/spov/pvso_driving.lua")
require("/vehicles/spov/pvso_replaceable_functions.lua")

function init()
	p.vso = config.getParameter("vso")
	p.directoryPath = config.getParameter("directoryPath")
	p.cfgAnimationFile = config.getParameter("animation")
	p.victimAnimations = root.assetJson(p.vso.victimAnimations)
	p.stateconfig = config.getParameter("states")
	p.loungePositions = config.getParameter("loungePositions")
	p.animStateData = root.assetJson( p.directoryPath .. p.cfgAnimationFile ).animatedParts.stateTypes
	p.config = root.assetJson( "/vehicles/spov/pvso_general.config")
	p.transformGroups = root.assetJson( p.directoryPath .. p.cfgAnimationFile ).transformationGroups
	p.settings = config.getParameter( "settings", p.config.defaultSettings )
	p.spawner = config.getParameter("spawner")
	p.movementParams = "default"
	p.faceDirection(config.getParameter("direction", 1))

	p.resetOccupantCount()

	for i = 1, p.vso.maxOccupants.total do
		p.occupant[i] = p.clearOccupant
	end

	for _, state in pairs(p.animStateData) do
		state.animationState = {
			anim = state.default,
			priority = state.states[state.default].priority,
			cycle = state.states[state.default].cycle,
			frames = state.states[state.default].frames,
			time = 0,
			queue = {},
		}
		state.tag = nil
		state.victimAnim = {
			done = true
		}
	end

	for seatname, data in pairs(p.loungePositions) do
		controls[seatname] = p.clearSeat
	end

	if not config.getParameter( "uneaten" ) then
		world.spawnProjectile( "spovwarpineffectprojectile", mcontroller.position(), entity.id(), {0,0}, true) --Play warp in effect
	end

	local driver = config.getParameter( "driver" )
	if driver ~= nil then
		p.standalone = true
		p.driverSeat = "driver"
		p.driving = true
		p.forceSeat( driver, "driver" )
		p.spawner = driver
	else
		p.standalone = false
		p.driverSeat = "occupant1"
		p.driving = false
		vehicle.setLoungeEnabled( "driver", false )
	end
	p.spawnerUUID = world.entityUniqueId(p.spawner)

	if entity.uniqueId() ~= nil then
		world.setUniqueId(entity.id(), sb.makeUuid())
		sb.logInfo("uuid"..entity.uniqueId())
	end

	p.onForcedReset()	--Do a forced reset once.

	message.setHandler( "settingsMenuSet", function(_,_, val )
		p.settings = val
	end )

	message.setHandler( "letout", function(_,_, val )
		p.doTransition( "escape", {index = val} )
	end )

	message.setHandler( "settingsMenuRefresh", function(_,_)
		return p.getSettingsMenuInfo()
	end )

	message.setHandler( "despawn", function(_,_, nowarpout)
		local driver = vehicle.entityLoungingIn(p.driverSeat)
		if driver then
			world.sendEntityMessage(driver, "PVSOClear")
		end
		p.nowarpout = nowarpout
		p.onDeath()
	end )

	message.setHandler( "digest", function(_,_, eid)
		local i = p.getOccupantFromEid(eid)
		local location = p.occupant[i].location
		p.doTransition("digest"..location)
	end )

	message.setHandler( "uneat", function(_,_, eid)
		local i = p.getOccupantFromEid(eid)
		p.occupant[i] = p.clearOccupant
		p.unForceSeat( "occupant"..i)
	end )

	message.setHandler( "smolPreyPath", function(_,_, seatindex, path)
		p.occupant[seatindex].filepath = path
		p.smolprey()
	end )

	p.state = "" -- if its nil when setState is called it causes problems, empty string is the next best thing
	if not config.getParameter( "uneaten" ) then
		if not p.vso.startState then
			p.vso.startState = "stand"
		end
		p.setState( p.vso.startState )
		p.doAnims( p.stateconfig[p.vso.startState].idle, true )
	else -- released from larger pred
		p.setState( "smol" )
		p.doAnims( p.stateconfig.smol.idle, true )
	end

	local v_status = vehicle.setLoungeStatusEffects -- has to be in here instead of root because vehicle is nil before init
	vehicle.setLoungeStatusEffects = function(seatname, effects)
		local eid = vehicle.entityLoungingIn(seatname)
		local seatindex = p.getOccupantFromEid(eid)
		local smolprey
		if seatname ~= "driver" then
			smolprey = p.occupant[seatindex].species
		end
		if smolprey or p.isMonster(eid) then -- fix invis on smolprey too
			local invis = false
			local effects2 = {} -- don't touch outer table
			for _,e in ipairs(effects) do
				if e == "pvsoinvisible" then invis = true end
				table.insert(effects2, e)
			end
			if invis then
				animator.setAnimationState( seatname.."state", "empty" )
			elseif smolprey then
				animator.setAnimationState( seatname.."state", "smol" )
				table.insert(effects2, "vsoinvisible")
			elseif p.isMonster(eid) then
				animator.setAnimationState( seatname.."state", "monster" )
				table.insert(effects2, "vsoinvisible")
			end
			v_status(seatname, effects2)
		else
			v_status(seatname, effects)
		end
	end

	onBegin()
end

p.totalTimeAlive = 0
function update(dt)
	p.checkSpawnerExists()
	p.totalTimeAlive = p.totalTimeAlive + dt
	p.dt = dt
	p.updateAnims(dt)
	p.checkRPCsFinished(dt)
	p.checkTimers(dt)
	p.idleStateChange(dt)
	p.updateControls(dt)
	if p.driving then
		p.drive()
		p.driverSeatStateChange()
	end
	p.updateDriving()
	p.whenFalling()
	p.handleBelly()
	p.applyStatusLists()

	p.emoteCooldown = p.emoteCooldown - dt
	p.updateState()
	p.update(dt)
end

function uninit()
	if mcontroller.atWorldLimit()
	--or (world.entityHealth(entity.id()) <= 0) -- vehicles don't have health?
	then
		p.onDeath()
	end
end

p.dtSinceList = {}
function p.dtSince(name) -- used for when something isn't in the main update loop but knowing the dt since it was last called is good
	local last = p.dtSinceList[name] or p.totalTimeAlive
	p.dtSinceList[name] = p.totalTimeAlive
	return p.totalTimeAlive - last
end

function p.facePoint(x)
	p.faceDirection(x - mcontroller.position()[1])
end

function p.faceDirection(x)
	if x > 0 then
		p.direction = 1
		animator.setFlipped(false)
	elseif x < 0 then
		p.direction = -1
		animator.setFlipped(true)
	end
	p.setMovementParams(p.movementParams)
end

function p.setMovementParams(name)
	p.movementParams = name
	local params = p.vso.movementSettings[name]
	if params.flip then
		for _, coords in ipairs(params.collisionPoly) do
			coords[1] = coords[1] * p.direction
		end
	end
	mcontroller.applyParameters(params)
end

function p.checkSpawnerExists()
	if world.entityExists(p.spawner) then
	elseif (p.spawnerUUID ~= nil) and (p.waitingResponse == nil)then
		p.waitingResponse = true
		p.addRPC(world.sendEntityMessage(p.spawnerUUID, "pvsoPreyWarpRequest"), function(data)
			p.waitingResponse = false
		end)
	else
		p.onDeath()
	end
end

function p.onForcedReset()
	animator.setAnimationRate( 1.0 );
	for i = 1, p.vso.maxOccupants.total do
		vehicle.setLoungeEnabled( "occupant"..i, false )
	end

	vehicle.setInteractive( true )

	p.emoteCooldown = 0

	onForcedReset()
end

function p.onDeath()
	world.sendEntityMessage(p.spawner, "saveVSOsettings", p.settings)

	if not p.nowarpout then
		world.spawnProjectile( "spovwarpouteffectprojectile", mcontroller.position(), entity.id(), {0,0}, true)
	end

	onEnd()
	vehicle.destroy()
end

p.rpcList = {}
function p.addRPC(rpc, callback, name)
	if callback ~= nil and name == nil then
		table.insert(p.rpcList, {rpc = rpc, callback = callback, dt = 0})
	elseif p.rpcList[name] == nil then
		p.rpcList[name] = {rpc = rpc, callback = callback, dt = 0}
	end
end

function p.checkRPCsFinished(dt)
	for name, list in pairs(p.rpcList) do
		list.dt = list.dt + dt -- I think this is good to have, incase the time passed since the RPC was put into play is important
		if list.rpc:finished() then
			list.callback(list.rpc:result(), list.dt)
			-- not quite sure if what is below is what I should be doing
			if type(name) == number then
				table.remove(p.rpcList, name)
			else
				p.rpcList[name] = nil
			end
		end
	end
end

p.timerList = {}

function p.randomTimer(name, min, max, callback)
	if name == nil or p.timerList[name] == nil then
		local timer = {
			targetTime = (math.random(min * 100, max * 100))/100,
			currTime = 0,
			callback = callback
		}
		if name ~= nil then
			p.timerList[name] = timer
		else
			table.insert(p.timerList, timer)
		end
	end
end

function p.timer(name, time, callback)
	if name == nil or p.timerList[name] == nil then
		local timer = {
			targetTime = time,
			currTime = 0,
			callback = callback
		}
		if name ~= nil then
			p.timerList[name] = timer
		else
			table.insert(p.timerList, timer)
		end
	end
end

function p.checkTimers(dt)
	for name, timer in pairs(p.timerList) do
		timer.currTime = timer.currTime + dt
		if timer.currTime >= timer.targetTime then
			if timer.callback ~= nil then
				timer.callback()
			end
			if type(name) == "number" then
				table.remove(p.timerList, name)
			else
				p.timerList[name] = nil
			end
		end
	end
end

function p.applyStatusLists()
	for i = 1, p.occupants.total do
		for j = 1, #p.occupant[i].statList[j] do
			world.sendEntityMessage( p.occupant[i].id, "applyStatusEffect", p.occupant[i].statList[j], p.occupant[i].statPower[j], entity.id() )
		end
		vehicle.setLoungeStatusEffects( "occupant"..i, p.occupant[i].loungeStatList )
	end
end

function p.applyStatusEffects(eid, statuses)
	for i = 1, #statuses do
		world.sendEntityMessage(eid, "applyStatusEffect", statuses[i][1], statuses[i][2], entity.id())
	end
end

function p.addStatusToList(index, status, power)
	local power = power
	for i = 1, #p.occupant[index].statList do
		if p.occupant[index].statList[i] == status then
			if power then
				p.occupant[index].statPower[i] = power
			end
			return
		end
	end
	if not power then
		power = 1
	end
	table.insert(p.occupant[index].statList, status)
	table.insert(p.occupant[index].statPower, power)
end

function p.addLoungeStatusToList(index, status)
	for i = 1, #p.occupant[index].loungeStatList do
		if p.occupant[index].loungeStatList[i] == status then
			return
		end
	end
	table.insert(p.occupant[index].loungeStatList, status)
end

function p.removeLoungeStatusFromList(index, status)
	for i = 1, #p.occupant[index].loungeStatList do
		if p.occupant[index].loungeStatList[i] == status then
			table.remove(p.occupant[index].loungeStatList, i)
			return
		end
	end
end

function p.removeStatusFromList(index, status)
	for i = 1, #p.occupant[index].statList do
		if p.occupant[index].statList[i] == status then
			table.remove(p.occupant[index].statList, i)
			table.remove(p.occupant[index].statPower, i)
			return
		end
	end
end

function p.forceSeat( occupantId, seatname )
	if occupantId then
		world.sendEntityMessage( occupantId, "applyStatusEffect", "pvsoremoveforcesit", 1, entity.id())

		vehicle.setLoungeEnabled(seatname, true)
		local seat = 0
		if seatname ~= "driver" then
			seat = tonumber(seatname:sub(#"occupant"+1))
		end
		world.sendEntityMessage( occupantId, "applyStatusEffect", "pvsoforcesit", seat + 1, entity.id())
	end
end

function p.unForceSeat(seatname)
	local occupantId = vehicle.entityLoungingIn( seatname )
	vehicle.setLoungeEnabled(seatname, false)
	if occupantId then
		world.sendEntityMessage( occupantId, "applyStatusEffect", "pvsoremoveforcesit", 1, entity.id())
	end
end

function p.locationFull(location)
	if p.occupants.total == p.vso.maxOccupants.total then
		--sb.logInfo("["..p.vso.menuName.."] Can't have more than "..p.vso.maxOccupants.total.." occupants total!")
		return true
	else
		return p.occupants[location] == p.vso.maxOccupants[location]
		--[[if p.occupants[location] == p.vso.maxOccupants[location] then
			--sb.logInfo("["..p.vso.menuName.."] Can't have more than "..p.vso.maxOccupants[location].." occupants in their "..location.."!")
			return true
		else
			return false
		end]]
	end
end

function p.locationEmpty(location)
	if p.occupants.total == 0 then
		--sb.logInfo( "["..p.vso.menuName.."] No one to let out!" )
		return true
	else
		return p.occupants[location] == 0
		--[[if p.occupants[location] == 0 then
			sb.logInfo( "["..p.vso.menuName.."] No one in "..location.." to let out!" )
			return true
		else
			return false
		end]]
	end
end

function p.doVore(args, location, statuses, sound )
	local i = p.occupants.total + 1
	if p.eat( args.id, i, location ) then
		vehicle.setInteractive( false )
		p.showEmote("emotehappy")
		--vsoVictimAnimSetStatus( "occupant"..i, statuses );
		return true, function()
			vehicle.setInteractive( true )
			if sound then animator.playSound( sound ) end
		end
	else
		return false
	end
end

function p.doEscape(args, location, monsteroffset, statuses, afterstatus )
	p.monstercoords = p.localToGlobal(monsteroffset)--same as last bit of escape anim

	if p.locationEmpty(location) then return false end
	local i = args.index
	local victim = p.occupant[i].id

	if not victim then -- could be part of above but no need to log an error here
		return false
	end
	vehicle.setInteractive( false )
	--vsoVictimAnimSetStatus( "occupant"..i, statuses );

	return true, function()
		vehicle.setInteractive( true )
		p.uneat( i )
		world.sendEntityMessage( victim, "applyStatusEffect", afterstatus.status, afterstatus.duration, entity.id() )
	end
end

function p.doEscapeNoDelay(args, location, monsteroffset, afterstatus )
	p.monstercoords = p.localToGlobal(monsteroffset)--same as last bit of escape anim

	if p.locationEmpty(location) then return false end
	local i = args.index
	local victim = p.occupant[i].id

	if not victim then -- could be part of above but no need to log an error here
		return false
	end

	vehicle.setInteractive( true )
	p.uneat( i )
	world.sendEntityMessage( victim, "applyStatusEffect", afterstatus.status, afterstatus.duration, entity.id() )
end


function p.checkEatPosition(position, location, transition, noaim)
	if not p.locationFull(location) then
		local prey = world.entityQuery(position, 2, {
			withoutEntityId = vehicle.entityLoungingIn(p.driverSeat),
			includedTypes = {"creature"}
		})
		local entityaimed = world.entityQuery(vehicle.aimPosition(p.driverSeat), 2, {
			withoutEntityId = vehicle.entityLoungingIn(p.driverSeat),
			includedTypes = {"creature"}
		})
		local aimednotlounging = p.firstNotLounging(entityaimed)

		if #prey > 0 then
			for i = 1, #prey do
				if ((prey[i] == entityaimed[aimednotlounging]) or noaim) and not p.entityLounging(prey[i]) then
					animator.setGlobalTag( "bap", "" )
					p.doTransition( transition, {id=prey[i]} )
					return true
				end
			end
		end
		return false
	end
end

function p.firstNotLounging(entityaimed)
	for i = 1, #entityaimed do
		if not p.entityLounging(entityaimed[i]) then
			return i
		end
	end
end

function p.moveOccupantLocation(args, part, location)
	if p.locationFull(location) then return false end
	p.occupant[args.index].location = location
	return true
end

function p.findFirstIndexForLocation(location)
	for i = 1, p.occupants.total do
		if p.occupant[i].location == location then
			return i
		end
	end
	return
end

function p.showEmote( emotename ) --helper function to express a emotion particle "emotesleepy","emoteconfused","emotesad","emotehappy","love"
	if p.emoteCooldown < 0 then
		animator.setParticleEmitterBurstCount( emotename, 1 );
		animator.burstParticleEmitter( emotename )
		p.emoteCooldown = 0.2; -- seconds
	end
end
function p.resetOccupantCount()
	p.occupants.total = 0
	for i = 1, #p.vso.locations.regular do
		p.occupants[p.vso.locations.regular[i]] = 0
	end
	if p.vso.locations.sided then
		for i = 1, #p.vso.locations.sided do
			p.occupants[p.vso.locations.sided[i].."R"] = 0
			p.occupants[p.vso.locations.sided[i].."L"] = 0
		end
	end
	p.occupants.fatten = p.settings.fatten or 0
	p.occupants.mass = 0
end

function p.updateOccupants()
	p.resetOccupantCount()

	local lastFilled = true
	for i = 1, p.vso.maxOccupants.total do
		local occupantId = p.occupant[i].id
		if occupantId and world.entityExists(occupantId) then
			p.occupants.total = p.occupants.total + 1
			p.occupants[p.occupant[i].location] = p.occupants[p.occupant[i].location] + 1

			for _, location in ipairs(p.vso.locations.mass) do
				if location == p.occupant[i].location then
					p.occupants.mass = p.occupants.mass + controls["occupant"..i].mass
				end
			end

			if not lastFilled and p.swapCooldown <= 0 then
				p.swapOccupants( i-1, i )
			end
			lastFilled = true
		else
			p.occupant[i] = p.clearOccupant
			lastFilled = false
			animator.setAnimationState( "occupant"..i.."state", "empty" )
		end
	end
	p.swapCooldown = math.max(0, p.swapCooldown - 1)

	for _, location in ipairs(p.vso.locations.mass) do
		if location == "fatten" then
			p.occupants.mass = p.occupants.mass + p.occupants.fatten
		end
	end

	for _, combine in ipairs(p.vso.locations.combine) do
		for j = 2, #combine do
			p.occupants[combine[1]] = p.occupants[combine[1]]+p.occupants[combine[j]]
			if p.occupants[combine[1]] > p.vso.maxOccupants[combine[1]] then
				p.occupants[combine[1]] = p.vso.maxOccupants[combine[1]]
			end
			p.occupants[combine[j]] = p.occupants[combine[1]]
		end
	end

	mcontroller.applyParameters({mass = p.vso.movementSettings[p.movementParams].mass + p.occupants.mass})

	animator.setGlobalTag( "totaloccupants", tostring(p.occupants.total) )
	for i = 1, #p.vso.locations.regular do
		animator.setGlobalTag( p.vso.locations.regular[i].."occupants", tostring(p.occupants[p.vso.locations.regular[i]]) )
	end

	if p.vso.locations.sided then
		for i = 1, #p.vso.locations.sided do
			if p.direction >= 1 then -- to make sure those in the balls in CV and breasts in BV cases stay on the side they were on instead of flipping
				animator.setGlobalTag( p.vso.locations.sided[i].."2occupants", tostring(p.occupants[p.vso.locations.sided[i].."R"]) )
				animator.setGlobalTag( p.vso.locations.sided[i].."1occupants", tostring(p.occupants[p.vso.locations.sided[i].."L"]) )
			else
				animator.setGlobalTag( p.vso.locations.sided[i].."1occupants", tostring(p.occupants[p.vso.locations.sided[i].."R"]) )
				animator.setGlobalTag( p.vso.locations.sided[i].."2occupants", tostring(p.occupants[p.vso.locations.sided[i].."L"]) )
			end
		end
	end
end

function p.localToGlobal( position )
	local lpos = { position[1], position[2] }
	if p.direction == -1 then lpos[1] = -lpos[1] end
	local mpos = mcontroller.position()
	local gpos = { mpos[1] + lpos[1], mpos[2] + lpos[2] }
	return world.xwrap( gpos )
end
function p.globalToLocal( position )
	local pos = world.distance( position, mcontroller.position() )
	if p.direction == -1 then pos[1] = -pos[1] end
	return pos
end

function p.occupantArray( maybearray )
	if maybearray == nil or maybearray[1] == nil then -- not an array, check for eating
		if maybearray.location then
			if maybearray.failOnFull then
				if (maybearray.failOnFull ~= true) and (p.occupants[maybearray.location] >= maybearray.failOnFull) then return maybearray.failTransition
				elseif p.locationFull(maybearray.location) then return maybearray.failTransition end
			else
				if p.locationEmpty(maybearray.location) then return maybearray.failTransition end
			end
		end
		return maybearray
	else -- pick one depending on number of occupants
		return maybearray[(p.occupants[maybearray[1].location or "total"] or 0) + 1]
	end
end

function p.swapOccupants(a, b)
	local A = p.occupant[a]
	local B = p.occupant[b]
	p.occupant[a] = b
	p.occupant[b] = A

	if A then p.unForceSeat( "occupant"..a ) end
	if B then p.unForceSeat( "occupant"..b ) end
	if B then p.forceSeat( B, "occupant"..a ) end
	if A then p.forceSeat( A, "occupant"..b ) end

	p.swapCooldown = 100 -- p.unForceSeat and p.forceSeat are asynchronous, without some cooldown it'll try to swap multiple times and bad things will happen
end

function p.entityLounging( entity )
	if entity == vehicle.entityLoungingIn( "driver" ) then return true end
	for i = 1, p.vso.maxOccupants.total do
		if entity == (vehicle.entityLoungingIn( "occupant"..i ) or p.occupant[i].id) then return true end
	end
	return false
end

function p.edible( occupantId, seatindex, source )
	if vehicle.entityLoungingIn( "driver" ) ~= occupantId then return false end
	if p.occupants.total > 0 then return false end
	if p.stateconfig[p.state].edible then
		if p.stateconfig[p.state].ediblePath then
			world.sendEntityMessage( source, "smolPreyPath", seatindex, p.stateconfig[p.state].ediblePath )
		end
		return true
	end
end

function p.isMonster( id )
	if id == nil then return false end
	if not world.entityExists(id) then return false end
	return world.entityType(id) == "monster"
end

function p.inedible(occupantId)
	for i = 1, #p.config.inedibleCreatures do
		if world.entityType(occupantId) == p.config.inedibleCreatures[i] then return true end
	end
	return false
end

function p.eat( occupantId, seatindex, location )
	if occupantId == nil or p.entityLounging(occupantId) or p.inedible(occupantId) or p.locationFull(location) then return false end -- don't eat self
	local loungeables = world.entityQuery( world.entityPosition(occupantId), 5, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "p.entityLounging", callScriptArgs = { occupantId }
	} )
	local edibles = world.entityQuery( world.entityPosition(occupantId), 2, {
		withoutEntityId = entity.id(), includedTypes = { "vehicle" },
		callScript = "p.edible", callScriptArgs = { occupantId, seatindex, entity.id() }
	} )
	p.occupant[seatindex].location = location

	if edibles[1] == nil then
		if loungeables[1] == nil then -- now just making sure the prey doesn't belong to another loungable now
			p.occupant[seatindex].id = occupantId
			p.smolprey( seatindex )
			p.forceSeat( occupantId, "occupant"..seatindex )
			p.justAte = true
			return true -- not lounging
		else
			return false -- lounging in something inedible
		end
	end
	-- lounging in edible smol thing
	local species = world.entityName( edibles[1] ):sub( 5 ) -- "spov"..species
	p.occupant[seatindex].id = occupantId
	p.occupant[seatindex].species = species
	p.smolprey( seatindex )
	world.sendEntityMessage( edibles[1], "despawn", true ) -- no warpout
	p.forceSeat( occupantId, "occupant"..seatindex )
	p.addStatusToList(seatindex, "vsoinvisible")
	vehicle.setLoungeStatusEffects( "occupant"..seatindex, invis );
	p.justAte = true
	return true
end

function p.uneat( seatindex )
	local occupantId = p.occupant[seatindex].id
	world.sendEntityMessage( occupantId, "PVSOClear")
	world.sendEntityMessage( occupantId, "applyStatusEffect", "pvsoremovebellyEffects")
	p.unForceSeat( "occupant"..seatindex )
	if p.occupant[seatindex].species then
		if world.entityType(occupantId) == "player" then
			world.sendEntityMessage( occupantId, "spawnSmolPrey", p.occupant[seatindex].species )
		else
			world.spawnVehicle( "spov"..p.occupant[seatindex].species, { p.monstercoords[1], p.monstercoords[2]}, { driver = occupantId, settings = {}, uneaten = true } )
		end
		p.occupant[seatindex].species = nil
		p.occupant[seatindex].filepath = nil
	elseif p.isMonster(occupantId) then
		-- do something to move it forward a few blocks
		world.sendEntityMessage( occupantId, "applyStatusEffect", "pvsomonsterbindremove", p.monstercoords[1], p.monstercoords[2]) --this is hacky as fuck I love it
	end
	p.smolprey( seatindex ) -- clear
	p.occupant[seatindex] = p.clearOccupant
end

function p.smolprey( seatindex )
	if seatindex == nil then return end
	local id = p.occupant[seatindex].id
	if p.occupant[seatindex].species ~= nil then
		if p.occupant[seatindex].filepath then
			animator.setPartTag( "occupant"..seatindex, "smolpath", p.occupant[seatindex].filepath)
		else
			animator.setPartTag( "occupant"..seatindex, "smolpath", "/vehicles/spov/"..p.occupant[seatindex].species.."/spov/default/smol/smol_body.png:smolprey")
		end
		animator.setPartTag( "occupant"..seatindex, "smoldirectives", "" ) -- todo eventually, unimportant since there are no directives to set yet
		p.doAnim( "occupant"..seatindex.."state", "smol" )
	elseif p.isMonster(id) then
		local portrait = world.entityPortrait(id, "fullneutral")
		if portrait and portrait[1] and portrait[1].image then
			animator.setPartTag( "occupant"..seatindex, "monster", portrait[1].image )
			p.doAnim( "occupant"..seatindex.."state", "monster" )
		end
	else
		animator.setPartTag( "occupant"..seatindex, "smolspecies", "" )
		animator.setPartTag( "occupant"..seatindex, "smoldirectives", "" )
		p.doAnim( "occupant"..seatindex.."state", "empty" )
	end
end

-------------------------------------------------------------------------------

function p.getOccupantFromEid(eid)
	for i = 1, p.vso.maxOccupants.total do
		if eid == p.occupant[i].id then
			return i
		end
	end
end

-------------------------------------------------------------------------------

function p.getSettingsMenuInfo()
	local occupants = {}
	for i = 1, p.occupants.total do
		if p.occupant[i].id then
			occupants[i] = {
				id = p.occupant[i].id,
				species = p.occupant[i].species
			}
		else
			occupants[i] = {}
		end
	end
	return occupants
end

function p.probablyOnGround() -- check number of frames -> ceiling isn't ground
	local yvel = mcontroller.yVelocity()
	if yvel < 0.1 and yvel > -0.1 then
		p.movement.groundframes = p.movement.groundframes + 1
	else
		p.movement.groundframes = 0
	end
	return p.movement.groundframes > 5
end

function p.notMoving()
	local xvel = mcontroller.xVelocity()
	return xvel < 0.1 and xvel > -0.1
end

function p.underWater()
	return mcontroller.liquidPercentage() >= 0.2
end

function p.useEnergy(eid, cost, callback)
	p.addRPC( world.sendEntityMessage(eid, "useEnergy", cost), callback)
end

-------------------------------------------------------------------------------

function p.handleBelly()
	p.updateOccupants()
	p.handleStruggles()
	if p.occupants.total > 0 and p.stateconfig[p.state].bellyEffect ~= nil then
		local driver = vehicle.entityLoungingIn( "driver")
		if driver ~= nil then
			getDriverStat(driver, "powerMultiplier", function(powerMultiplier)
				p.doBellyEffects(driver, math.log(powerMultiplier)+1)
			end)
		else
			p.doBellyEffects(false, p.standalonePowerLevel())
		end
	end
end

function p.standalonePowerLevel()
	local power = world.threatLevel()
	if type(power) ~= "number" or power < 1 then return 1 end
	return power
end

function p.doBellyEffects(driver, powerMultiplier)
	local status = p.settings.bellyEffect
	local hungereffect = p.settings.hungerEffect

	for i = 1, p.vso.maxOccupants.total do
		local eid = p.occupant[i].id

		if eid and world.entityExists(eid) then
			local health = world.entityHealth(eid)
			local light = p.vso.lights.prey
			light.position = world.entityPosition( eid )
			world.sendEntityMessage( eid, "PVSOAddLocalLight", light )

			if p.isLocationDigest(p.occupant[i].location) then
				if (p.settings.bellySounds == true) and p.randomTimer( "gurgle", 1.0, 8.0 ) then animator.playSound( "digest" ) end
				local hunger_change = (hungereffect * powerMultiplier * p.dt)/100
				if status then world.sendEntityMessage( eid, "applyStatusEffect", status, powerMultiplier, entity.id() ) end
				if (p.settings.bellyEffect == "pvsoSoftDigest" or p.settings.bellyEffect == "pvsoDisplaySoftDigest") and health[1] <= 1 then hunger_change = 0 end
				if driver then p.addHungerHealth( driver, hunger_change) end
				p.extraBellyEffects(i, eid, health, status)
			else
				p.otherLocationEffects(i, eid, health, status)
			end
		end
	end
end

function p.isLocationDigest(location)
	for i = 1, #p.vso.locations.digest do
		if #p.vso.locations.digest[i] == location then
			return true
		end
	end
	return false
end

function p.addHungerHealth(eid, amount, callback)
	p.addRPC( world.sendEntityMessage(eid, "addHungerHealth", amount), callback)
end

p.struggleCount = 0
p.bellySettleDownTimer = 5

function p.handleStruggles()
	p.bellySettleDownTimer = p.bellySettleDownTimer - p.dt
	if p.bellySettleDownTimer <= 0 then
		if p.struggleCount > 0 then
			p.struggleCount = p.struggleCount - 1
			p.bellySettleDownTimer = 3
		end
	end

	local struggler = 0
	local struggledata
	if p.driving and not p.standalone then
		struggler = 1
	end

	local movedir = nil

	while (movedir == nil) and struggler < p.vso.maxOccupants.total do
		struggler = struggler + 1
		movedir = p.getSeatDirections( "occupant"..struggler )
		struggledata = p.stateconfig[p.state].struggle[p.occupant[struggler].location]
		if movedir then
			if (struggledata == nil) or (struggledata[movedir] == nil) then
				movedir = nil
			elseif not p.hasAnimEnded( struggledata.part.."State" )
			and (
				p.animationIs( struggledata.part.."State", "s_up" ) or
				p.animationIs( struggledata.part.."State", "s_front" ) or
				p.animationIs( struggledata.part.."State", "s_back" ) or
				p.animationIs( struggledata.part.."State", "s_down" )
			)then
				movedir = nil
			else
				for i = 1, #p.config.speciesStrugglesDisabled do
					if p.occupant[struggler].species == p.config.speciesStrugglesDisabled[i] then
						movedir = nil
					end
				end
			end
		end
	end
	if movedir == nil then return end -- invalid struggle

	if struggledata.script ~= nil then
		local statescript = p.statestripts[p.state][struggledata.script]
		statescript( struggler, movedir )
	end

	local chance = struggledata.chances
	if struggledata[movedir].chances ~= nil then
		chance = struggledata[movedir].chances
	end
	if chance[p.settings.escapeModifier] ~= nil then
		chance = chance[p.settings.escapeModifier]
	end

	if chance ~= nil and ( chance.max == 0 or (
		(not p.driving or struggledata[movedir].controlled)
		and (math.random(chance.min, chance.max) <= p.struggleCount))
	) then
		p.struggleCount = 0
		p.doTransition( struggledata[movedir].transition, {index=struggler, direction=movedir} )
	else
		p.struggleCount = p.struggleCount + 1
		p.bellySettleDownTimer = 5

		sb.setLogMap("b", "struggle")
		local animation = {offset = struggledata[movedir].offset}
		animation[struggledata.part] = "s_"..movedir


		p.doAnims(animation)

		if p.notMoving() then
			p.doAnims( struggledata[movedir].animation or struggledata.animation, true )
		else
			p.doAnims( struggledata[movedir].animationWhenMoving or struggledata.animationWhenMoving, true )
		end

		if struggledata[movedir].victimAnimation then
			p.doVictimAnim( "occupant"..struggler, struggledata[movedir].victimAnimation, struggledata.part.."State" )
		end
		animator.playSound( "struggle" )
	end
end

function p.onInteraction( occupantId )
	local state = p.stateconfig[p.state]

	local position = p.globalToLocal( world.entityPosition( occupantId ) )
	local interact
	if position[1] > 3 then
		interact = p.occupantArray( state.interact.front )
	elseif position[1] < -3 then
		interact = p.occupantArray( state.interact.back )
	else
		interact = p.occupantArray( state.interact.side )
	end
	if not p.driving or interact.controlled then
		if interact.chance > 0 and p.randomChance( interact.chance ) then
			p.doTransition( interact.transition, {id=occupantId} )
			return
		end
	end

	if state.interact.animation then
		p.doAnims( state.interact.animation )
	end
	p.showEmote( "emotehappy" )
end

function p.randomChance(percent)
	return math.random() <= (percent/100)
end
