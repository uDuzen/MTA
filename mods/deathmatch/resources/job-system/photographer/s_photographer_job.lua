local SAN_FACTION_ID = 20
local PHOTOGRAPHER_FACTION_TYPE = 6

local function isLoggedInPlayer(player)
	return player and isElement(player) and getElementType(player) == "player"
		and tonumber(getElementData(player, "loggedin")) == 1
end

local function getStoredCollectionValue(player)
	if not isLoggedInPlayer(player) then return nil end
	local characterID = tonumber(getElementData(player, "dbid"))
	if not characterID or characterID < 1 then return nil end
	local result = mysql:query_fetch_assoc(
		"SELECT photos FROM characters WHERE id = " .. math.floor(characterID) .. " LIMIT 1"
	)
	if not result then return nil end
	local value = tonumber(result.photos)
	if not value or value ~= value or value == math.huge or value < 0 then return nil end
	return math.floor(value)
end

local function updateCollectionValue(player, value)
	if not isLoggedInPlayer(player) then return false end
	local characterID = tonumber(getElementData(player, "dbid"))
	value = tonumber(value)
	if not characterID or characterID < 1 or not value or value ~= value
		or value == math.huge or value < 0 or value > 100000000 then
		return false
	end
	return mysql:query_free(
		"UPDATE characters SET photos = " .. math.floor(value) .. " WHERE id = " .. math.floor(characterID)
	)
end

function getPaid()
	local player = client
	if not isLoggedInPlayer(player) or not exports.factions:isInFactionType(player, PHOTOGRAPHER_FACTION_TYPE) then
		return false
	end

	local collectionValue = getStoredCollectionValue(player)
	if not collectionValue or collectionValue <= 0 then
		outputChatBox("There are no photographs ready to submit.", player, 255, 0, 0)
		return false
	end

	local sanFaction = exports.factions:getFactionFromID(SAN_FACTION_ID)
	if not sanFaction or not isElement(sanFaction) then return false end
	if not exports.global:giveMoney(sanFaction, collectionValue) then return false end
	if not updateCollectionValue(player, 0) then
		-- Roll back the faction payment if the character record could not be cleared.
		exports.global:takeMoney(sanFaction, collectionValue)
		return false
	end

	local gender = tonumber(getElementData(player, "gender"))
	local pronoun = gender == 1 and "her" or "his"
	triggerEvent("sendAme", player, "hands " .. pronoun .. " collection of photographs to the woman behind the desk.")
	exports.global:sendLocalText(player, "Victoria Greene says: Thank you. These should make the morning edition. Keep up the good work.", nil, nil, nil, 10)
	outputChatBox("#SAN made $" .. exports.global:formatMoney(collectionValue) .. " from the photographs.", player, 255, 104, 91, true)
	triggerClientEvent(player, "updateCollectionValue", player, 0)
	return true
end
addEvent("submitCollection", true)
addEventHandler("submitCollection", root, getPaid)

function info()
	local player = client
	if not isLoggedInPlayer(player) then return false end
	exports.global:sendLocalText(player, "Victoria Greene says: Hello, There. I'm taking the photos of our SAN Photographers -", nil, nil, nil, 10)
	exports.global:sendLocalText(player, "but it seems you aren't one. Feel free to apply for SAN any time ((on the forums))!", nil, nil, nil, 10)
end
addEvent("sellPhotosInfo", true)
addEventHandler("sellPhotosInfo", root, info)

addEvent("getCollectionValue", true)
addEventHandler("getCollectionValue", root, function()
	local player = client
	local value = getStoredCollectionValue(player)
	if value then
		triggerClientEvent(player, "updateCollectionValue", player, value)
	end
end)

function sanAD()
	local player = client
	if not isLoggedInPlayer(player) then return false end
	exports.global:sendLocalText(player, "Victoria Greene says: You can call to our call centre to place an advert. The number is 7331.", 255, 255, 255, 10)
end
addEvent("cSANAdvert", true)
addEventHandler("cSANAdvert", root, sanAD)

function photoHeli(player)
	if not isLoggedInPlayer(player) or not exports.factions:isInFactionType(player, PHOTOGRAPHER_FACTION_TYPE) then
		return false
	end
	local vehicle = getPedOccupiedVehicle(player)
	if not isElement(vehicle) or (getElementModel(vehicle) ~= 488 and getElementModel(vehicle) ~= 487)
		or getVehicleController(vehicle) ~= player then
		return false
	end
	triggerClientEvent(player, "job:photo:heli", player)
	return true
end
addCommandHandler("photoheli", photoHeli)
