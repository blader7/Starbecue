local mysteriousTFDuration

function sbq.everything_primary()
	message.setHandler("sbqApplyStatusEffects", function(_,_, statlist)
		for statusEffect, data in pairs(statlist) do
			status.setStatusProperty(statusEffect, data.property)
			status.addEphemeralEffect(statusEffect, data.power, data.source)
		end
	end)
	message.setHandler("sbqRemoveStatusEffects", function(_,_, statlist)
		for _, statusEffect in ipairs(statlist) do
			status.removeEphemeralEffect(statusEffect)
		end
	end)
	message.setHandler("sbqRemoveStatusEffect", function(_,_, statusEffect)
		status.removeEphemeralEffect(statusEffect)
	end)

	message.setHandler("sbqApplyScaleStatus", function(_,_, scale)
		status.setStatusProperty("sbqScaling", scale)
		status.addEphemeralEffect("sbqScaling")
	end)

	message.setHandler("sbqForceSit", function(_,_, data)
		status.setStatusProperty("sbqForceSitData", data)
		status.addEphemeralEffect("sbqForceSit", 1, data.source)
	end)

	message.setHandler("sbqGetSeatInformation", function()
		return {
			mass = mcontroller.mass(),
			powerMultiplier = status.stat("powerMultiplier")
		}
	end)

	message.setHandler("sbqSucc", function(_,_, data)
		status.setStatusProperty("sbqSuccData", data)
		status.addEphemeralEffect("sbqSucc", 1, data.source)
	end)

	message.setHandler("sbqIsPreyEnabled", function(_,_, voreType)
		if (status.statusProperty("sbqPreyEnabled") or {}).preyEnabled == false then return false end
		return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], (status.statusProperty("sbqPreyEnabled") or {}))[voreType]
	end)
	message.setHandler("sbqGetPreyEnabled", function(_,_)
		return sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], (status.statusProperty("sbqPreyEnabled") or {}))
	end)

	message.setHandler("sbqSetVelocityAngle", function(_,_, data)
		status.setStatusProperty("sbqSetVelocityAngle", data)
		status.addEphemeralEffect("sbqSetVelocityAngle")
	end)

	message.setHandler("sbqProjectileSource", function (_,_, source)
		status.setStatusProperty("sbqProjectileSource", source)
	end)

	message.setHandler("sbqDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqDigest", id)
		end
	end)
	message.setHandler("sbqSoftDigest", function (_,_,id)
		local currentData = status.statusProperty("sbqCurrentData") or {}
		if type(currentData.id) == "number" and world.entityExists(currentData.id) then
			world.sendEntityMessage(currentData.id, "sbqSoftDigest", id)
		end
	end)

	message.setHandler("sbqGetSpeciesOverrideData", function (_,_)
		local data = { species = world.entitySpecies(entity.id()), gender = world.entityGender(entity.id())}
		return sb.jsonMerge(data, status.statusProperty("speciesAnimOverrideData") or {})
	end)

	message.setHandler("sbqMysteriousPotionTF", function (_,_, data, duration)
		status.setStatusProperty("sbqMysteriousPotionTFDuration", duration )
		mysteriousTFDuration = duration
		sbq.doMysteriousTF(data)
	end)
	message.setHandler("sbqEndMysteriousPotionTF", function (_,_)
		sbq.endMysteriousTF()
	end)

	mysteriousTFDuration = status.statusProperty("sbqMysteriousPotionTFDuration" )
end

local oldupdate = update
function update(dt)
	if oldupdate ~= nil then oldupdate(dt) end

	if type(mysteriousTFDuration) == "number" then
		mysteriousTFDuration = math.max(mysteriousTFDuration - dt, 0)
		if mysteriousTFDuration == 0 then
			sbq.endMysteriousTF()
		end
	end
end

