local tazerCooldowns = {}

function tazerFired(x, y, z, target)
	local shooter = client
	if not shooter or not isElement(shooter) or getElementType(shooter) ~= "player"
		or tonumber(getElementData(shooter, "loggedin")) ~= 1
		or tonumber(getElementData(shooter, "deaglemode")) ~= 0
		or getPedWeapon(shooter) ~= 24 or getPedTotalAmmo(shooter) <= 0
		or not (exports.factions:isInFactionType(shooter, 2) or exports.factions:isInFactionType(shooter, 3))
		or not isElement(target) or getElementType(target) ~= "player"
		or target == shooter or tonumber(getElementData(target, "loggedin")) ~= 1
		or isTimer(tazerCooldowns[shooter]) then
		return false
	end
	local px, py, pz = getElementPosition(shooter)
	local tx, ty, tz = getElementPosition(target)
	if getElementDimension(shooter) ~= getElementDimension(target)
		or getElementInterior(shooter) ~= getElementInterior(target)
		or getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) > 20 then
		return false
	end
	for _, value in ipairs(exports.global:getNearbyElements(target, "player", 20)) do
		if value ~= shooter then
			triggerClientEvent(value, "showTazerEffect", value, tx, ty, tz)
		end
	end
	tazerCooldowns[shooter] = setTimer(function(player)
		tazerCooldowns[player] = nil
	end, 10005, 1, shooter)
	exports.anticheat:changeProtectedElementDataEx(target, "tazed", true, false)
	toggleAllControls(target, false, true, false)
	exports.global:applyAnimation(target, "ped", "FLOOR_hit_f", -1, false, false, true, true, true)
	setTimer(removeAnimation, 10005, 1, target)
	return true
end
addEvent("tazerFired", true )
addEventHandler("tazerFired", getRootElement(), tazerFired)

function removeAnimation(thePlayer)
	if isElement(thePlayer) and getElementType(thePlayer) == "player" then
		exports.global:removeAnimation(thePlayer, true)
	end
end

function updateDeagleMode(mode)
	local player = client
	mode = tonumber(mode)
	if not player or not isElement(player) or tonumber(getElementData(player, "loggedin")) ~= 1
		or getPedWeapon(player) ~= 24 or not mode or mode < 0 or mode > 2
		or mode ~= math.floor(mode) then
		return false
	end
	if mode ~= 1 and not (exports.factions:isInFactionType(player, 2) or exports.factions:isInFactionType(player, 3)) then
		return false
	end
	exports.anticheat:changeProtectedElementDataEx(player, "deaglemode", mode, true)
	return true
end
addEvent("deaglemode", true)
addEventHandler("deaglemode", getRootElement(), updateDeagleMode)

addEventHandler("onPlayerQuit", root, function()
	local cooldown = tazerCooldowns[source]
	if isTimer(cooldown) then killTimer(cooldown) end
	tazerCooldowns[source] = nil
end)
