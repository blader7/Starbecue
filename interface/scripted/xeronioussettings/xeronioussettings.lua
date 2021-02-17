local xeronious
local occupants
local maxOccupants
local settings
local bellyeffects = {
	[-1] = "", [0] = "heal", [1] = "digest", [2] = "softdigest",
	[""] = -1, ["heal"] = 0, ["digest"] = 1, ["softdigest"] = 2 -- reverse lookup
}

function init()
	xeronious = config.getParameter( "vso" )
	occupants = config.getParameter( "occupants" )
	maxOccupants = config.getParameter( "maxOccupants" )
	for i = 1, maxOccupants do
		if occupants[i] and occupants[i].id and world.entityExists( occupants[i].id ) then
			local id = occupants[i].id
			local species = occupants[i].species
			if species == nil then
				setPortrait( "occupant"..i, world.entityPortrait( id, "bust" ) )
			else
				setPortrait( "occupant"..i, {{
					image = "/vehicles/spov/"..species.."/"..species.."icon.png",
					position = {13, 19}
				}})
			end
			widget.setText( "occupant"..i..".name", world.entityName( id ) )
		else
			widget.setButtonEnabled( "occupant"..i..".letOut", false )
		end
	end
	settings = player.getProperty("xeroniousSettings") or {}
	widget.setChecked( "autoDeploy", settings.autodeploy or false )
	widget.setChecked( "defaultSmall", settings.defaultsmall or false )
	widget.setSelectedOption( "bellyEffect", bellyeffects[settings.bellyeffect or ""] )
end

function update( dt )
	for i = 1, maxOccupants do
		if occupants[i] and occupants[i].id and world.entityExists( occupants[i].id ) then
			local health = world.entityHealth( occupants[i].id )
			widget.setProgress( "occupant"..i..".healthbar", health[1] / health[2] )
		else
			widget.setProgress( "occupant"..i..".healthbar", 0)
		end
	end
end

function setBellyEffect()
	local value = widget.getSelectedOption( "bellyEffect" )
	local bellyeffect = bellyeffects[value]
	world.sendEntityMessage( xeronious, "settingsMenuSet", "bellyeffect", bellyeffect )
	settings.bellyeffect = bellyeffect
	saveSettings()
end
function autoDeploy()
	local value = widget.getChecked( "autoDeploy" )
	settings.autodeploy = value
	saveSettings()
end
function defaultSmall()
	local value = widget.getChecked( "defaultSmall" )
	settings.defaultsmall = value
	saveSettings()
end

function despawn()
	world.sendEntityMessage( xeronious, "despawn" )
end

function setPortrait( canvasName, data )
	local canvas = widget.bindCanvas( canvasName..".portrait" )
	canvas:clear()
	for k,v in ipairs(data or {}) do
		local pos = v.position or {0, 0}
		canvas:drawImage(v.image, { -7 + pos[1], -19 + pos[2] } )
	end
end
function letOut(_, which )
	world.sendEntityMessage( xeronious, "settingsMenuSet", "letout", which )
end

function saveSettings()
	player.setProperty( "xeroniousSettings", settings )
end