--MAXIME
--ATM Card system
local cooldown = {}
local MAX_ATM_TRANSACTION = 1000000000

local function validateATMInteraction(player, atm)
	if not isElement(player) or getElementType(player) ~= "player"
		or client ~= player or source ~= player
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not isElement(atm) or getElementType(atm) ~= "object"
		or getElementModel(atm) ~= 2942 then
		return false
	end
	if getElementDimension(player) ~= getElementDimension(atm)
		or getElementInterior(player) ~= getElementInterior(atm) then
		return false
	end
	local px, py, pz = getElementPosition(player)
	local ax, ay, az = getElementPosition(atm)
	if getDistanceBetweenPoints3D(px, py, pz, ax, ay, az) > 3.5 then
		return false
	end
	return true
end

local function validateATMAmount(value)
	local amount = tonumber(value)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge
		or amount < 1 or amount > MAX_ATM_TRANSACTION or amount ~= math.floor(amount) then
		return false
	end
	return amount
end

local function validateATMCardNumber(cardNumber)
	return type(cardNumber) == "string"
		and cardNumber:match("^%d%d%d%d %d%d%d%d %d%d%d%d %d%d%d%d$") ~= nil
end

local function getPlayerATMCardRecord(player)
	local characterID = tonumber(getElementData(player, "dbid"))
	if not characterID or characterID < 1 then return false end
	return mysql:query_fetch_assoc("SELECT card_id, card_owner, card_number, card_pin, card_locked, card_type, limit_type "
		.. "FROM atm_cards WHERE card_type = 1 AND card_owner = " .. characterID .. " LIMIT 1")
end

local function isATMNearPlayer(player, atm)
	if not isElement(player) or getElementType(player) ~= "player"
		or not isElement(atm) or getElementType(atm) ~= "object"
		or getElementModel(atm) ~= 2942
		or getElementDimension(player) ~= getElementDimension(atm)
		or getElementInterior(player) ~= getElementInterior(atm) then return false end
	local px, py, pz = getElementPosition(player)
	local ax, ay, az = getElementPosition(atm)
	return getDistanceBetweenPoints3D(px, py, pz, ax, ay, az) <= 3.5
end

local function isAuthenticatedBankPlayer(player)
	return isElement(player) and getElementType(player) == "player"
		and source == player and (client == nil or client == player)
		and tonumber(getElementData(player, "loggedin")) == 1
end

local function fetchATMCardOwner(cardNumber)
	if not validateATMCardNumber(cardNumber) then return false end
	local row = mysql:query_fetch_assoc("SELECT c.id, c.charactername, c.bankmoney FROM characters c "
		.. "INNER JOIN atm_cards a ON c.id = a.card_owner WHERE a.card_number = '" .. cardNumber
		.. "' AND a.card_locked = '0' AND a.card_type = '1' LIMIT 1")
	if not row then return false end
	local characterID, balance = tonumber(row.id), tonumber(row.bankmoney)
	if not characterID or characterID < 1 or characterID ~= math.floor(characterID)
		or not balance or balance < 0 or balance ~= balance
		or balance == math.huge or balance == -math.huge then
		return false
	end
	return { id = characterID, name = tostring(row.charactername or "Unknown"), balance = balance }
end

local function adjustATMCardOwnerBalance(player, ownerID, onlineOwner, amount, operation)
	if onlineOwner then
		if operation == "minus" then return takeBankMoney(onlineOwner, amount) == true end
		if operation == "plus" then return giveBankMoney(onlineOwner, amount) == true end
		return false
	end
	return updateBankMoney(player, ownerID, amount, operation) == true
end


function checkInsideATMMachine(theATM, absX, absY)
	if not validateATMInteraction(client, theATM) then return false end
	absX, absY = tonumber(absX), tonumber(absY)
	if not absX or not absY or absX ~= absX or absY ~= absY
		or absX < 0 or absX > 1 or absY < 0 or absY > 1 then return false end
	if not exports["item-system"]:loadItems(theATM) then
		triggerClientEvent(client, "bank:respondToPendingTransfer", client, "ATM inventory is temporarily unavailable.")
		return false
	end
	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if not foundAnATMCard then
		exports.hud:sendBottomNotification(source,"ATM Card is required!", "Please insert your ATM card into the ATM machine's slot.")
		return false
	end

	local cardOwner, cardNumber, cardOwnerCharID = getCardInfo(foundAnATMCard)
	if not cardOwnerCharID then
		triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Your ATM card is expired. Please get a new one from Bank of Los Santos.")
		ejectATMCard(theATM, source)
		return false
	end
	local atmLocationName = exports.global:getElementZoneName(theATM)
	triggerClientEvent(source,"bank:ATMCardInteractions", source, theATM, foundAnATMCard, absX, absY, atmLocationName)
end
addEvent( "bank:checkInsideATMMachine", true )
addEventHandler( "bank:checkInsideATMMachine", getRootElement(), checkInsideATMMachine )

--[[function iAmTester(thePlayer)
	if setElementData(thePlayer, "IAmTester", not getElementData(thePlayer, "IAmTester"), true) then
		exports.hud:sendBottomNotification(thePlayer,"Maxime's Tester",( ( getElementData(thePlayer, "IAmTester") and "You're now a Maxime's Tester. Do not leak this cmd to new player. Thank you :3" ) or ("You're no longer a Maxime's Tester") ))
	end
end
addCommandHandler("iamtester",iAmTester)]]

