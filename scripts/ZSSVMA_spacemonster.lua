local oldinit = init
function init()
	oldinit()

	message.setHandler("pvsoApplyStatusEffects", function(_,_, effects, source)
		status.addEphemeralEffects(effects, source)
	end)

	message.setHandler("pvsoRemoveStatusEffect", function(_,_, effect)
		status.removeEphemeralEffect(effect)
	end)

	message.setHandler("pvsoRemoveStatusEffects", function(_,_, effects)
		for i = 1, #effects do
			status.removeEphemeralEffect(effect[i])
		end
	end)

end
