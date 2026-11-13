function mixDrugs(drug1, drug2)
	local player = client
	if not isElement(player) or getElementType(player) ~= "player"
		or source ~= player or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	drug1, drug2 = tonumber(drug1), tonumber(drug2)
	if not drug1 or not drug2 or drug1 < 30 or drug1 > 33 or drug2 < 30 or drug2 > 33
		or drug1 ~= math.floor(drug1) or drug2 ~= math.floor(drug2) then
		outputChatBox("Invalid ingredients.", player, 255, 0, 0)
		return false
	end

	local recipes = {
		["31:31"] = 34, ["30:31"] = 35, ["31:30"] = 35,
		["32:31"] = 36, ["31:32"] = 36, ["33:31"] = 37, ["31:33"] = 37,
		["30:30"] = 38, ["30:32"] = 39, ["32:30"] = 39,
		["30:33"] = 40, ["33:30"] = 40, ["32:32"] = 41,
		["32:33"] = 42, ["33:32"] = 42, ["33:33"] = 43
	}
	local drugID = recipes[tostring(drug1) .. ":" .. tostring(drug2)]
	local drugName = drugID and getItemName(drugID)
	if not drugID or not drugName then
		outputChatBox("These ingredients cannot be mixed.", player, 255, 0, 0)
		return false
	end

	if not exports["item-system"]:loadItems(player) then
		outputChatBox("Your inventory could not be loaded. Please try again.", player, 255, 0, 0)
		return false
	end
	local inventory = exports["item-system"]:getItems(player)
	if type(inventory) ~= "table" then return false end
	local ingredients = {}
	for slot, item in ipairs(inventory) do
		if tonumber(item[1]) == drug1 and not ingredients[1] then
			ingredients[1] = { slot = slot, itemID = item[1], value = item[2], metadata = item[5] }
		elseif tonumber(item[1]) == drug2 and (drug1 ~= drug2 or ingredients[1]) and not ingredients[2] then
			if drug1 ~= drug2 or slot ~= ingredients[1].slot then
				ingredients[2] = { slot = slot, itemID = item[1], value = item[2], metadata = item[5] }
			end
		end
	end
	if not ingredients[1] or not ingredients[2] then
		outputChatBox("You do not have both ingredients in your inventory.", player, 255, 0, 0)
		return false
	end

	-- Remove the higher slot first so the lower slot remains stable.
	local first, second = ingredients[1], ingredients[2]
	if first.slot < second.slot then first, second = second, first end
	local removed = {}
	local function restoreIngredients()
		local restored = true
		for _, ingredient in ipairs(removed) do
			if not exports.global:giveItem(player, ingredient.itemID, ingredient.value, ingredient.metadata) then
				restored = false
			end
		end
		if not restored then
			outputDebugString("[item-system] Drug mix rollback failed for " .. getPlayerName(player), 1)
			outputChatBox("Drug mixing failed and an ingredient could not be restored. Contact staff immediately.", player, 255, 0, 0)
			if exports.global.sendMessageToAdmins then
				exports.global:sendMessageToAdmins("[ITEM SYSTEM] Drug mix rollback failed for " .. getPlayerName(player) .. ".")
			end
		end
		return restored
	end

	for _, ingredient in ipairs({ first, second }) do
		if not exports["item-system"]:takeItemFromSlot(player, ingredient.slot) then
			restoreIngredients()
			outputChatBox("An ingredient could not be removed. The mix was cancelled.", player, 255, 0, 0)
			return false
		end
		table.insert(removed, ingredient)
	end

	if not exports.global:giveItem(player, drugID, 1) then
		restoreIngredients()
		outputChatBox("You do not have enough space to mix these chemicals.", player, 255, 0, 0)
		return false
	end

	outputChatBox("You mixed '" .. getItemName(drug1) .. "' and '" .. getItemName(drug2)
		.. "' to form '" .. drugName .. "'.", player, 0, 255, 0)
	exports.global:sendLocalMeAction(player, "mixes some chemicals together.")
	triggerClientEvent(player, "item:updateclient", player)
	return true
end
addEvent("mixDrugs", true)
addEventHandler("mixDrugs", getRootElement(), mixDrugs)