function isAltToAlt(source, item)
	local result = exports.mysql:query_fetch_assoc("SELECT account FROM characters WHERE id='"..exports.mysql:escape_string(item).."'")
	if result then
		if tostring(result["account"]) == tostring(getElementData(source, "account:id")) then
			return true
		end
	end
	return false
end

function takeOutATMCard(theATM, item)
	local player = client
	if not validateATMInteraction(player, theATM)
		or type(item) ~= "table" or tonumber(item[1]) ~= 150
		or type(item[2]) ~= "string" or #item[2] > 256
		or not exports["item-system"]:loadItems(theATM) then
		return false
	end
	local hasStoredCard = exports["item-system"]:hasItem(theATM, 150, item[2])
	if not hasStoredCard then return false end
	local values = split(item[2], ";")
	local v = values and values[2]
	if not v or not tonumber(v) then return false end
	if tonumber(v) ~= tonumber(getElementData(source, "account:character:id")) then
		if isAltToAlt(source, v) then
			outputChatBox("Denied - Card Deleted.", source, 255, 0, 0)
			exports["item-system"]:takeItem(theATM, item[1], item[2])
			return
		end
	end
	if exports["item-system"]:takeItem(theATM, 150, item[2]) then
		if exports["item-system"]:giveItem(player, 150, item[2]) then
			triggerEvent("sendAme", player, "slips out an ATM card from the ATM machine's slot.")
			playAtmInsert(theATM)
			return true
		end
		if not exports["item-system"]:giveItem(theATM, 150, item[2]) then
			outputDebugString("[BANK] Failed to restore ATM card to machine after inventory grant failure.", 1)
			outputChatBox("The ATM card could not be restored. Please contact staff immediately.", player, 255, 0, 0)
		end
		triggerEvent("sendAme", player, "tries to slip an ATM card out of the ATM machine's slot but fails.")
		exports.hud:sendBottomNotification(player, "ATM Machine", "Your inventory is full.")
		return false
	end
	triggerEvent("sendAme", player, "tries to slip an ATM card out of the ATM machine's slot but fails.")
	return false
end
addEvent( "bank:takeOutATMCard", true )
addEventHandler( "bank:takeOutATMCard", getRootElement(), takeOutATMCard )


local cooldownSec = 5000

function applyForNewATMCard(replacingOldATMCard, limitType)
	local player = client or source
	if not isAuthenticatedBankPlayer(player)
		or (replacingOldATMCard ~= nil and type(replacingOldATMCard) ~= "boolean") then
		return false
	end
	local charID = tonumber(getElementData(player, "dbid"))
	if not charID or charID < 1 or charID ~= math.floor(charID) then return false end

	limitType = tonumber(limitType) or 1
	if limitType ~= 1 and limitType ~= 2 and limitType ~= 3 then return false end
	local price = limitType == 1 and 50 or (limitType == 2 and 200 or 500)
	local playerName = getPlayerName(player)
	local playerGender = tonumber(getElementData(player, "gender")) == 0 and "sir" or "madam"

	local oldCard
	local existing = mysql:query_fetch_assoc("SELECT card_id, card_owner, card_number, card_pin, card_locked, card_type, limit_type "
		.. "FROM atm_cards WHERE card_type = '1' AND card_owner = " .. charID .. " LIMIT 1")
	if replacingOldATMCard then
		if existing and existing.card_id then
			oldCard = existing
			local oldCardID = tonumber(oldCard.card_id)
			if not oldCardID or oldCardID < 1 then return false end
			if not mysql:query_free("DELETE FROM atm_cards WHERE card_id = " .. oldCardID
				.. " AND card_owner = " .. charID .. " LIMIT 1") then
				exports.hud:sendBottomNotification(player, "SQL Error", "Your previous ATM card could not be replaced. No new card was issued.")
				return false
			end
		end
	elseif existing and existing.card_id then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'I'm sorry, " .. playerGender .. ", but we don't allow multiple ATM cards.'")
		triggerClientEvent(player, "atm:atmCardExisted", player)
		return false
	else
		triggerClientEvent(player, "atm:chooseAtm", player)
		return false
	end

	local function restoreOldCard()
		if not oldCard then return true end
		local restored = mysql:query_free("INSERT INTO atm_cards (card_id, card_owner, card_number, card_pin, card_locked, card_type, limit_type) VALUES ("
			.. tonumber(oldCard.card_id) .. ", " .. charID .. ", '" .. tostring(oldCard.card_number)
			.. "', '" .. tostring(oldCard.card_pin or "0000") .. "', "
			.. tonumber(oldCard.card_locked or 0) .. ", " .. tonumber(oldCard.card_type or 1) .. ", "
			.. tonumber(oldCard.limit_type or 1) .. ")")
		if not restored then
			outputDebugString("[BANK] CRITICAL: failed to restore previous ATM card record for character #" .. charID, 1)
			outputChatBox("Your previous ATM card could not be restored. Contact staff immediately.", player, 255, 0, 0)
		end
		return restored
	end

	if not exports["item-system"]:loadItems(player) or not exports.global:hasSpaceForItem(player, 150, 1) then
		restoreOldCard()
		exports.hud:sendBottomNotification(player, "Inventory", "Your inventory is full or unavailable. No ATM card was issued.")
		return false
	end

	local cardNumber
	for attempt = 1, 100 do
		local candidate = string.format("%04d %04d %04d %04d",
			math.random(0, 9999), math.random(0, 9999), math.random(0, 9999), math.random(0, 9999))
		local query = mysql:query("SELECT card_number FROM atm_cards WHERE card_number = '" .. candidate .. "' LIMIT 1")
		if not query then
			restoreOldCard()
			exports.hud:sendBottomNotification(player, "SQL Error", "The card number could not be reserved. Please try again.")
			return false
		end
		local row = mysql:fetch_assoc(query)
		mysql:free_result(query)
		if not row then
			cardNumber = candidate
			break
		end
	end
	if not cardNumber then
		restoreOldCard()
		exports.hud:sendBottomNotification(player, "SQL Error", "A unique card number could not be generated. Please try again.")
		return false
	end

	if not exports.global:takeMoney(player, price) then
		restoreOldCard()
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Could I have $" .. price .. " please, " .. playerGender .. "?'")
		return false
	end

	local cardValue = cardNumber .. ";" .. charID .. ";" .. limitType
	if not exports.global:giveItem(player, 150, cardValue) then
		local refunded = exports.global:giveMoney(player, price)
		local oldRestored = restoreOldCard()
		if not refunded or not oldRestored then
			outputDebugString("[BANK] CRITICAL: ATM card creation failed and rollback was incomplete for character #" .. charID, 1)
		end
		exports.hud:sendBottomNotification(player, "Internal Error", "The ATM card could not be added to your inventory. The fee has been refunded.")
		return false
	end

	local inserted = mysql:query_free("INSERT INTO atm_cards (card_owner, card_number, limit_type, card_type) VALUES ("
		.. charID .. ", '" .. cardNumber .. "', " .. limitType .. ", 1)")
	local saved = inserted and mysql:query_fetch_assoc("SELECT card_id FROM atm_cards WHERE card_owner = "
		.. charID .. " AND card_number = '" .. cardNumber .. "' AND card_type = 1 LIMIT 1")
	if not inserted or not saved or not saved.card_id then
		if not exports["item-system"]:takeItem(player, 150, cardValue) then
			outputDebugString("[BANK] Failed to remove unregistered ATM card item after insert failure for character #" .. charID, 1)
		end
		local refunded = exports.global:giveMoney(player, price)
		local oldRestored = restoreOldCard()
		if not refunded or not oldRestored then
			outputDebugString("[BANK] CRITICAL: ATM card database insert rollback was incomplete for character #" .. charID, 1)
			outputChatBox("ATM card creation rollback failed. Contact staff immediately.", player, 255, 0, 0)
		end
		exports.hud:sendBottomNotification(player, "SQL Error", "The ATM card could not be registered. The operation was rolled back.")
		return false
	end

	triggerEvent("sendAme", player, "takes some dollar notes and gives them to Maxime Du Trieux.")
	exports.global:sendLocalText(player, "* Maxime Du Trieux gives " .. tostring(playerName):gsub("_", " ") .. " a sleek plastic ATM card.", 255, 51, 102, 30, {}, true)
	exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Thank you, " .. playerGender .. "! Here is your ATM card (Card Number: '" .. cardNumber .. "', PIN: '0000').'")
	return true
