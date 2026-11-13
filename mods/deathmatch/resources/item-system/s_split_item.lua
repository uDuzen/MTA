
function resetFrame(requestedPlayer, itemID, itemValue)
	local player = client or requestedPlayer
	if client and (source ~= client or requestedPlayer ~= client) then return false end
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 or itemID ~= math.floor(itemID)
		or type(itemValue) ~= "string" and type(itemValue) ~= "number" then return false end
	if not hasItem(player, itemID, itemValue) then return false end

	if not takeItem(player, itemID, itemValue) then return false end
	if not giveItem(player, 147, 1) then
		if not giveItem(player, itemID, itemValue) then
			outputDebugString("[item-system] resetFrame rollback failed for " .. getPlayerName(player), 1)
			outputChatBox("The frame reset failed and the original item could not be restored. Contact staff.", player, 255, 0, 0)
		else
			outputChatBox("The frame reset failed; your original item was restored.", player, 255, 0, 0)
		end
		return false
	end
	outputChatBox("Texture information formatted.", player, 0, 255, 0)
	return true
end
addEvent("resetFrame", true)
addEventHandler("resetFrame", getRootElement(), resetFrame)

function splitItem(itemID, amount)
	local player = client or source
	if client and source ~= client then return false end
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end

	itemID = tonumber(itemID)
	amount = tonumber(amount)
	if not itemID or itemID < 1 or itemID ~= math.floor(itemID)
		or not amount or amount ~= amount or amount == math.huge
		or amount < 1 or amount > 100000 or amount ~= math.floor(amount) then
		outputChatBox("Item ID and amount must be positive whole numbers.", player, 255, 0, 0, false)
		return false
	end
	if not splittableItems[itemID] then return false end

	local hasItem, itemSlot, itemValue, itemIndex, metadata = hasItem(player, itemID)
	if not hasItem then
		outputChatBox("You do not have that item in your inventory.", player, 255, 0, 0, false)
		return false
	end
	local function restoreOriginal()
		local restored = giveItem(player, itemID, itemValue, false, true, metadata)
		if not restored then
			outputDebugString("[item-system] Failed to restore original split item for " .. getPlayerName(player) .. " item " .. itemID, 1)
			outputChatBox("The split failed and the original item could not be restored. Contact staff immediately.", player, 255, 0, 0)
		end
		return restored
	end
	local function rollbackSplit(partialValue)
		if not takeItem(player, itemID, partialValue) then
			outputDebugString("[item-system] Failed to remove partial split item during rollback for " .. getPlayerName(player), 1)
			outputChatBox("A partial split could not be rolled back. Contact staff immediately.", player, 255, 0, 0)
			return false
		end
		return restoreOriginal()
	end

	if itemID == 116 then
		local pack = exports.global:explode(":", tostring(itemValue))
		local ammo = type(pack) == "table" and tonumber(pack[2]) or nil
		if not ammo or ammo < 1 or ammo ~= math.floor(ammo) or not pack[3] then
			outputChatBox("Your ammunition pack is invalid. Please contact staff.", player, 255, 0, 0)
			return false
		end
		if amount >= ammo then
			outputChatBox("The amount to split must be smaller than the pack amount.", player, 255, 0, 0, false)
			return false
		end

		local serialDetails = exports.global:retrieveWeaponDetails(pack[3])
		local serialSource = serialDetails and tonumber(serialDetails[2]) or 1
		local serialCreator = serialDetails and tonumber(serialDetails[3]) or tonumber(getElementData(player, "dbid"))
		local newSerial = exports.global:createWeaponSerial(serialSource, serialCreator, tonumber(getElementData(player, "dbid")))
		if not newSerial or tostring(newSerial) == "" then
			outputChatBox("A new ammunition serial could not be created. Nothing was changed.", player, 255, 0, 0)
			return false
		end

		local remainingValue = exports.weapon:modifyWeaponValue(itemValue, 2, ammo - amount)
		local splitValue = exports.weapon:modifyWeaponValue(
			exports.weapon:modifyWeaponValue(itemValue, 3, newSerial),
			2,
			amount
		)
		if type(remainingValue) ~= "string" and type(remainingValue) ~= "number"
			or type(splitValue) ~= "string" and type(splitValue) ~= "number" then
			outputChatBox("The ammunition pack could not be formatted. Nothing was changed.", player, 255, 0, 0)
			return false
		end

		if not takeItem(player, itemID, itemValue) then return false end
		if not giveItem(player, itemID, remainingValue, false, true, metadata) then
			restoreOriginal()
			outputChatBox("The ammunition pack could not be split. Your original pack was restored.", player, 255, 0, 0)
			return false
		end
		if not giveItem(player, itemID, splitValue, false, true, metadata) then
			rollbackSplit(remainingValue)
			outputChatBox("The ammunition pack could not be fully split. The system attempted to restore your original pack.", player, 255, 0, 0)
			return false
		end
		outputChatBox("Ammunition pack split successfully.", player, 0, 255, 0)
		triggerClientEvent(player, "item:updateclient", player)
		return true
	end

	local itemAmount = tonumber(tostring(itemValue):match("%d+"))
	if not itemAmount or itemAmount < 1 then
		outputChatBox("Your item value is invalid. Please contact staff.", player, 255, 0, 0)
		return false
	end
	if amount >= itemAmount then
		outputChatBox("The amount to split must be smaller than the item amount.", player, 255, 0, 0)
		return false
	end

	local remainingAmount = itemAmount - amount
	if not takeItem(player, itemID, itemValue) then return false end
	if not giveItem(player, itemID, amount, false, true, metadata) then
		restoreOriginal()
		outputChatBox("The item could not be split. Your original item was restored.", player, 255, 0, 0)
		return false
	end
	if not giveItem(player, itemID, remainingAmount, false, true, metadata) then
		rollbackSplit(amount)
		outputChatBox("The item could not be fully split. The system attempted to restore your original item.", player, 255, 0, 0)
		return false
	end
	outputChatBox("Item split successfully.", player, 0, 255, 0)
	triggerClientEvent(player, "item:updateclient", player)
	return true
end
addEvent("splitItem", true)
addEventHandler("splitItem", getRootElement(), splitItem)

function listSplittable(thePlayer, commandName)
	outputChatBox("List of splittable item's names & IDs:",thePlayer, 255, 194, 14)
	for itemID = 1, 150 do
		local itemName = false
		itemName = getItemName(itemID)
		if itemName and splittableItems[itemID] then
			outputChatBox("ID #"..tostring(itemID).." - "..itemName..".",thePlayer, 0, 255, 0)
		end
	end
end
addCommandHandler("splits",listSplittable, false, false )