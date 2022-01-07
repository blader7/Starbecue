
function sbq.letout(id, i)
	world.sendEntityMessage( player.loungingIn(), "letout", id )
end

function sbq.turboDigest(id, i)
	world.sendEntityMessage( id, "sbqTurboDigest" )
end

function sbq.transform(id, i)
	world.sendEntityMessage( player.loungingIn(), "transform", id, 3 )
end

function sbq.xeroEggify(id, i)
	if sbq.occupant[i].location ~= "belly" then return end
	world.sendEntityMessage( player.loungingIn(), "transform", id, 3, {
		barColor = {"aa720a", "e4a126", "ffb62e", "ffca69"},
		forceSettings = true,
		layer = true,
		state = "smol",
		species = "sbqEgg",
		layerLocation = "egg",
		settings = {
			cracks = 0,
			bellyEffect = "sbqHeal",
			escapeDifficulty = sbq.sbqSettings.global.escapeDifficulty,
			skinNames = {
				head = "xeronious",
				body = "xeronious"
			}
		}
	})
end

function sbq.cumTF(id, i)
	if not ((sbq.occupant[i].location == "balls") or (sbq.occupant[i].location == "shaft") or (sbq.occupant[i].location == "ballsR") or (sbq.occupant[i].location == "ballsL")) then return end
	world.sendEntityMessage( player.loungingIn(), "transform", id, 3, {
		barColor = {"A1A1A1", "DCDCDC", "EFEFEF", "FFFFFF"},
		forceSettings = true,
		state = "stand",
		species = "sbqSlime",
		settings = {
			bellyEffect = "sbqRemoveBellyEffects",
			replaceColors = {2},
			skinNames = {}
		}
	})
end