end
addEvent( "bank:applyForNewATMCard", true )
addEventHandler( "bank:applyForNewATMCard", getRootElement(), applyForNewATMCard )

function lockATMCard()
	local player = client or source
	if not isAuthenticatedBankPlayer(player) then return false end
	local card = getPlayerATMCardRecord(player)
	if not card or not card.card_id then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'I cannot find an active ATM card for your profile.'")
		return false
	end
	if tostring(card.card_locked) == "1" then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your ATM card is already locked.'")
		return false
	end
	local cardID = tonumber(card.card_id)
	if not cardID or not mysql:query_free("UPDATE atm_cards SET card_locked = 1 WHERE card_id = "
		.. cardID .. " AND card_owner = " .. tonumber(getElementData(player, "dbid")) .. " AND card_locked = 0") then
		return false
	end
	local saved = mysql:query_fetch_assoc("SELECT card_locked FROM atm_cards WHERE card_id = " .. cardID .. " LIMIT 1")
	if not saved or tostring(saved.card_locked) ~= "1" then return false end
	exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your ATM Card with Card Number '" .. tostring(card.card_number) .. "' has been locked.'")
	return true
end

addEvent( "bank:lockATMCard", true )
addEventHandler( "bank:lockATMCard", getRootElement(), lockATMCard )

function unlockATMCard()
	local player = client or source
	if not isAuthenticatedBankPlayer(player) then return false end
	local card = getPlayerATMCardRecord(player)
	if not card or not card.card_id then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'I cannot find an ATM card for your profile.'")
		return false
	end
	if tostring(card.card_locked) == "0" then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your ATM card is already unlocked.'")
		return false
	end
	local cardID = tonumber(card.card_id)
	if not cardID or not mysql:query_free("UPDATE atm_cards SET card_locked = 0 WHERE card_id = "
		.. cardID .. " AND card_owner = " .. tonumber(getElementData(player, "dbid")) .. " AND card_locked = 1") then
		return false
	end
	local saved = mysql:query_fetch_assoc("SELECT card_locked FROM atm_cards WHERE card_id = " .. cardID .. " LIMIT 1")
	if not saved or tostring(saved.card_locked) ~= "0" then return false end
	exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your ATM Card with Card Number '" .. tostring(card.card_number) .. "' has been unlocked.'")
	return true
end

