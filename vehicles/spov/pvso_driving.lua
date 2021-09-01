
function p.updateDriving(dt)
	if driver then
		local light = p.vso.lights.driver
		light.position = world.entityPosition( driver )
		world.sendEntityMessage( driver, "PVSOAddLocalLight", light )

		local aim = vehicle.aimPosition(p.driverSeat)
		local cursor = "/cursors/cursors.png:pointer"
		world.sendEntityMessage( driver, "PVSOCursor", aim, cursor)
	end

	if p.standalone then
		p.driving = true
		if p.pressControl(p.driverSeat, "special3") then
			world.sendEntityMessage(
				vehicle.entityLoungingIn( p.driverSeat ), "openPVSOInterface", p.vso.menuName.."settings",
				{ vso = entity.id(), occupants = p.getSettingsMenuInfo(), maxOccupants = p.vso.maxOccupants.total }, false, entity.id()
			)
		end
	end

	local dx = controls[p.driverSeat].dx
	local dy = controls[p.driverSeat].dy
	local state = p.stateconfig[p.state]
	local control = state.control
	if dx ~= 0 then
		p.faceDirection( dx )
	end
	if state.control ~= nil then
		p.groundMovement(dx, dy, state, control, dt)
		p.waterMovement(dx, dy, state, control, dt)
		p.jumpMovement(dx, dy, state, control, dt)
		p.airMovement(dx, dy, state, control, dt)
	end
end

function p.pressControl(seat, control)
	return (( controls[seat][control.."Released"] > 0 ) and ( controls[seat][control.."Released"] < 0.15 ))
end

function p.heldControl(seat, control, min)
	return controls[seat][control] > (min or 0)
end

function p.heldControlMax(seat, control, max)
	return controls[seat][control] < (max or 1)
end

function p.heldControlMinMax(seat, control, min, max)
	return p.heldControl(seat, control, min) and p.heldControlMax(seat, control, max)
end

function p.heldControls(seat, controlList, time)
	for _, control in pairs(controlList) do
		if controls[seat][control] <= (time or 0) then
			return false
		end
	end
	return true
end

function p.updateControl(seatname, seat, control, dt, pathfindUpate)
	if vehicle.controlHeld(seatname, control) or pathfindUpate == "hold" then
		seat[control] = seat[control] + dt
		seat[control.."Released"] = 0
	else
		--if p.pathfinding and seatname == p.driverSeat and pathfindUpate ~= "release" then return end
		seat[control.."Released"] = seat[control]
		seat[control] = 0
	end
end

function p.updateDirectionControl(seatname, seat, control, direction, val, dt, pathfindUpate)
	if vehicle.controlHeld(seatname, control) then
		seat[control] = seat[control] + dt
		seat[direction] = seat[direction] + val
		seat[control.."Released"] = 0
	else
		--if p.pathfinding and seatname == p.driverSeat and pathfindUpate ~= "release" then return end
		seat[control.."Released"] = seat[control]
		seat[control] = 0
	end
end

function p.updateControls(dt)
	for seatname, seat in pairs(controls) do
		local lounging = vehicle.entityLoungingIn(seatname)

		if lounging ~= nil and world.entityExists(lounging) then
			seat.dx = 0
			seat.dy = 0
			p.updateDirectionControl(seatname, seat, "left", "dx", -1, dt)
			p.updateDirectionControl(seatname, seat, "right", "dx", 1, dt)
			p.updateDirectionControl(seatname, seat, "down", "dy", -1, dt)
			p.updateDirectionControl(seatname, seat, "up", "dy", 1, dt)
			p.updateControl(seatname, seat, "jump", dt)
			p.updateControl(seatname, seat, "special1", dt)
			p.updateControl(seatname, seat, "special2", dt)
			p.updateControl(seatname, seat, "special3", dt)

			seat.species = world.entitySpecies(lounging) or world.monsterType(lounging)

			seat.primaryHandItem = world.entityHandItem(lounging, "primary")
			seat.altHandItem = world.entityHandItem(lounging, "alt")
			seat.primaryHandItemDescriptor = world.entityHandItemDescriptor(lounging, "primary")
			seat.altHandItemDescriptor = world.entityHandItemDescriptor(lounging, "alt")

			local type = "prey"
			if p.driving and (seatname == p.driverSeat) then
				type = "driver"
			end

			p.addRPC(world.sendEntityMessage(vehicle.entityLoungingIn(seatname), "getVSOseatInformation", type), function(seatdata)
				if seatdata ~= nil then
					sb.jsonMerge(seat, seatdata)
				end
			end, seatname.."Info")
			p.addRPC(world.sendEntityMessage(vehicle.entityLoungingIn(seatname), "getVSOseatEquips", type), function(seatdata)
				if seatdata ~= nil then
					sb.jsonMerge(seat, seatdata)
				end
			end, seatname.."Equips")
		else
			seat = p.clearSeat
		end
	end
end

