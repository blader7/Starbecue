function init()
	script.setUpdateDelta(5)
	self.powerMultiplier = effect.duration()
	self.digested = false
	self.cdt = 0
	status.removeEphemeralEffect("pvsoDigest")
	status.removeEphemeralEffect("pvsoSoftDigest")
	status.removeEphemeralEffect("pvsoDisplaySoftDigest")
	status.removeEphemeralEffect("pvsoDisplayDigest")

end

function update(dt)
	status.modifyResourcePercentage("health", 0.01 * dt * self.powerMultiplier)
end

function uninit()

end