addEvent( "bank:unlockATMCard", true )
addEventHandler( "bank:unlockATMCard", getRootElement(), unlockATMCard )

function recoverATMCard()
	local player = client or source
	if not isAuthenticatedBankPlayer(player) then return false end
	local card = getPlayerATMCardRecord(player)
	if not card or not card.card_id or not validateATMCardNumber(card.card_number) then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'I cannot find an ATM card for your profile.'")
		return false
	end
	if tostring(card.card_locked) ~= "1" then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your ATM card is not locked. Please use the unlock service instead.'")
		return false
	end
	if not exports["item-system"]:loadItems(player)
		or not exports.global:hasSpaceForItem(player, 150, 1) then
		exports.hud:sendBottomNotification(player, "Inventory", "Your inventory is full or unavailable.")
		return false
	end

	local fee = 50
	if not exports.global:takeMoney(player, fee) then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Could I have $50 please?'")
		return false
	end
	local characterID = tonumber(getElementData(player, "dbid"))
	local cardValue = card.card_number .. ";" .. characterID .. ";" .. (tonumber(card.limit_type) or 1)
	if not exports.global:giveItem(player, 150, cardValue) then
		if not exports.global:giveMoney(player, fee) then
			outputDebugString("[BANK] Failed to refund ATM recovery fee after inventory grant failure for character #" .. characterID, 1)
		end
		return false
	end
	local updated = mysql:query_free("UPDATE atm_cards SET card_locked = 0 WHERE card_id = "
		.. tonumber(card.card_id) .. " AND card_owner = " .. characterID .. " AND card_locked = 1")
	local saved = updated and mysql:query_fetch_assoc("SELECT card_locked FROM atm_cards WHERE card_id = "
		.. tonumber(card.card_id) .. " LIMIT 1")
	if not saved or tostring(saved.card_locked) ~= "0" then
		if not exports["item-system"]:takeItem(player, 150, cardValue) then
			outputDebugString("[BANK] Failed to remove recovered ATM card item after database failure for character #" .. characterID, 1)
		end
		if not exports.global:giveMoney(player, fee) then
			outputDebugString("[BANK] Failed to refund ATM recovery fee after database failure for character #" .. characterID, 1)
			outputChatBox("ATM recovery failed and your fee refund could not be completed. Contact staff immediately.", player, 255, 0, 0)
		end
		return false
	end

	triggerEvent("sendAme", player, "takes some dollar notes and gives them to Maxime Du Trieux.")
	exports.global:sendLocalText(player, "* Maxime Du Trieux gives " .. tostring(getPlayerName(player)):gsub("_", " ") .. " a replacement ATM card.", 255, 51, 102, 30, {}, true)
	exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Here is your ATM card (Card Number: '" .. card.card_number .. "', PIN: '" .. tostring(card.card_pin or "0000") .. "').'")
	return true
end

addEvent( "bank:recoverATMCard", true )
addEventHandler( "bank:recoverATMCard", getRootElement(), recoverATMCard )

function cancelATMCard(replacingOldATMCard)
	local player = client or source
	if not isAuthenticatedBankPlayer(player)
		or (replacingOldATMCard ~= nil and type(replacingOldATMCard) ~= "boolean") then return false end
	local card = getPlayerATMCardRecord(player)
	if not card or not card.card_id then
		if not replacingOldATMCard then
			exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'I cannot find an ATM card for your profile.'")
		end
		return replacingOldATMCard == true
	end
	local characterID, cardID = tonumber(getElementData(player, "dbid")), tonumber(card.card_id)
	if not characterID or not cardID then return false end
	if not mysql:query_free("DELETE FROM atm_cards WHERE card_id = " .. cardID
		.. " AND card_owner = " .. characterID .. " LIMIT 1") then
		exports.hud:sendBottomNotification(player, "SQL Error", "Your ATM card could not be cancelled. Please try again.")
		return false
	end
	local remaining = mysql:query_fetch_assoc("SELECT card_id FROM atm_cards WHERE card_id = " .. cardID .. " LIMIT 1")
	if remaining then return false end

	local cardValue = tostring(card.card_number) .. ";" .. characterID .. ";" .. (tonumber(card.limit_type) or 1)
	if exports["item-system"]:loadItems(player) and exports["item-system"]:hasItem(player, 150, cardValue) then
		if not exports["item-system"]:takeItem(player, 150, cardValue) then
			outputDebugString("[BANK] ATM card record cancelled but inventory card could not be removed for character #" .. characterID, 1)
		end
	end
	if not replacingOldATMCard then
		exports.hud:sendBottomNotification(player, "Maxime Du Trieux says:", "'Your previous ATM card with number '" .. tostring(card.card_number) .. "' has been terminated.'")
	end
	return true
end

addEvent( "bank:cancelATMCard", true )
addEventHandler( "bank:cancelATMCard", getRootElement(), cancelATMCard )

