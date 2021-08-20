
p.bellyeffects = {
	[-1] = "", [0] = "heal", [1] = "digest", [2] = "softdigest",
	[""] = -1, ["heal"] = 0, ["digest"] = 1, ["softdigest"] = 2 -- reverse lookup
}

function onInit()
	p.occupantList = "occupantScrollArea.occupantList"
	p.vso = config.getParameter( "vso" )
	p.occupants = config.getParameter( "occupants" )
	p.maxOccupants = config.getParameter( "maxOccupants" )
	enableActionButtons(false)
	readOccupantData()
	p.vsoSettings = player.getProperty("vsoSettings") or {}
	settings = p.vsoSettings[p.vsoname] or {}
	widget.setChecked( "autoDeploy", settings.autodeploy or false )
	widget.setChecked( "displayDamage", settings.displaydamage or false )
	widget.setChecked( "defaultSmall", settings.defaultsmall or false )
	widget.setSelectedOption( "bellyEffect", p.bellyeffects[settings.bellyeffect or ""] )
	p.refreshed = true
end

function enableActionButtons(enable) -- replace function on the specific settings menu if extra buttons are added
	widget.setButtonEnabled( "letOut", enable )
end

p.listItems = {}

function checkIfIdListed(id, species)
	for i = 1, #p.listItems do
		if p.listItems[i].id == id then
			return i, p.listItems[i].listItem
		end
	end
	return #p.listItems+1, widget.addListItem(p.occupantList)
end

function readOccupantData()
	enableActionButtons(false)
	for i = 1, #p.occupants do
		if p.occupants[i] and p.occupants[i].id and world.entityExists( p.occupants[i].id ) then
			local id = p.occupants[i].id
			local species = p.occupants[i].species
			local listEntry, listItem = checkIfIdListed(id, species)

			p.listItems[listEntry] = {
				id = id,
				listItem = listItem
			}
			if id == p.selectedId then
				widget.setListSelected(p.occupantList, listItem)
			end
			if species == nil then
				setPortrait(p.occupantList.."."..listItem, world.entityPortrait( id, "bust" ))
			else
				setPortrait(p.occupantList.."."..listItem, {{
					image = "/vehicles/spov/"..species.."/"..species.."icon.png",
					position = {13, 12}
				}})
			end
			widget.setText(p.occupantList.."."..listItem..".name", world.entityName( id ))
		end
		enableActionButtons(true)
	end
end

function updateHPbars()
	local listItem
	for i = 1, #p.occupants do
		for j = 1, #p.listItems do
			if p.listItems[j].id == p.occupants[i].id then
				listItem = p.listItems[j].listItem
			end
		end
		if p.occupants[i] and p.occupants[i].id and world.entityExists( p.occupants[i].id ) then
			local health = world.entityHealth( p.occupants[i].id )
			widget.setProgress( p.occupantList.."."..listItem..".healthbar", health[1] / health[2] )

			secondaryBar(i, listItem)
		else
			p.refreshList = true
		end
	end
end

function secondaryBar(occupant, listItem)
end

function getSelectedId()
	local selected = widget.getListSelected(p.occupantList)
	for j = 1, #p.listItems do
		if p.listItems[j].listItem == selected then
			p.selectedId = p.listItems[j].id
		end
	end
end

function refreshListData()
	if not p.refreshList then return end
	p.refreshList = false

	getSelectedId()

	p.listItems = {}
	widget.clearListItems(p.occupantList)
end

p.refreshtime = 0
p.rpc = nil

function checkRefresh(dt)
	if p.refreshtime >= 3 and p.rpc == nil then
		p.rpc = world.sendEntityMessage( p.vso, "settingsMenuRefresh")
	elseif p.rpc ~= nil and p.rpc:finished() then
		if p.rpc:succeeded() then
			local result = p.rpc:result()
			if result ~= nil then
				p.occupants = result
				refreshListData()
				readOccupantData()
				p.refreshtime = 0
				p.refreshed = true
				--sb.logInfo( "Refreshed Settings Menu" )
			end
		else
			sb.logError( "Couldn't refresh settings." )
			sb.logError( p.rpc:error() )
		end
		--sb.logInfo( "Reset Settings Menu RPC" )
		p.rpc = nil
	else
		--[[if p.rpc then
			sb.logInfo( "Waiting for RPC" )
		else
			sb.logInfo( "Waiting for refresh for"..p.refreshtime )
		end]]
		p.refreshtime = p.refreshtime + dt
	end
end

function setBellyEffect()
	local value = widget.getSelectedOption( "bellyEffect" )
	local bellyeffect = p.bellyeffects[value]
	settings.bellyeffect = bellyeffect
	saveSettings()
end

function changeSetting(settingname)
	local value = widget.getChecked( settingname )
	settings[string.lower(settingname)] = value
	saveSettings()
end

function displayDamage()
	changeSetting( "displayDamage" )
end

function autoDeploy()
	changeSetting( "autoDeploy" )
end
function defaultSmall()
	changeSetting( "defaultSmall" )
end

function saveSettings()
	world.sendEntityMessage( p.vso, "settingsMenuSet", settings )
	p.vsoSettings[p.vsoname] = settings
	player.setProperty( "vsoSettings", p.vsoSettings )
end

function despawn()
	world.sendEntityMessage( p.vso, "despawn" )
end
function clearPortrait(canvasName)
	local canvas = widget.bindCanvas( canvasName..".portrait" )
	canvas:clear()
end

function setPortrait( canvasName, data )
	local canvas = widget.bindCanvas( canvasName..".portrait" )
	canvas:clear()
	for k,v in ipairs(data or {}) do
		local pos = v.position or {0, 0}
		canvas:drawImage(v.image, { -7 + pos[1], -19 + pos[2] } )
	end
end

function getWhich()
	getSelectedId()
	for i = 1, #p.occupants do
		if p.selectedId == p.occupants[i].id then
			return i
		end
	end
	return #p.occupants
end

function letOut()
	if p.refreshed then
		p.refreshed = false
		p.refreshtime = 0
		p.refreshList = true
		local which = getWhich()
		enableActionButtons(false)
		world.sendEntityMessage( p.vso, "letout", which )
	end
end