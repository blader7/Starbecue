sbq = {}

function init()
	sbq.sbqSettings = player.getProperty("sbqSettings") or {}

	sbq.sbqCurrentData = player.getProperty("sbqCurrentData") or {}

	sbq.loungingIn = player.loungingIn()

	sbq.config = root.assetJson( "/sbqGeneral.config" )

	sbq.globalSettings = sb.jsonMerge( sbq.config.defaultSettings, sbq.sbqSettings.global or {} )

	if sbq.sbqCurrentData.species ~= nil then
		sbq.predatorSettings = sbq.sbqSettings[sbq.sbqCurrentData.species] or sbq.globalSettings
	else
		sbq.predatorSettings = sbq.globalSettings
	end

	sbq.predator = sbq.sbqCurrentData.species or "global"

	BENone:selectValue(sbq.globalSettings.bellyEffect) ---@diagnostic disable-line:undefined-global
	EMEasy:selectValue(sbq.globalSettings.escapeModifier) ---@diagnostic disable-line:undefined-global

	displayDigest:setChecked(sbq.globalSettings.displayDigest) ---@diagnostic disable-line:undefined-global
	bellySounds:setChecked(sbq.globalSettings.bellySounds) ---@diagnostic disable-line:undefined-global

	sbq.sbqPreyEnabled = sb.jsonMerge(sbq.config.defaultPreyEnabled.player, status.statusProperty("sbqPreyEnabled") or {})

	preyEnabled:setChecked(sbq.sbqPreyEnabled.enabled)---@diagnostic disable-line:undefined-global

	oralVore:setChecked(sbq.sbqPreyEnabled.oralVore)---@diagnostic disable-line:undefined-global
	tailVore:setChecked(sbq.sbqPreyEnabled.tailVore)---@diagnostic disable-line:undefined-global
	absorbVore:setChecked(sbq.sbqPreyEnabled.absorbVore)---@diagnostic disable-line:undefined-global

	analVore:setChecked(sbq.sbqPreyEnabled.analVore)---@diagnostic disable-line:undefined-global
	cockVore:setChecked(sbq.sbqPreyEnabled.cockVore)---@diagnostic disable-line:undefined-global
	breastVore:setChecked(sbq.sbqPreyEnabled.breastVore)---@diagnostic disable-line:undefined-global
	unbirth:setChecked(sbq.sbqPreyEnabled.unbirth)---@diagnostic disable-line:undefined-global

	held:setChecked(sbq.sbqPreyEnabled.held)---@diagnostic disable-line:undefined-global
end

function update()
	local dt = script.updateDt()
	sbq.checkRefresh(dt)
end

--------------------------------------------------------------------------------------------------

function sbq.saveSettings()
	if sbq.loungingIn ~= nil and sbq.sbqCurrentData.type == "driver" then
		world.sendEntityMessage( sbq.loungingIn, "settingsMenuSet", sbq.predatorSettings )
	end
	sbq.sbqSettings[sbq.predator] = sbq.predatorSettings
	sbq.sbqSettings.global = sbq.globalSettings
	player.setProperty( "sbqSettings", sbq.sbqSettings )
end

function sbq.changeGlobalSetting(settingname, settingvalue)
	sbq.globalSettings[settingname] = settingvalue
	sbq.predatorSettings[settingname] = settingvalue

	sbq.saveSettings()
end

function sbq.changePredatorSetting(settingname, settingvalue)
	sbq.predatorSettings[settingname] = settingvalue

	sbq.saveSettings()
end

function sbq.setBellyEffect()
	sbq.changeGlobalSetting("bellyEffect", BENone:getGroupValue()) ---@diagnostic disable-line:undefined-global
end

function sbq.setEscapeModifier()
	sbq.changeGlobalSetting("escapeModifier", EMEasy:getGroupValue()) ---@diagnostic disable-line:undefined-global
end

function sbq.changePreySetting(settingname, settingvalue)
	sbq.sbqPreyEnabled[settingname] = settingvalue
	status.setStatusProperty("sbqPreyEnabled", sbq.sbqPreyEnabled)
end

sbq.occupants = {
	total = 0
}

sbq.refreshtime = 0
function sbq.checkRefresh(dt)
	if sbq.refreshtime >= 0.1 and sbq.rpc == nil and sbq.sbqCurrentData.type == "driver" then
		sbq.rpc = world.sendEntityMessage( sbq.loungingIn, "settingsMenuRefresh")
	elseif sbq.rpc ~= nil and sbq.rpc:finished() then
		if sbq.rpc:succeeded() then
			local result = sbq.rpc:result()
			if result ~= nil then
				sbq.occupants = result.occupants
				sbq.occupant = result.occupant
				sbq.powerMultiplier = result.powerMultiplier
				sbq.refreshtime = 0
				sbq.refreshList = result.refreshList or sbq.refreshList
				sbq.locked = result.locked

				sbq.setIconDirectives()
				sbq.refreshListData()
				sbq.readOccupantData()

				sbq.refreshed = true
			end
		else
			sb.logError( "Couldn't refresh settings." )
			sb.logError( sbq.rpc:error() )
		end
		sbq.rpc = nil
	else
		sbq.refreshtime = sbq.refreshtime + dt
	end