local retryPIN = {}
function checkPINCode(theATM, enteredCode)
	local player = client
	if not validateATMInteraction(player, theATM)
		or type(enteredCode) ~= "string" or not enteredCode:match("^%d%d%d%d$") then return false end
	if not exports["item-system"]:loadItems(theATM) then return false end
	local cardItem = getATMCardFromATMMachine(theATM)
	if type(cardItem) ~= "table" or tonumber(cardItem[1]) ~= 150 then
		exports.hud:sendBottomNotification(player, "ATM Machine is not working properly!", "Please reinsert your ATM card.")
		return false
	end
	local cardOwner, cardNumber, cardOwnerCharID, amountLimit = getCardInfo(cardItem)
	if not validateATMCardNumber(cardNumber) or not tonumber(cardOwnerCharID) then return false end
	local record = mysql:query_fetch_assoc("SELECT card_owner, card_locked, card_pin FROM atm_cards WHERE card_number = '"
		.. cardNumber .. "' AND card_type = 1 LIMIT 1")
	if not record or tonumber(record.card_owner) ~= tonumber(cardOwnerCharID) then
		triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "The ATM card could not be verified. Please contact the bank.", 255, 0, 0, "locked", cardNumber)
		return false
	end
	if tostring(record.card_pin) ~= enteredCode then
		retryPIN[player] = (retryPIN[player] or 0) + 1
		if retryPIN[player] < 3 then
			triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "Access Denied (" .. retryPIN[player] .. "/3)", 255, 0, 0, "failedLessThan3", retryPIN[player])
		else
			local locked = mysql:query_free("UPDATE atm_cards SET card_locked = 1 WHERE card_number = '" .. cardNumber
				.. "' AND card_owner = " .. tonumber(cardOwnerCharID) .. " AND card_locked = 0")
			local verified = locked and mysql:query_fetch_assoc("SELECT card_locked FROM atm_cards WHERE card_number = '"
				.. cardNumber .. "' LIMIT 1")
			if verified and tostring(verified.card_locked) == "1" then
				triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "Access Denied (3/3)", 255, 0, 0, "failedMoreThan3", 3)
				exports["item-system"]:clearItems(theATM)
			else
				triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "PIN could not be verified. Please try again later.", 255, 0, 0, "failedLessThan3", retryPIN[player])
			end
			retryPIN[player] = 0
		end
		return false
	end
	if tostring(record.card_locked) == "1" then
		triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "ERROR: This ATM card is not usable.", 255, 0, 0, "locked", cardNumber)
		retryPIN[player] = 0
		return false
	end

	local owner = fetchATMCardOwner(cardNumber)
	if not owner or owner.id ~= tonumber(cardOwnerCharID) then return false end
	retryPIN[player] = 0
	triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "Access Granted!", 70, 255, 14, "success")
	local deposit = tonumber(getElementData(theATM, "depositable")) == 1
	local limit = getElementData(theATM, "limit")
	local isDefaultPIN = enteredCode == "0000"
	triggerClientEvent(player, "bank:openATMGrantedGUI", root,
		{cardOwner, cardNumber, owner.balance, owner.id, amountLimit}, deposit, limit, true,
		theATM, exports.global:getElementZoneName(theATM), isDefaultPIN)
	return true
end

addEvent( "bank:checkPINCode", true )
addEventHandler( "bank:checkPINCode", getRootElement(), checkPINCode )

function ejectATMCard(theATM)
	local player = client or source
	if not isAuthenticatedBankPlayer(player) or not isATMNearPlayer(player, theATM) then return false end
	if not exports["item-system"]:loadItems(theATM) then return false end
	local card = getATMCardFromATMMachine(theATM)
	if type(card) ~= "table" or tonumber(card[1]) ~= 150 then return false end
	local cardValue = tostring(card[2])
	if not exports["item-system"]:takeItem(theATM, 150, cardValue) then return false end
	if exports["item-system"]:giveItem(player, 150, cardValue) then
		triggerEvent("sendAme", player, "slips out an ATM card from the ATM machine's slot.")
		playAtmInsert(theATM)
		return true
	end
	if not exports["item-system"]:giveItem(theATM, 150, cardValue) then
		outputDebugString("[BANK] Failed to restore ATM card to ATM after ejection inventory failure.", 1)
		outputChatBox("ATM card ejection rollback failed. Contact staff immediately.", player, 255, 0, 0)
	end
	exports.hud:sendBottomNotification(player, "ATM Machine", "Your inventory is full.")
	return false
end

addEvent( "bank:ejectATMCard", true )
addEventHandler( "bank:ejectATMCard", getRootElement(), ejectATMCard )

function changePIN(theATM, enteredCode)
	local player = client
	if not validateATMInteraction(player, theATM)
		or type(enteredCode) ~= "string" or not enteredCode:match("^%d%d%d%d$")
		or enteredCode == "0000" then
		return false
	end
	if not exports["item-system"]:loadItems(theATM) then return false end
	local card = getATMCardFromATMMachine(theATM)
	if type(card) ~= "table" or tonumber(card[1]) ~= 150 then return false end
	local _, cardNumber, ownerID = getCardInfo(card)
	if not validateATMCardNumber(cardNumber) or not tonumber(ownerID) then return false end
	local updated = mysql:query_free("UPDATE atm_cards SET card_pin = '" .. enteredCode
		.. "' WHERE card_number = '" .. cardNumber .. "' AND card_owner = " .. tonumber(ownerID)
		.. " AND card_locked = 0 AND card_type = 1")
	local saved = updated and mysql:query_fetch_assoc("SELECT card_pin FROM atm_cards WHERE card_number = '"
		.. cardNumber .. "' AND card_owner = " .. tonumber(ownerID) .. " LIMIT 1")
	if not saved or tostring(saved.card_pin) ~= enteredCode then
		exports.hud:sendBottomNotification(player, "SQL Error", "The PIN could not be changed. Please try again.")
		triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "The PIN could not be changed.", 255, 0, 0, "changedPIN", "failed")
		return false
	end
	triggerClientEvent(player, "bank:respondToATMInterfacePIN", player, "PIN Code is successfully changed!", 0, 255, 0, "changedPIN", "ok")
	exports.hud:sendBottomNotification(player, "ATM Machine", "Your ATM card PIN was changed successfully.")
	return true
