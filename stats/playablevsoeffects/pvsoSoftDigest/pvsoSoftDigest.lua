
require("/stats/playablevsoeffects/pvsoEffectsGeneral.lua")

function init()
	script.setUpdateDelta(5)
	self.powerMultiplier = effect.duration()

	removeOtherBellyEffects()
end

function update(dt)
	if world.entityExists(effect.sourceEntity()) and (effect.sourceEntity() ~= entity.id()) then
		local health = world.entityHealth(entity.id())

		if health[1] <= 1 then
			status.setResource("health", 1)
			return
		end

		if health[1] > ( 0.01 * dt * self.powerMultiplier) then
			status.modifyResourcePercentage("health", -0.01 * dt * self.powerMultiplier)
		end
	else
		effect.expire()
	end
end

function uninit()

end