end

function sbq.setIconDirectives()
end

function sbq.refreshListData()
	if not sbq.refreshList then return end
	occupantScrollArea:clearChildren() ---@diagnostic disable-line:undefined-global
	sbq.occupantList = {}
	sbq.listItems = {}
	sbq.refreshList = nil
end

sbq.occupantList = {}
sbq.listItems = {}

function sbq.readOccupantData()
	if sbq.occupants.total > 0 then
		--this stardust stuff is powerful but is really wonky and I'm not sure whats wrong here with making it visible and invisible as the tab is defined...
		--occupantsTab:setVisible(true) ---@diagnostic disable-line:undefined-global
		local enable = false
		for i, occupant in pairs(sbq.occupant) do
			if not ((i == "0") or (i == 0)) and (sbq.occupant[i] ~= nil) and (sbq.occupant[i].id ~= nil) and (world.entityExists( sbq.occupant[i].id )) then
				if not sbq.locked then
					enable = true
				end
				local id = sbq.occupant[i].id
				local species = sbq.occupant[i].species

				if sbq.occupantList[id] == nil then
					sbq.occupantList[id] = occupantScrollArea:addChild({ ---@diagnostic disable-line:undefined-global
						type = "listItem",
						selectionGroup = "occupantSelect",
						children = {
							{ type = "label", text = "occupant"..i}
						}
					})
					sbq.listItems[sbq.occupantList[id]] = id
				end

				if id == sbq.selectedId then
					--widget.setListSelected(sbq.occupantList, listItem)
				end
				if species == nil then
					--setPortrait(sbq.occupantList.."."..listItem, world.entityPortrait( id, "bust" ))
				else
					local skin = (sbq.occupant[i].smolPreyData.settings.skinNames or {}).head or "default"
					local directives = sbq.occupant[i].smolPreyData.settings.directives or ""
					--widget.setImage(sbq.occupantList.."."..listItem..".portraitIcon", "/vehicles/sbq/"..species.."/skins/"..skin.."/icon.png"..directives)
				end
				--widget.setText(sbq.occupantList.."."..listItem..".name", world.entityName( id ))
			end
		end

	else
		--occupantsTab:setVisible(false) ---@diagnostic disable-line:undefined-global
	end
end

--------------------------------------------------------------------------------------------------

function BENone:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setBellyEffect()
end

function BEHeal:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setBellyEffect()
end

function BEDigest:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setBellyEffect()
end

function BESoftDigest:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setBellyEffect()
end

--------------------------------------------------------------------------------------------------

function EMEasy:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setEscapeModifier()
end

function EMNormal:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setEscapeModifier()
end

function EMHard:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setEscapeModifier()
end

function EMImpossible:onClick() ---@diagnostic disable-line:undefined-global
	sbq.setEscapeModifier()
end

--------------------------------------------------------------------------------------------------

function displayDigest:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changeGlobalSetting("displayDigest", displayDigest.checked) ---@diagnostic disable-line:undefined-global
end

function bellySounds:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changeGlobalSetting("bellySounds", bellySounds.checked) ---@diagnostic disable-line:undefined-global
end

--------------------------------------------------------------------------------------------------

function preyEnabled:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("enabled", preyEnabled.checked) ---@diagnostic disable-line:undefined-global
end

function oralVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("oralVore", oralVore.checked) ---@diagnostic disable-line:undefined-global
end

function tailVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("tailVore", tailVore.checked) ---@diagnostic disable-line:undefined-global
end

function absorbVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("absorbVore", absorbVore.checked) ---@diagnostic disable-line:undefined-global
end

function analVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("analVore", analVore.checked) ---@diagnostic disable-line:undefined-global
end

function cockVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("cockVore", cockVore.checked) ---@diagnostic disable-line:undefined-global
end

function breastVore:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("breastVore", breastVore.checked) ---@diagnostic disable-line:undefined-global
end

function unbirth:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("unbirth", unbirth.checked) ---@diagnostic disable-line:undefined-global
end

function held:onClick() ---@diagnostic disable-line:undefined-global
	sbq.changePreySetting("held", held.checked) ---@diagnostic disable-line:undefined-global
end

--------------------------------------------------------------------------------------------------