function sbq.doMysteriousTF(data)
	if world.pointTileCollision(entity.position(), {"Null"}) then return end
	local overrideData = data or {}
	local currentData = status.statusProperty("speciesAnimOverrideData") or {}
	local customizedSpecies = status.statusProperty("sbqCustomizedSpecies") or {}
	local originalSpecies = world.entitySpecies(entity.id())

	if not overrideData.species then
		local speciesList = root.assetJson("/interface/windowconfig/charcreation.config").speciesOrdering
		overrideData.species = speciesList[math.random(#speciesList)]
	end
	if overrideData.species == originalSpecies and (not overrideData.identity) then
		return sbq.endMysteriousTF()
	end
	local customData = customizedSpecies[overrideData.species]
	overrideData = sb.jsonMerge(customData or {}, overrideData)

	local genders = {"male", "female"}

	local genderswapImmunity = sb.jsonMerge(root.assetJson("/sbqGeneral.config:defaultPreyEnabled")[world.entityType(entity.id())], (status.statusProperty("sbqPreyEnabled") or {})).genderswapImmunity
	if genderswapImmunity then
		overrideData.gender = currentData.gender or world.entityGender(entity.id())
	else
		if not overrideData.gender then
			overrideData.gender = genders[math.random(2)]
		end
		if overrideData.gender == "noChange" then
			overrideData.gender = currentData.gender or world.entityGender(entity.id())
		end
	end

	local success, speciesFile = pcall(root.assetJson, ("/species/"..overrideData.species..".species"))

	overrideData.identity = overrideData.identity or {}

	if success then
		for i, data in ipairs(speciesFile.genders or {}) do
			if data.name == overrideData.gender then
				overrideData.identity.hairGroup = overrideData.identity.hairGroup or data.hairGroup or "hair"
				overrideData.identity.facialHairGroup = overrideData.identity.facialHairGroup or data.facialHairGroup or "facialHair"
				overrideData.identity.facialMaskGroup = overrideData.identity.facialMaskGroup or data.facialMaskGroup or "facialMask"

				if data.hair and data.hair[1] then
					overrideData.identity.hairType = overrideData.identity.hairType or data.hair[math.random(#data.hair)]
				end
				if data.facialHair and data.facialHair[1] then
					overrideData.identity.facialHairType = overrideData.identity.facialHairType or data.facialHair[math.random(#data.facialHair)]
				end
				if data.facialMask and data.facialMask[1] then
					overrideData.identity.facialMaskType = overrideData.identity.facialMaskType or data.facialMask[math.random(#data.facialMask)]
				end
			end
		end
	end
	local undyColor = overrideData.identity.undyColor or ""
	if success and not overrideData.identity.undyColor and speciesFile.undyColor and speciesFile.undyColor[1] then
		local index = math.random(#speciesFile.undyColor)
		local colorTable = (speciesFile.undyColor or {})[index]
		if type(colorTable) == "table" then
			undyColor = "?replace"
			for color, replace in pairs(colorTable) do
				undyColor = undyColor..";"..color.."="..replace
			end
		end
		overrideData.identity.undyColor = undyColor
		overrideData.identity.undyColorIndex = index
	end

	local bodyColor = overrideData.identity.bodyDirectives or ""
	if success and not overrideData.identity.bodyDirectives and speciesFile.bodyColor and speciesFile.bodyColor[1] then
		local index = math.random(#speciesFile.bodyColor)
		local colorTable = (speciesFile.bodyColor or {})[index]
		if type(colorTable) == "table" then
			bodyColor = "?replace"
			for color, replace in pairs(colorTable) do
				bodyColor = bodyColor..";"..color.."="..replace
			end
		end
		overrideData.identity.bodyColorIndex = index
		overrideData.identity.bodyDirectives = bodyColor

		if speciesFile.altOptionAsUndyColor then
			overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..undyColor
		end
	end

	local hairColor = overrideData.identity.hairDirectives or ""
	if success and not overrideData.identity.hairDirectives and speciesFile.hairColor and speciesFile.hairColor[1] then
		local index = math.random(#speciesFile.hairColor)
		local colorTable = (speciesFile.hairColor or {})[index]
		if type(colorTable) == "table" then
			hairColor = "?replace"
			for color, replace in pairs(colorTable) do
				hairColor = hairColor..";"..color.."="..replace
			end
		end
		overrideData.identity.hairColorIndex = index
		if speciesFile.headOptionAsHairColor then
			overrideData.identity.hairDirectives = hairColor
		else
			overrideData.identity.hairDirectives = overrideData.identity.bodyDirectives
		end
		if speciesFile.altOptionAsHairColor then
			overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..undyColor
		end
		if speciesFile.hairColorAsBodySubColor then
			overrideData.identity.bodyDirectives = overrideData.identity.bodyDirectives..hairColor
		end
		if speciesFile.bodyColorAsHairSubColor then
			overrideData.identity.hairDirectives = overrideData.identity.hairDirectives..overrideData.identity.bodyDirectives
		end
	end

	if not overrideData.identity.facialHairDirectives then
		overrideData.identity.facialHairDirectives = overrideData.identity.facialHairDirectives or overrideData.identity.hairDirectives
		if speciesFile.bodyColorAsFacialHairSubColor then
			overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..overrideData.identity.bodyDirectives
		end
	end
	if not overrideData.identity.facialMaskDirectives then
		overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives or overrideData.identity.hairDirectives
		if speciesFile.bodyColorAsFacialMaskSubColor then
			overrideData.identity.facialMaskDirectives = overrideData.identity.facialMaskDirectives..overrideData.identity.bodyDirectives
		end
	end

	overrideData.identity.emoteDirectives = overrideData.identity.emoteDirectives or overrideData.identity.bodyDirectives

	local specialStatus
	if success then
		specialStatus = speciesFile.customAnimStatus
	end

	overrideData.mysteriousPotion = true
	overrideData.permanent = true
	overrideData.customAnimStatus = specialStatus

	if (overrideData.species ~= originalSpecies and not customData) and not speciesFile.noUnlock then
		overrideData.unlockSpecies = nil
		customizedSpecies[overrideData.species] = overrideData
		status.setStatusProperty("sbqCustomizedSpecies", customizedSpecies)
		world.sendEntityMessage(entity.id(), "sbqUnlockedSpecies")
	end

	local statusProperty = status.statusProperty("speciesAnimOverrideData") or {}
	if not statusProperty.mysteriousPotion then
		status.setStatusProperty("oldSpeciesAnimOverrideData", statusProperty)
		status.setStatusProperty("oldSpeciesAnimOverrideCategory", status.getPersistentEffects("speciesAnimOverride"))
	end

	status.setStatusProperty("sbqMysteriousPotionTF", overrideData)
	status.clearPersistentEffects("speciesAnimOverride")
	status.setStatusProperty("speciesAnimOverrideData", overrideData)
	status.setPersistentEffects("speciesAnimOverride", {specialStatus or "speciesAnimOverride"})
	refreshOccupantHolder()
end

function refreshOccupantHolder()
	local currentData = status.statusProperty("sbqCurrentData") or {}
	if type(currentData.id) == "number" and world.entityExists(currentData.id) then
		world.sendEntityMessage(currentData.id, "reversion")
		if currentData.species == "sbqOccupantHolder" then
			world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
		end
	else
		world.spawnProjectile("sbqWarpInEffect", mcontroller.position(), entity.id(), { 0, 0 }, true)
	end
end

function sbq.endMysteriousTF()
	status.setStatusProperty("sbqMysteriousPotionTFDuration", nil )
	mysteriousTFDuration = nil
	status.setStatusProperty("sbqMysteriousPotionTF", nil)
	status.clearPersistentEffects("speciesAnimOverride")
	status.setStatusProperty("speciesAnimOverrideData", status.statusProperty("oldSpeciesAnimOverrideData"))
	status.setPersistentEffects("speciesAnimOverride", status.statusProperty("oldSpeciesAnimOverrideCategory") or {})
	refreshOccupantHolder()
end