function p.groundMovement(dx, dy, state, control, dt)
	if (not mcontroller.onGround()) then return end

	local running = "walk"
	if not p.heldControl(p.driverSeat, "shift") and p.occupants.mass < control.fullThreshold then
		running = "run"
	end
	mcontroller.setXVelocity( dx * p.movementParams[running.."Speed"] )

	if dx ~= 0 then
		p.doAnims( control.animations[running] )
		p.movement.animating = true
		mcontroller.applyParameters{ groundFriction = p.movementParams.ambulatingGroundFriction }
	elseif p.movement.animating then
		p.doAnims( state.idle )
		p.movement.animating = false
		mcontroller.applyParameters{ groundFriction = p.movementParams.normalGroundFriction }
	end

	p.movement.jumps = 0
	p.movement.falling = false
	p.movement.airtime = 0
end

function p.jumpMovement(dx, dy, state, control, dt)
	mcontroller.applyParameters{ ignorePlatformCollision = p.movementParams.ignorePlatformCollision }
	p.movement.sinceLastJump = p.movement.sinceLastJump + dt

	local jumpProfile = "airJumpProfile"
	if p.underWater() and p.movementParams.liquidJumpProfile ~= nil then
		jumpProfile = "liquidJumpProfile"
	end

	if p.heldControl( p.driverSeat, "jump" ) then
		if (p.movement.jumps < control.jumpCount) and (p.movement.sinceLastJump >= p.movementParams[jumpProfile].reJumpDelay) and ((not p.movement.jumped) or p.movementParams[jumpProfile].autoJump) then
			p.movement.sinceLastJump = 0
			p.movement.jumps = p.movement.jumps + 1
			p.movement.jumped = true
			if (dy ~= -1) then
				if not p.underWater() then
					p.doAnims( control.animations.jump )
				end
				p.movement.animating = true
				p.movement.falling = false
				mcontroller.setYVelocity(p.movementParams[jumpProfile].jumpSpeed)
				if (p.movement.jumps > 1) and (not p.underWater()) then
					-- particles from effects/multiJump.effectsource
					animator.burstParticleEmitter( control.pulseEffect )
					animator.playSound( "doublejump" )
					for i = 1, control.pulseSparkles do
						animator.burstParticleEmitter( "defaultblue" )
						animator.burstParticleEmitter( "defaultlightblue" )
					end
				end
			end
		end
		if dy == -1 then
			mcontroller.applyParameters{ ignorePlatformCollision = true }
		elseif p.movement.jumped and controls[p.driverSeat].jump < p.movementParams[jumpProfile].jumpHoldTime and mcontroller.yVelocity() <= p.movementParams[jumpProfile].jumpSpeed then
			mcontroller.force({0, p.movementParams[jumpProfile].jumpControlForce * (1 + dt)})
		end
	else
		p.movement.jumped = false
	end
end

function p.airMovement( dx, dy, state, control, dt )
	if (not p.underWater()) and (not mcontroller.onGround()) then
		if (mcontroller.yVelocity() < 0) and (not p.movement.falling) then
			p.doAnims( control.animations.fall )
			p.movement.falling = true
			p.movement.animating = true
		elseif (mcontroller.yVelocity() > 0) and (p.movement.falling) then
			p.doAnims( control.animations.jump )
			p.movement.animating = true
			p.movement.falling = false
		end
		if math.abs(mcontroller.xVelocity()) <= p.movementParams.runSpeed then
			mcontroller.force({ dx * p.movementParams.airForce, 0 })
		end
	end
end

function p.waterMovement( dx, dy, state, control, dt )
	if p.underWater() then
		local swimSpeed = p.movementParams.swimSpeed or p.movementParams.walkSpeed
		local dy = dy
		if p.heldControl(p.driverSeat, "jump") and (dy ~= 1) then
			dy = dy + 1
		end
		if (dx ~= 0) or (dy ~= 0)then
			p.doAnims( control.animations.swim )
			p.movement.animating = true
		else
			p.doAnims( control.animations.swimIdle )
			p.movement.animating = true
		end
		if dx ~= 0 then
			mcontroller.setXVelocity( dx * swimSpeed )
		end
		if dy ~= 0 then
			mcontroller.setYVelocity( dy * swimSpeed )
		end
		p.movement.jumps = 0
		p.movement.falling = false
		p.movement.airtime = 0
	end
end

function p.primaryAction()
	local control = p.stateconfig[p.state].control
	if control.primaryAction ~= nil and vehicle.controlHeld( p.driverSeat, "PrimaryFire" ) then
		if p.movement.primaryCooldown < 1 then
			if control.primaryAction.projectile ~= nil then
				p.projectile(control.primaryAction.projectile)
			end
			if control.primaryAction.animation ~= nil then
				p.doAnims( control.primaryAction.animation )
			end
			if control.primaryAction.script ~= nil then
				local statescript = p.statescripts[p.state][control.primaryAction.script]
				if statescript then
					statescript() -- what arguments might this need?
				else
					sb.logError("[PVSO "..world.entityName(entity.id()).."] Missing statescript "..control.altAction.script.." for state "..p.state.."!")
				end
			end
			if 	p.movement.primaryCooldown < 1 then
				p.movement.primaryCooldown = control.primaryAction.cooldown
			end
		end
	end
	p.movement.primaryCooldown = p.movement.primaryCooldown - 1