end

addEvent( "bank:changePIN", true )
addEventHandler( "bank:changePIN", getRootElement(), changePIN )

function withdrawATMMoneyPersonal(amount, theATM)
	local player = client
	amount = validateATMAmount(amount)
	if not player or not amount or not validateATMInteraction(player, theATM) then return false end

	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if type(foundAnATMCard) ~= "table" or tonumber(foundAnATMCard[1]) ~= 150 then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "ATM Machine is not working properly. Please reinsert your card.")
		return false
	end
	local cardOwner, cardNumber, cardOwnerCharID, limitType = getCardInfo(foundAnATMCard)
	local owner = fetchATMCardOwner(cardNumber)
	if not owner or tonumber(cardOwnerCharID) ~= owner.id then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The ATM card is invalid or disabled. Please contact the bank.")
		return false
	end

	local withinLimit, limitReason = isThisTransactionWithinLimitation(cardNumber, amount, limitType)
	if not withinLimit then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, limitReason)
		return false
	end
	local altCheck = areYouAltAlting(player, { cardOwner, cardNumber, owner.id })
	if altCheck then
		exports.global:sendMessageToAdmins("[BANK] " .. getPlayerName(player) .. " attempted an ATM withdrawal from an alternate character's card (" .. tostring(altCheck) .. ").")
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "You cannot transfer money between your own characters.")
		disableATMCard(cardNumber)
		exports["item-system"]:clearItems(theATM)
		return false
	end

	local atmFee, bankFactionID = 2, 17
	local totalDebit = amount + atmFee
	if owner.balance < totalDebit then
		exports.hud:sendBottomNotification(player, "ATM Machine", "ATM card '" .. cardNumber .. "' does not have enough funds.")
		return false
	end
	local ownerElement = exports.pool:getElement("playerByDbid", owner.id)
	if isElement(ownerElement) and tonumber(getElementData(ownerElement, "bankmoney")) ~= owner.balance then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The account balance changed. Please try again.")
		return false
	end

	if not adjustATMCardOwnerBalance(player, owner.id, isElement(ownerElement) and ownerElement or nil, totalDebit, "minus") then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The ATM card does not have enough available funds.")
		return false
	end

	local cashCredited = exports.global:giveMoney(player, amount) == true
	if not cashCredited then
		if not adjustATMCardOwnerBalance(player, owner.id, isElement(ownerElement) and ownerElement or nil, totalDebit, "plus") then
			outputDebugString("[BANK] Failed to reverse ATM withdrawal after cash credit failure for card " .. cardNumber, 1)
			outputChatBox("ATM withdrawal failed and the bank refund could not be completed. Contact staff immediately.", player, 255, 0, 0)
		end
		return false
	end

	local bankFaction = exports.factions:getFactionFromID(bankFactionID)
	if not isElement(bankFaction) or not exports.global:giveMoney(bankFaction, atmFee) then
		local cashReversed = exports.global:takeMoney(player, amount)
		local bankReversed = adjustATMCardOwnerBalance(player, owner.id, isElement(ownerElement) and ownerElement or nil, totalDebit, "plus")
		if not cashReversed or not bankReversed then
			outputDebugString("[BANK] Failed to roll back ATM withdrawal after fee credit failure for card " .. cardNumber, 1)
			outputChatBox("ATM withdrawal rollback failed. Contact staff immediately.", player, 255, 0, 0)
		end
		return false
	end

	addTransactionLimit(cardNumber, amount, limitType)
	local remaining = owner.balance - totalDebit
	local atmName = getATMName(theATM)
	addBankTransactionLog(owner.id, nil, amount, 0, nil, "Withdrew from " .. atmName, cardNumber, nil)
	exports.logs:dbLog(player, 25, player, "WITHDREW $" .. amount .. " - REMAINING $" .. remaining .. " FROM (" .. owner.name .. ", " .. cardNumber .. ", " .. atmName .. ")")
	exports.hud:sendBottomNotification(player, "ATM Machine", "You withdrew $" .. exports.global:formatMoney(amount) .. " from ATM Card '" .. cardNumber .. "' (Owner: '" .. no_(owner.name) .. "').")
	triggerEvent("bank:ejectATMCard", player, theATM)
	return true
end
addEvent("bank:withdrawATMMoneyPersonal", true)
addEventHandler("bank:withdrawATMMoneyPersonal", getRootElement(), withdrawATMMoneyPersonal)

