local tazerCooldowns = {}

function tazerFired(weapon, ammo, ammoInClip, hitX, hitY, hitZ, target)
	local shooter = source
	if weapon ~= 24 or not isElement(shooter) or getElementType(shooter) ~= "player"
		or tonumber(getElementData(shooter, "loggedin")) ~= 1
		or tonumber(getElementData(shooter, "deaglemode")) ~= 0
		or not (exports.factions:isInFactionType(shooter, 2) or exports.factions:isInFactionType(shooter, 3))
		or isTimer(tazerCooldowns[shooter]) then
		return false
	end

	-- Cooldown is driven by the server-side weapon-fire event, including misses.
	tazerCooldowns[shooter] = setTimer(function(player)
		tazerCooldowns[player] = nil
	end, 10005, 1, shooter)

	if not isElement(target) or getElementType(target) ~= "player"
		or target == shooter or tonumber(getElementData(target, "loggedin")) ~= 1
		or isPedDead(target) then
		return false
	end
	local sx, sy, sz = getElementPosition(shooter)
	local tx, ty, tz = getElementPosition(target)
	if getElementDimension(shooter) ~= getElementDimension(target)
		or getElementInterior(shooter) ~= getElementInterior(target)
		or getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) > 20 then
		return false
	end

	for _, nearbyPlayer in ipairs(exports.global:getNearbyElements(target, "player", 20)) do
		triggerClientEvent(nearbyPlayer, "showTazerEffect", nearbyPlayer, tx, ty, tz)
	end
	exports.anticheat:changeProtectedElementDataEx(target, "tazed", true, false)
	toggleAllControls(target, false, true, false)
	exports.global:applyAnimation(target, "ped", "FLOOR_hit_f", -1, false, false, true, true, true)
	setTimer(removeAnimation, 10005, 1, target)
	return true
end
addEventHandler("onPlayerWeaponFire", root, tazerFired)

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