end

function p.altAction()
	local control = p.stateconfig[p.state].control
	if control.altAction ~= nil and vehicle.controlHeld( p.driverSeat, "altFire" ) then
		if p.movement.altCooldown < 1 then
			if control.altAction.projectile ~= nil then
				p.projectile(control.altAction.projectile)
			end
			if control.altAction.animation ~= nil then
				p.doAnims( control.altAction.animation )
			end
			if control.altAction.script ~= nil then
				local statescript = p.statescripts[p.state][control.altAction.script]
				if statescript then
					statescript() -- what arguments might this need?
				else
					sb.logError("[PVSO "..world.entityName(entity.id()).."] Missing statescript "..control.altAction.script.." for state "..p.state.."!")
				end
			end
			if 	p.movement.altCooldown < 1 then
				p.movement.altCooldown = control.altAction.cooldown
			end
		end
	end
	p.movement.altCooldown = p.movement.altCooldown - 1
end

p.monsterstrugglecooldown = {}

function p.getSeatDirections(seatname)
	local occupantId = vehicle.entityLoungingIn(seatname)
	if not occupantId or not world.entityExists(occupantId) then return end

	if world.entityType( occupantId ) ~= "player" then
		if not p.monsterstrugglecooldown[seatname] or p.monsterstrugglecooldown[seatname] <= 0 then
			local randomDirections = { "back", "front", "up", "down", "jump", nil}
			p.monsterstrugglecooldown[seatname] = (math.random(100, 1000)/100)
			return randomDirections[math.random(1,6)]
		else
			p.monsterstrugglecooldown[seatname] = p.monsterstrugglecooldown[seatname] - p.dt
			return
		end
	else
		local direction = p.relativeDirectionName(controls[seatname].dx, controls[seatname].dy)
		if diretion then return direction end
		if controls[seatname].jump > 0 then
			return "jump"
		end
	end
end

function p.relativeDirectionName(dx, dy)
	local dx = dx * p.direction
	if dx ~= 0 then
		if dx >= 1 then
			return "front"
		else
			return "back"
		end
	end
	if dy ~= 0 then
		if dy >= 1 then
			return "up"
		else
			return "down"
		end
	end
end

function getDriverStat(eid, stat, callback)
	p.addRPC( world.sendEntityMessage(eid, "getDriverStat", stat), callback, "getDriver"..stat)
end

function p.driverSeatStateChange()
	local transitions = p.stateconfig[p.state].transitions
	local dx = 0
	local dy = 0
	if p.pressControl(p.driverSeat, "left") then
		dx = dx -1
	end
	if p.pressControl(p.driverSeat, "right") then
		dx = dx +1
	end
	if p.pressControl(p.driverSeat, "up") then
		dy = dy +1
	end
	if p.pressControl(p.driverSeat, "down") then
		dy = dy -1
	end
	local movedir = p.relativeDirectionName(dx, dy)

	if (movedir == nil) and p.pressControl(p.driverSeat, "jump") then
		movedir = "jump"
	end

	if movedir ~= nil then
		if transitions[movedir] ~= nil then
			p.doTransition(movedir)
		elseif (movedir == "front" or movedir == "back") and transitions.side ~= nil then
			p.doTransition("side")
		end
	end
end

function p.projectile( projectiledata )
	local driver = vehicle.entityLoungingIn(p.driverSeat)
	if projectiledata.energy and driver then
		p.useEnergy(driver, projectiledata.cost, function(energyUsed)
			if energyUsed then
				p.fireProjectile( projectiledata, driver )
			end
		end)
	else
		p.fireProjectile( projectiledata, driver )
	end
end

function p.fireProjectile( projectiledata, driver )
	local position = p.localToGlobal( projectiledata.position )
	local direction
	if projectiledata.aimable then
		local aiming = vehicle.aimPosition( p.driverSeat )
		vsoFacePoint( aiming[1] )
		position = p.localToGlobal( projectiledata.position )
		aiming[2] = aiming[2] + 0.2 * p.direction * (aiming[1] - position[1])
		direction = world.distance( aiming, position )
	else
		direction = { p.direction, 0 }
	end
	local params = {}

	if driver then
		getDriverStat(driver, "powerMultiplier", function(powerMultiplier)
			params.powerMultiplier = powerMultiplier
			world.spawnProjectile( projectiledata.name, position, driver, direction, true, params )
		end)
	else
		params.powerMultiplier = p.standalonePowerLevel()
		world.spawnProjectile( projectiledata.name, position, entity.Id(), direction, true, params )
	end
end