function depositATMMoneyPersonal(amount, theATM)
	local player = client
	amount = validateATMAmount(amount)
	if not player or not amount or not validateATMInteraction(player, theATM) then return false end

	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if type(foundAnATMCard) ~= "table" or tonumber(foundAnATMCard[1]) ~= 150 then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "ATM Machine is not working properly. Please reinsert your card.")
		return false
	end
	local cardOwner, cardNumber, cardOwnerCharID = getCardInfo(foundAnATMCard)
	local owner = fetchATMCardOwner(cardNumber)
	if not owner or tonumber(cardOwnerCharID) ~= owner.id then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The ATM card is invalid or disabled. Please contact the bank.")
		return false
	end

	local altCheck = areYouAltAlting(player, { cardOwner, cardNumber, owner.id })
	if altCheck then
		exports.global:sendMessageToAdmins("[BANK] " .. getPlayerName(player) .. " attempted an ATM deposit to an alternate character's card (" .. tostring(altCheck) .. ").")
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "You cannot transfer money between your own characters.")
		disableATMCard(cardNumber)
		exports["item-system"]:clearItems(theATM)
		return false
	end

	local ownerElement = exports.pool:getElement("playerByDbid", owner.id)
	if isElement(ownerElement) and tonumber(getElementData(ownerElement, "bankmoney")) ~= owner.balance then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The account balance changed. Please try again.")
		return false
	end
	if owner.balance + amount > 2000000000 then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The recipient's bank account cannot accept that amount.")
		return false
	end

	if not exports.global:takeMoney(player, amount, nil, true) then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "You do not have enough available cash.")
		return false
	end

	if not adjustATMCardOwnerBalance(player, owner.id, isElement(ownerElement) and ownerElement or nil, amount, "plus") then
		if not exports.global:giveMoney(player, amount, true) then
			outputDebugString("[BANK] Failed to refund cash after ATM deposit credit failure for card " .. cardNumber, 1)
			outputChatBox("ATM deposit failed and your cash refund could not be completed. Contact staff immediately.", player, 255, 0, 0)
		end
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The bank account could not be credited. Your cash was returned.")
		return false
	end

	local atmName = getATMName(theATM)
	addBankTransactionLog(nil, owner.id, amount, 1, nil, "Deposited from " .. atmName, nil, cardNumber)
	exports.logs:dbLog(player, 25, player, "DEPOSITED $" .. amount .. " - NEW BALANCE $" .. (owner.balance + amount) .. " TO (" .. owner.name .. ", " .. cardNumber .. ", " .. atmName .. ")")
	exports.hud:sendBottomNotification(player, "ATM Machine", "You deposited $" .. exports.global:formatMoney(amount) .. " to ATM Card '" .. cardNumber .. "' (Owner: '" .. no_(owner.name) .. "').")
	triggerEvent("bank:ejectATMCard", player, theATM)
	return true
end
addEvent("bank:depositATMMoneyPersonal", true)
addEventHandler("bank:depositATMMoneyPersonal", getRootElement(), depositATMMoneyPersonal)

function transferATMMoneyToPersonal(theATM, amount, targetBankAccNo, reason)
	local player = client
	amount = validateATMAmount(amount)
	if not player or not amount or not validateATMInteraction(player, theATM)
		or type(targetBankAccNo) ~= "string" or #targetBankAccNo < 1
		or #targetBankAccNo > 64 or targetBankAccNo:find("[%c]") then
		return false
	end
	if reason ~= nil and (type(reason) ~= "string" or #reason > 128 or reason:find("[%c]")) then
		return false
	end
	reason = reason or ""

	local atmCard = getATMCardFromATMMachine(theATM)
	if type(atmCard) ~= "table" or tonumber(atmCard[1]) ~= 150 then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "ATM Machine is not working properly. Please reinsert your card.")
		return false
	end
	local cardOwner, cardNumber, cardOwnerID, limitType = getCardInfo(atmCard)
	local sender = fetchATMCardOwner(cardNumber)
	if not sender or tonumber(cardOwnerID) ~= sender.id then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The ATM card is invalid or disabled. Please contact the bank.")
		return false
	end

	local withinLimit, limitReason = isThisTransactionWithinLimitation(cardNumber, amount, limitType)
	if not withinLimit then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, limitReason)
		return false
	end

	local senderElement = exports.pool:getElement("playerByDbid", sender.id)
	if isElement(senderElement) and tonumber(getElementData(senderElement, "bankmoney")) ~= sender.balance then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The sender account balance changed. Please try again.")
		return false
	end

	local targetFaction = getTeamFromName(targetBankAccNo:gsub("_", " "))
	local target, targetElement, targetID, targetName, targetBalance
	if targetFaction and isElement(targetFaction) then
		targetID = tonumber(getElementData(targetFaction, "id"))
		if not targetID or targetID < 1 then return false end
		targetName = getTeamName(targetFaction)
		target = targetFaction
	else
		if not validateATMCardNumber(targetBankAccNo) then
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The target ATM card number is invalid.")
			return false
		end
		target = fetchATMCardOwner(targetBankAccNo)
		if not target then
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "Target bank account does not exist or is disabled.")
			return false
		end
		if target.id == sender.id then
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "You cannot transfer money to the same account.")
			return false
		end
		local altCheck = areYouAltAlting(player, { cardOwner, cardNumber, sender.id }, target.id)
		if altCheck then
			exports.global:sendMessageToAdmins("[BANK] " .. getPlayerName(player) .. " attempted an ATM transfer to an alternate character's card (" .. tostring(altCheck) .. ").")
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "You cannot transfer money between your own characters.")
			disableATMCard(cardNumber)
			exports["item-system"]:clearItems(theATM)
			return false
		end
		targetID, targetName, targetBalance = target.id, target.name, target.balance
		targetElement = exports.pool:getElement("playerByDbid", target.id)
		if isElement(targetElement) and tonumber(getElementData(targetElement, "bankmoney")) ~= target.balance then
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The recipient account balance changed. Please try again.")
			return false
		end
		if target.balance + amount > 2000000000 then
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The recipient's bank account cannot accept that amount.")
			return false
		end
	end

	if sender.balance < amount then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The source ATM card does not have enough funds.")
		return false
	end

	local sourceDebited = adjustATMCardOwnerBalance(player, sender.id,
		isElement(senderElement) and senderElement or nil, amount, "minus")
	if not sourceDebited then
		triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The source account could not be debited. Please try again.")
		return false
	end

	local targetCredited
	if targetFaction then
		targetCredited = exports.global:giveMoney(targetFaction, amount) == true
	else
		targetCredited = adjustATMCardOwnerBalance(player, target.id,
			isElement(targetElement) and targetElement or nil, amount, "plus")
	end

	if not targetCredited then
		local sourceRefunded = adjustATMCardOwnerBalance(player, sender.id,
			isElement(senderElement) and senderElement or nil, amount, "plus")
		if not sourceRefunded then
			outputDebugString("[BANK] Failed to roll back ATM transfer debit from source card " .. cardNumber, 1)
			outputChatBox("The transfer failed and the source account refund could not be completed. Contact staff immediately.", player, 255, 0, 0)
		else
			triggerClientEvent(player, "bank:respondToPendingTransfer", player, "The recipient account could not be credited. Your transfer was cancelled.")
		end
		return false
	end

	addTransactionLimit(cardNumber, amount, limitType)
	local targetLabel = targetFaction and getTeamName(targetFaction):gsub("_", " ") or (targetName or "Unknown")
	local atmName = getATMName(theATM)
	local destinationAccountID = targetFaction and -targetID or targetID
	addBankTransactionLog(sender.id, destinationAccountID, amount, 2, reason,
		"Transferred from " .. atmName, cardNumber, targetFaction and nil or targetBankAccNo)
	exports.logs:dbLog(player, 25, player,
		"TRANSFERRED $" .. amount .. " FROM (" .. sender.name .. ", " .. cardNumber .. ") TO (" .. targetLabel .. ") REASON (" .. reason .. ", " .. atmName .. ")")
	triggerClientEvent(player, "bank:respondToPendingTransfer", player,
		"You successfully transferred $" .. exports.global:formatMoney(amount) .. " to '" .. targetLabel .. "'.", true)
	triggerEvent("bank:ejectATMCard", player, theATM)
	return true
