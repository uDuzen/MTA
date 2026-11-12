local KEY_TYPES = {
	[1] = { itemID = 4, name = "house key" },
	[2] = { itemID = 5, name = "business key" },
	[3] = { itemID = 3, name = "vehicle key" }
}

function makeKey(player, commandName, keyType, keyID)
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or tonumber(getElementData(player, "job")) ~= 6 then
		return false
	end

	keyType, keyID = tonumber(keyType), tonumber(keyID)
	local keyInfo = keyType and KEY_TYPES[keyType]
	if not keyInfo or not keyID or keyID < 1 or keyID ~= math.floor(keyID) then
		outputChatBox("SYNTAX: /" .. tostring(commandName) .. " [Key Type: 1=House 2=Business 3=Vehicle] [Key ID]", player, 255, 194, 14)
		return false
	end

	local itemValue = math.floor(keyID)
	if not exports.global:hasItem(player, keyInfo.itemID, itemValue) then
		outputChatBox("You do not have that key.", player, 255, 0, 0)
		return false
	end
	if not exports.global:hasMoney(player, 25) then
		outputChatBox("You do not have enough money to duplicate a key.", player, 255, 0, 0)
		return false
	end
	if not exports.global:giveItem(player, keyInfo.itemID, itemValue) then
		outputChatBox("The duplicate key could not be created.", player, 255, 0, 0)
		return false
	end
	if not exports.global:takeMoney(player, 25) then
		exports.global:takeItem(player, keyInfo.itemID, itemValue)
		return false
	end

	outputChatBox("You have duplicated a " .. keyInfo.name .. " " .. itemValue .. " at a cost of $25.", player)
	exports.global:sendLocalMeAction(player, "duplicates a " .. keyInfo.name .. ".")
	return true
end
addCommandHandler("copykey", makeKey, false, false)
