
---@diagnostic disable:undefined-global

require("/interface/scripted/sbq/sbqSettings/sbqSettings.lua")

-- replace functions that would be using the player table to save data, instead now they will send messages to the predator to save its data, the settings menu should behave exactly the same otherwise

local oldInit = init

function init()
	sbq.predatorEntity = pane.sourceEntity()
	sbq.sbqCurrentData = {
		species = world.entityName(sbq.predatorEntity),
		type = "object"
	}

	local data = metagui.inputData


	sbq.sbqSettings = { global = data.settings }
	sbq.sbqSettings[sbq.sbqCurrentData.species] = data.settings
	sbq.predatorSpawner = data.spawner

	oldInit()

	function lockSettings:onClick()
		sbq.changeGlobalSetting("lockSettings", lockSettings.checked)
		if lockSettings.checked then
			sbq.changeGlobalSetting("ownerId", player.uniqueId())
			local ownerName = world.entityName(player.id())
			sbq.changeGlobalSetting("ownerName", ownerName)
			ownerLabel:setText("Owner: "..ownerName)
			ownerBar:setVisible(true)
		else
			sbq.changeGlobalSetting("ownerId", "")
			sbq.changeGlobalSetting("ownerName", "")
			ownerLabel:setText("")
			ownerBar:setVisible(false)
		end
	end


	if (data.settings.lockSettings and data.settings.ownerId ~= player.uniqueId()) and not player.isAdmin() then
		mainTabField.tabs.globalPredSettings:setVisible(false)
		mainTabField.tabs.customizeTab:setVisible(false)
		if sbq.speciesSettingsTab ~= nil then
			sbq.speciesSettingsTab:setVisible(false)
		end
	end
	if data.settings.ownerName ~= nil and data.settings.ownerName ~= "" then
		ownerLabel:setText("Owner: "..data.settings.ownerName)
		ownerBar:setVisible(true)
	else
		ownerBar:setVisible(false)
	end

	sbq.globalSettings = sbq.predatorSettings
end

function update()
	local dt = script.updateDt()
	sbq.checkRPCsFinished(dt)
end

function sbq.getInitialData()
end

function sbq.getHelpTab()
	if sbq.extraTabs.speciesInfoTabs[sbq.sbqCurrentData.species] ~= nil then
		sbq.speciesHelpTab = mainTabField:newTab( sbq.extraTabs.speciesInfoTabs[sbq.sbqCurrentData.species] )
	end
end

function sbq.saveSettings()
	world.sendEntityMessage( sbq.predatorEntity, "settingsMenuSet", sbq.predatorSettings )
	world.sendEntityMessage( sbq.predatorSpawner, "sbqSaveSettings", sbq.predatorSettings )
end

sbq.changePredatorSetting = sbq.changeGlobalSetting

--------------------------------------------------------------------------------------