end
addEvent("bank:transferATMMoneyToPersonal", true)
addEventHandler("bank:transferATMMoneyToPersonal", getRootElement(), transferATMMoneyToPersonal)

function tellTransfersHistory(cardInfo)
	--outputDebugString(cardInfo[1])
	--outputDebugString(cardInfo[2])
	--outputDebugString(cardInfo[3])

end
addEvent( "tellTransfersHistory", true )
addEventHandler( "tellTransfersHistory", getRootElement(), tellTransfersHistory )

function tellATMTransfers(source, cardInfo, event)
	local accountName = tostring(cardInfo[1]):gsub("'", "''")
	local where = "( `from` = '" ..accountName.. "' OR `to` = '" .. accountName .. "' )"
	--where = where .. " AND type != 4 AND type != 5"

	local query = mysql:query("SELECT w.*, a.charactername as characterfrom, b.charactername as characterto,w.`time` - INTERVAL 1 hour as 'newtime' FROM ATM_wiretransfers w LEFT JOIN characters a ON a.id = `from` LEFT JOIN characters b ON b.id = `to` WHERE " .. mysql:escape_string(where) .. " ORDER BY id DESC LIMIT 40")
	if query then
		local continue = true
		while continue do
			row = mysql:fetch_assoc(query)
			if not row then break end

			local id = tonumber(row["id"])
			local amount = tonumber(row["amount"])
			local time = row["newtime"]
			local type = tonumber(row["type"])
			local reason = row["reason"]
			if reason == mysql_null() then
				reason = ""
			end

			local from, to = "-", "-"
			if row["characterfrom"] ~= mysql_null() then
				from = row["characterfrom"]:gsub("_", " ")
			elseif tonumber(row["from"]) then
				num = tonumber(row["from"])
				if num < 0 then
					from = "-" or getTeamName(exports.pool:getElement("team", -num))
				elseif num == 0 and ( type == 6 or type == 7 ) then
					from = "Government"
				end
			end
			if row["characterto"] ~= mysql_null() then
				to = row["characterto"]:gsub("_", " ")
			elseif tonumber(row["to"]) and tonumber(row["to"]) < 0 then
				to = getTeamName(exports.pool:getElement("team", -tonumber(row["to"])))
			end

			if tostring(row["from"]) == tostring(dbid) and amount > 0 then
				amount = amount - amount - amount
			end


			--if type >= 2 and type <= 5 and tonumber(row['from']) == dbid then
			--	amount = -amount
			--end

			--[[if amount < 0 then
				amount = "-$" .. -amount
			else
				amount = "$" .. amount
			end]]

			triggerClientEvent(source, event, source, id, amount, time, type, from, to, reason)
		end
		mysql:free_result(query)
	else
		outputDebugString("Mysql error @ s_bank_system.lua\tellTransfers", 2)
	end
end


function cleanUp()
	for key, element in pairs(getElementsByType("object", resourceRoot)) do
		if getElementModel(element) == 2942 then
			local items = exports["item-system"]:getItems(element)
			if items and items[1] then
				exports.global:takeItem(element, items[1][1], items[1][2])
			end
		end
	end
end
addEventHandler("onResourceStop", resourceRoot, cleanUp)
