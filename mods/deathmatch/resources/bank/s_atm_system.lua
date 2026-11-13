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
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "sir" or "madam"
	local charID = getElementData(source,"dbid")
	--[[
	if not replacingOldATMCard and cooldown[source] and ((getTickCount() - cooldown[source]) < 1000*cooldownSec) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry, "..playerGender..". Our system is currently busy, please come back later'")
		return false
	end
	]]

	if not replacingOldATMCard then
		local check = mysql:query_fetch_assoc("SELECT * FROM `atm_cards` WHERE `card_type`='1' AND `card_owner`='"..charID.."' ")
		if check then
			if check["card_id"] then
				exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry,"..playerGender.." but we don't allow multiple ATM cards'")
				triggerClientEvent(source, "atm:atmCardExisted", source)
				return false
			end
		else
			triggerClientEvent(source, "atm:chooseAtm", source)
			return false
		end
	else
		triggerEvent("bank:cancelATMCard", source, true)
	end

	local numSum = false
	while true do
		local num1 = tostring(math.random(0,9999))
		local num2 = tostring(math.random(0,9999))
		local num3 = tostring(math.random(0,9999))
		local num4 = tostring(math.random(0,9999))
		numSum = num1.." "..num2.." "..num3.." "..num4
		--outputDebugString(numSum)
		if string.len(numSum) == 19 then
			local checkNumber = mysql:query_fetch_assoc("SELECT `card_number` FROM `atm_cards` WHERE `card_number`='"..numSum.."' ")
			if (not checkNumber or checkNumber["card_number"]==mysql_null() or checkNumber["card_number"] ~= numSum) then
				break
			end
		end
	end

	if not numSum then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE01 has occured in Bank System. Please report this on http://bugs.owlgaming.net")
		return false
	end

	if not exports.global:hasSpaceForItem(source, 150, 1) then
		exports.hud:sendBottomNotification(source, "Inventory", "Your inventory is full. Please clear them up and retry.")
		return false
	end

	if not limitType then
		limitType = 1
	end

	if limitType == 2 then
		if not exports.global:takeMoney(source, 200) then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Could I have $200 please, "..playerGender.."'.")
			return false
		end
	elseif limitType == 3 then
		if not exports.global:takeMoney(source, 500) then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Could I have $500 please, "..playerGender.."'.")
			return false
		end
	else
		if not exports.global:takeMoney(source, 50) then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Could I have $50 please, "..playerGender.."'.")
			return false
		end
	end

	if not exports.global:giveItem(source, 150, numSum..";"..charID..";"..limitType) then
		exports.hud:sendBottomNotification(source, "Internal Error", "An SQL Error CODE0223 has occured in Bank System. Please report this on http://bugs.owlgaming.net.")
		return false
	end

	local makeNewCard = mysql:query_free("INSERT INTO `atm_cards`(`card_owner`, `card_number`, `limit_type`) VALUES ('"..tostring(charID).."', '"..numSum.."', '"..limitType.."') ")
	if not makeNewCard then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE02 has occured in Bank System. Please report this on http://bugs.owlgaming.net.")
		return false
	end

	triggerEvent('sendAme', source, "takes some dollar notes and gives them to Maxime Du Trieux.")
	exports.global:sendLocalText(source, "* Maxime Du Trieux gives "..tostring(playerName):gsub("_"," ").." a sleek plastic ATM card.", 255, 51, 102, 30, {}, true)

	exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Thank you,"..playerGender.."! Here is your ATM card (Card Number: '"..numSum.."', PIN: '0000').'")

	--cooldown[source] = getTickCount()
end
addEvent( "bank:applyForNewATMCard", true )
addEventHandler( "bank:applyForNewATMCard", getRootElement(), applyForNewATMCard )

function lockATMCard()
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "sir" or "madam"
	local charID = getElementData(source,"dbid")
	--[[
	if cooldown[source] and ((getTickCount() - cooldown[source]) < 1000*cooldownSec) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry, "..playerGender..". Our system is currently busy, please come back later'")
		return false
	end
	]]

	local iban = ""
	local check = mysql:query_fetch_assoc("SELECT `card_id`, `card_locked`, `card_pin`, `card_number` FROM `atm_cards` WHERE `card_type`='1' AND `card_owner`='"..tostring(charID).."' ")
	if check and check["card_locked"] then
		iban = check["card_number"]
		if check["card_locked"] == "1" then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Oh well, I think your ATM card had been locked already'.")
			return false
		end
	else
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Hm..are you sure you have applied for one in here,"..playerGender.."? Because I can't find your profile in our database'.")
		return false
	end

	local cardID = check["card_id"]

	local lockATMCard = mysql:query_free("UPDATE `atm_cards` SET `card_locked`='1' WHERE `card_id` = '".. cardID .."' ")
	if not lockATMCard then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE03 has occured in Bank System. Please report this to admin Maxime.")
		return false
	end

	exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Your ATM Card with Card Number '"..iban.."' has been locked, "..playerGender.."'.")
	--cooldown[source] = getTickCount()
end
addEvent( "bank:lockATMCard", true )
addEventHandler( "bank:lockATMCard", getRootElement(), lockATMCard )

function unlockATMCard()
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "sir" or "madam"
	local charID = getElementData(source,"dbid")
	--[[
	if cooldown[source] and ((getTickCount() - cooldown[source]) < 1000*cooldownSec) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry, "..playerGender..". Our system is currently busy, please come back later'")
		return false
	end
	]]

	local iban = ""
	local check = mysql:query_fetch_assoc("SELECT `card_id`, `card_locked`, `card_pin`, `card_number` FROM `atm_cards` WHERE `card_owner`='"..tostring(charID).."' ")
	if check and check["card_locked"] then
		iban = check["card_number"]
		if check["card_locked"] == "0" then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Oh well, I think your ATM card wasn't locked at all'.")
			return false
		end
	else
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Hm..are you sure you have applied for one in here,"..playerGender.."? Because I can't find your profile in our database'.")
		return false
	end

	local cardID = check["card_id"]

	local unlockATMCard = mysql:query_free("UPDATE `atm_cards` SET `card_locked`='0' WHERE `card_id` = '".. cardID .."' ")
	if not unlockATMCard then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE03 has occured in Bank System. Please report this to admin Maxime.")
		return false
	end

	exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Your ATM Card with Card Number '"..iban.."' has been unlocked, "..playerGender.."'.")
	--cooldown[source] = getTickCount()
end
addEvent( "bank:unlockATMCard", true )
addEventHandler( "bank:unlockATMCard", getRootElement(), unlockATMCard )

function recoverATMCard()
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "sir" or "madam"
	local charID = getElementData(source,"dbid")
	--[[
	if cooldown[source] and ((getTickCount() - cooldown[source]) < 1000*cooldownSec) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry, "..playerGender..". Our system is currently busy, please come back later'")
		return false
	end
	]]

	local iban = ""
	local bankPin = ""
	local check = mysql:query_fetch_assoc("SELECT `card_id`, `card_locked`, `card_pin`, `card_number`, `limit_type` FROM `atm_cards` WHERE `card_owner`='"..tostring(charID).."' ")
	if check and check["card_number"] then
		iban = check["card_number"]
		bankPin = check["card_pin"]
		-- if check["card_locked"] == "0" then
			-- exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Oh well, I think your ATM card wasn't locked at all'.")
			-- return false
		-- end
	else
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Hm..are you sure you have applied for one in here,"..playerGender.."? Because I can't find your profile in our database'.")
		return false
	end
	local cardID = check["card_id"]

	if not exports.global:takeMoney(source, 50) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Could I have $50 please, "..playerGender.."'.")
		return false
	end

	local recoverATMCard = mysql:query_free("UPDATE `atm_cards` SET `card_locked`='0' WHERE `card_id` = '".. cardID .."' ")
	if not recoverATMCard then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE04 has occured in Bank System. Please report this to admin Maxime.")
		return false
	end

	if not exports.global:giveItem(source, 150, iban..";"..charID..";"..check['limit_type']) then
		exports.global:giveMoney(source, 50)
		exports.hud:sendBottomNotification(source, "Inventory", "Your inventory is full. Please clear them up and retry. $50 has been refunded.")
		return false
	end

	triggerEvent('sendAme', source, "takes some dollar notes and gives them to Maxime Du Trieux.")
	exports.global:sendLocalText(source, "* Maxime Du Trieux gives "..tostring(playerName):gsub("_"," ").." a sleek plastic ATM card.", 255, 51, 102, 30, {}, true)

	exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Thank you,"..playerGender.."! Here is your ATM card (Card Number: '"..iban.."', PIN: '"..bankPin.."').'")

	--cooldown[source] = getTickCount()
end
addEvent( "bank:recoverATMCard", true )
addEventHandler( "bank:recoverATMCard", getRootElement(), recoverATMCard )

function cancelATMCard(replacingOldATMCard)
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "Sir" or "Ma'am"
	local charID = getElementData(source,"dbid")
	--[[
	if not replacingOldATMCard and cooldown[source] and ((getTickCount() - cooldown[source]) < 1000*cooldownSec) then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'I'm sorry, "..playerGender..". Our system is currently busy, please come back later.'")
		return false
	end
	]]

	local iban = ""
	local bankPin = ""
	local check = mysql:query_fetch_assoc("SELECT `card_id`, `card_locked`, `card_pin`, `card_number` FROM `atm_cards` WHERE `card_owner`='"..tostring(charID).."' ")
	if check and check["card_number"] then
		iban = check["card_number"]
		bankPin = check["card_pin"]
		-- if check["card_locked"] == "0" then
			-- exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Oh well, I think your ATM card wasn't locked at all'.")
			-- return false
		-- end
	else
		if not replacingOldATMCard then
			exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Hmm... Are you sure you have applied for one in here, "..playerGender.."? Because I can't find your profile in our database'.")
			return false
		end
	end

	local cancelATMCard = mysql:query_free("DELETE FROM `atm_cards` WHERE `card_owner`='"..tostring(charID).."' ")
	if not cancelATMCard then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE05 has occured in Bank System. Please report this to admin Maxime.")
		return false
	end
	if not replacingOldATMCard then
		exports.hud:sendBottomNotification(source, "Maxime Du Trieux says:", "'Alright, I've just terminated your previous ATM card with number '"..iban.."', "..playerGender.."!'")
	end

	--cooldown[source] = getTickCount()
end
addEvent( "bank:cancelATMCard", true )
addEventHandler( "bank:cancelATMCard", getRootElement(), cancelATMCard )

local retryPIN = {}
function checkPINCode(theATM, enteredCode)
	local playerName = getPlayerName(source)
	local playerGender = (getElementData(source,"gender") == 0) and "sir" or "madam"

	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if not foundAnATMCard then
		exports.hud:sendBottomNotification(source,"ATM Machine is not working properly!", "This is really weird, the card you've just inserted, It's gone magically!")
		return false
	end

	local cardOwner, cardNumber, cardOwnerCharID = getCardInfo(foundAnATMCard)
	--outputDebugString(cardOwner.." - "..cardNumber.." - "..cardOwnerCharID)
	local check = mysql:query_fetch_assoc("SELECT `card_locked`, `card_pin`, `card_number` FROM `atm_cards` WHERE `card_number`='"..cardNumber.."' AND `card_pin`='"..enteredCode.."' ")
	if not check or not check["card_number"] then
		retryPIN[source] = (retryPIN[source] or 0) + 1
		if retryPIN[source] < 3 then
			triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "Access Denied ("..retryPIN[source].."/3)", 255,0,0, "failedLessThan3", retryPIN[source])
		else
			triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "Access Denied ("..retryPIN[source].."/3)", 255,0,0, "failedMoreThan3", retryPIN[source])
			retryPIN[source] = 0
			exports["item-system"]:clearItems(theATM)
			disableATMCard(cardNumber)
		end
		return false
	end

	if check["card_locked"] == "1" then
		triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "ERROR: This ATM card is not usable.", 255,0,0, "locked", cardNumber )
		retryPIN[source] = 0
		return false
	end

	triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "Access Granted!", 70,255,14, "success" )
	retryPIN[source] = 0

	local withdraw = true
	local deposit = ((getElementData(theATM, "depositable") == 1) and (true)) or (false)
	local limit = getElementData(theATM, "limit")
	local cardOwner, cardNumber, cardOwnerCharID, amountLimit = getCardInfo(foundAnATMCard)
	local balance = mysql:query_fetch_assoc("SELECT `bankmoney` from `characters` WHERE `id`= (SELECT `card_owner` FROM `atm_cards` WHERE `card_number`='".. cardNumber .."') ")
	if not balance or not balance["bankmoney"] then
		balance = 0
	else
		balance = tonumber(balance["bankmoney"])
	end

	local isPinCodeDefault = check["card_pin"] == "0000"
	triggerClientEvent(source, "bank:openATMGrantedGUI", getRootElement(), {cardOwner, cardNumber, balance, cardOwnerCharID, amountLimit}, deposit, limit, withdraw, theATM, exports.global:getElementZoneName(theATM), isPinCodeDefault)
end
addEvent( "bank:checkPINCode", true )
addEventHandler( "bank:checkPINCode", getRootElement(), checkPINCode )

function ejectATMCard(theATM, player)
	if player then source = player end
	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if not foundAnATMCard then
		exports.hud:sendBottomNotification(source,"ATM Machine is not working properly!", "This is really weird, the card you've just inserted, It's gone magically!")
		return false
	end

	if exports["item-system"]:takeItem(theATM, foundAnATMCard[1], foundAnATMCard[2]) then
		if exports["item-system"]:giveItem(source, foundAnATMCard[1], foundAnATMCard[2]) then
			triggerEvent('sendAme',  source, "slips out an ATM card from the ATM machine's slot." )
			playAtmInsert(theATM) --SoundFX
		else
			triggerEvent('sendAme',  source, "tries slip the ATM card out of the ATM machine's slot but failed." )
			exports["item-system"]:giveItem(theATM, foundAnATMCard[1], foundAnATMCard[2])
			exports.hud:sendBottomNotification(source,"ATM Machine", "Your inventory is full.")
		end
	else
		triggerEvent('sendAme',  source, "tries slip the ATM card out of the ATM machine's slot but failed." )
	end
end
addEvent( "bank:ejectATMCard", true )
addEventHandler( "bank:ejectATMCard", getRootElement(), ejectATMCard )

function changePIN(theATM, enteredCode)
	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if not foundAnATMCard then
		exports.hud:sendBottomNotification(source,"ATM Machine is not working properly!", "This is really weird, the card you've just inserted, It's gone magically!")
		return false
	end

	-- local cardOwner = foundAnATMCard[2]
	-- cardOwner = tostring(cardOwner):sub(1 , tostring(cardOwner):find( ";" ) - 1 )
	local cardOwner, cardNumber, cardOwnerCharID = getCardInfo(foundAnATMCard)

	if enteredCode == "0000" then
		triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "'0000' is default PIN code!\n\nTo make sure your account is secured, please change your PIN to something else.", 255,0,0, "changedPIN", "failed" )
		return false
	end

	if not mysql:query_free("UPDATE `atm_cards` SET `card_pin`='"..enteredCode.."' WHERE `card_number`='"..cardNumber.."' ") then
		exports.hud:sendBottomNotification(source, "SQL Error", "An SQL Error CODE06 has occured in Bank System. Please report this bug on http://bugs.owlgaming.net")
		triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "An SQL Error CODE06 has occured in Bank System. Please report this bug on http://bugs.owlgaming.net", 255,0,0, "changedPIN", "failed" )
		return false
	end

	triggerClientEvent(source, "bank:respondToATMInterfacePIN", source, "PIN Code is successfully changed!", 0,255,0, "changedPIN", "ok" )
	exports.hud:sendBottomNotification(source, "ATM Machine", "You have successfully changed your ATM card's PIN code. ("..enteredCode..")")
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

function transferATMMoneyToPersonal(theATM, amount,targetBankAccNo, reason)
	local player = client
	amount = validateATMAmount(amount)
	if not player or not amount or not validateATMInteraction(player, theATM)
		or type(targetBankAccNo) ~= "string" or #targetBankAccNo < 1 or #targetBankAccNo > 32
		or targetBankAccNo:find("[%c]") then return false end
	if reason ~= nil and (type(reason) ~= "string" or #reason > 128 or reason:find("[%c]")) then return false end
	local state = tonumber(getElementData(client, "loggedin")) or 0
	if (state == 0) then
		return false
	end

	if not reason then
		reason = ""
	end

	local foundAnATMCard = getATMCardFromATMMachine(theATM)
	if not foundAnATMCard then
		triggerClientEvent( client, "bank:respondToPendingTransfer", client, "ATM Machine is not working properly!", "This is really weird, the card you've just inserted, It's gone magically!")
		return false
	end

	local cardOwner, cardNumber, cardOwnerCharID, limitType = getCardInfo(foundAnATMCard)
	local isThisTransactionWithinLimitation, reason2 = isThisTransactionWithinLimitation(cardNumber,amount, limitType)
	if not isThisTransactionWithinLimitation then
		triggerClientEvent( client, "bank:respondToPendingTransfer", client, reason2)
		return false
	end

	local faction = getTeamFromName(targetBankAccNo:gsub("_", " "))

	if cardNumber == targetBankAccNo then
		triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You can not transfer money to yourself.")
		return false
	end

	if faction then
		local target_ownerName, target_bankmoney = nil
		local sender_ownerName, sender_id, sender_bankmoney = nil
		local target_id = getElementData(faction, "id") and -getElementData(faction, "id")

		--TAKE SENDER's ATM CARD's MONEY
		local cardOwnerElement = nil
		local senderBankOwnerQuery = mysql:query_fetch_assoc("SELECT `bankmoney`, id, charactername FROM `characters` LEFT JOIN `atm_cards` ON `characters`.`id`=`atm_cards`.`card_owner` WHERE `card_number`='"..cardNumber.."' AND `card_locked`='0' AND card_type='1' ")
		if not senderBankOwnerQuery or not senderBankOwnerQuery["bankmoney"] then
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Error code g23452 occurred, please report on forums.")
			return false
		else
			sender_ownerName = senderBankOwnerQuery["charactername"]
			sender_id = senderBankOwnerQuery["id"]
			sender_bankmoney = tonumber(senderBankOwnerQuery["bankmoney"])
			cardOwnerElement = exports.pool:getElement("playerByDbid", tonumber(sender_id))
		end

		local tookSenderMoney = false

		if cardOwnerElement then
			if getElementData(cardOwnerElement, "bankmoney") ~= sender_bankmoney then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Transaction failed. Try again.", true)
				return false
			end
			if takeBankMoney(cardOwnerElement, amount) then
				tookSenderMoney = true
				outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." from "..cardNumber.."/"..sender_ownerName.." (Online)")
			else
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "ATM Card Number '"..cardNumber.."' (Owner: '"..no_(sender_ownerName).."') doesn't have enough funds.", true)
				return false
			end
		else
			if sender_bankmoney - amount < 0 then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "ATM Card Number '"..cardNumber.."' (Owner: '"..no_(sender_ownerName).."') doesn't have enough funds.", true)
				return false
			end
			if updateBankMoney(client, sender_id, amount, "minus") then
				outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." from "..cardNumber.."/"..sender_ownerName.." (Offline)")
				tookSenderMoney = true
			end
		end



		if tookSenderMoney then
			giveBankMoney(faction, amount)
			outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." to "..getTeamName(faction).." (Online)")
		else
			outputDebugString("SQL error code GvddGh4")
			outputChatBox("SQL error code GvddGh4", client)
			triggerEvent("bank:ejectATMCard", client, theATM)
			return false
		end

		addTransactionLimit(cardNumber, amount, limitType)

		local teamName = getTeamName(faction):gsub("_", " ")
		triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You've successfully transferred $" .. exports.global:formatMoney(amount) .. " to '"..teamName.."'.", true)

		local atmName = getATMName(theATM)
		addBankTransactionLog(sender_id, target_id, amount, 2,  reason,"Transferred from "..atmName, cardNumber, targetBankAccNo)
		exports.logs:dbLog(client, 25, client, "TRANSFERRED $" .. amount.." FROM ("..no_(cardOwner)..", "..cardNumber..") TO ("..teamName..") REASON ("..reason..", "..atmName..")")

		triggerEvent("bank:ejectATMCard", client, theATM)

		return true
	else

		local target_ownerName, target_id, target_bankmoney = nil
		local sender_ownerName, sender_id, sender_bankmoney = nil

		--TAKE SENDER's ATM CARD's MONEY
		local cardOwnerElement = nil
		local senderBankOwnerQuery = mysql:query_fetch_assoc("SELECT `bankmoney`, id, charactername FROM `characters` LEFT JOIN `atm_cards` ON `characters`.`id`=`atm_cards`.`card_owner` WHERE `card_number`='"..cardNumber.."' AND `card_locked`='0' AND card_type='1' ")
		if not senderBankOwnerQuery or not senderBankOwnerQuery["bankmoney"] then
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Error code g2345 occurred, please report on forums.")
			return false
		else
			sender_ownerName = senderBankOwnerQuery["charactername"]
			sender_id = senderBankOwnerQuery["id"]
			sender_bankmoney = tonumber(senderBankOwnerQuery["bankmoney"])
			cardOwnerElement = exports.pool:getElement("playerByDbid", tonumber(sender_id))
		end

		if cardOwnerElement then
			if getElementData(cardOwnerElement, "bankmoney") ~= sender_bankmoney then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Transaction failed. Try again.", true)
				return false
			end
			if not hasBankMoney(cardOwnerElement, amount) then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "ATM Card Number '"..cardNumber.."' (Owner: '"..no_(sender_ownerName).."') doesn't have enough funds.", true)
				return false
			end
		else
			if sender_bankmoney - amount < 0 then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "ATM Card Number '"..cardNumber.."' (Owner: '"..no_(sender_ownerName).."') doesn't have enough funds.", true)
				return false
			end
		end



		local targetElement = nil
		local targetBankOwnerQuery = mysql:query_fetch_assoc("SELECT id, `charactername`, bankmoney FROM `characters` LEFT JOIN `atm_cards` ON `characters`.`id`=`atm_cards`.`card_owner` WHERE `atm_cards`.`card_number`='"..toSQL(targetBankAccNo).."' AND `card_locked`='0' AND card_type='1' ")
		if not targetBankOwnerQuery or not targetBankOwnerQuery["charactername"] then
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Target Bank Account Number does not exist or is disabled! Please check again and retry.")
			return false
		else
			target_ownerName = targetBankOwnerQuery["charactername"]
			target_id = targetBankOwnerQuery["id"]
			target_bankmoney = tonumber(targetBankOwnerQuery["bankmoney"])
			targetElement = exports.pool:getElement("playerByDbid", tonumber(target_id))
		end

		if targetElement then
			if getElementData(targetElement, "bankmoney") ~= target_bankmoney then
				triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Transaction failed. Try again.", true)
				return false
			end
		end

		local checkingResult = areYouAltAlting(client, { cardOwner, cardNumber, cardOwnerCharID}, target_id )
		if checkingResult == "between alts" then
			exports.global:sendMessageToAdmins("[BANK] ("..getElementData(client, "playerid")..") "..tostring(getPlayerName(client)):gsub("_"," ").." - "..getElementData(client, "account:username").." attempted to transfer $"..exports.global:formatMoney(amount).." to another ATM card owned by his alt.")
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You can not transfer money between your own characters. Using other ATM card to gain this purpose may get yourself a permanent ban.", true)
			disableATMCard(cardNumber)
			exports["item-system"]:clearItems(theATM)
			return false
		end

		if checkingResult == "between chars over the same ip" then
			exports.global:sendMessageToAdmins("[BANK] ("..getElementData(client, "playerid")..") "..tostring(getPlayerName(client)):gsub("_"," ").." - "..getElementData(client, "account:username").." attempted to transfer $"..exports.global:formatMoney(amount).." to another ATM card owned by a character in his other account on the same IP address.")
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You can not transfer money between your own characters. Using other ATM card to gain this purpose may get yourself a permanent ban.", true)
			disableATMCard(cardNumber)
			exports["item-system"]:clearItems(theATM)
			return false
		end

		if checkingResult == "between chars over the same mtaserial" then
			exports.global:sendMessageToAdmins("[BANK] ("..getElementData(client, "playerid")..") "..tostring(getPlayerName(client)):gsub("_"," ").." - "..getElementData(client, "account:username").." attempted  transfer $"..exports.global:formatMoney(amount).." to another ATM card owned by a character in his other account on the same MTA Serial.")
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You can not transfer money between your own characters. Using other ATM card to gain this purpose may get yourself a permanent ban.", true)
			disableATMCard(cardNumber)
			exports["item-system"]:clearItems(theATM)
			return false
		end

		local takeSenderMoney = false
		if cardOwnerElement then
		 	if takeBankMoney(cardOwnerElement, amount) then
		 		outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." from "..cardNumber.."/"..cardOwner.." (Online)")
		 		takeSenderMoney = true
		 	else
		 		if updateBankMoney(client, sender_id, amount, "minus") then
		 			outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." from "..cardNumber.."/"..cardOwner.." (Offline)")
		 			takeSenderMoney = true
		 		end
		 	end
		end

		if takeSenderMoney then
			if targetElement then
				if giveBankMoney(targetElement, amount) then
					outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." to "..targetBankAccNo.."/"..target_ownerName.." (Online)")
				end
			else
				if updateBankMoney(client, target_id, amount, "plus") then
					outputDebugString("[BANK] "..getPlayerName(client).." is transferring $"..amount.." to "..targetBankAccNo.."/"..target_ownerName.." (Offline)")
				end
			end
		else
			triggerClientEvent( client, "bank:respondToPendingTransfer", client, "Transaction failed. Try again.", true)
			return false
		end

		addTransactionLimit(cardNumber, amount, limitType)

		triggerClientEvent( client, "bank:respondToPendingTransfer", client, "You've successfully transferred $" .. exports.global:formatMoney(amount) .. " to ATM Card '"..targetBankAccNo.."' (Owner: '"..no_(target_ownerName).."') ", true)
		triggerEvent("bank:ejectATMCard", client, theATM)

		local atmName = getATMName(theATM)
		addBankTransactionLog(sender_id, target_id, amount, 2,  reason,"Transferred from "..atmName, cardNumber, targetBankAccNo)
		exports.logs:dbLog(client, 25, client, "TRANSFERRED $" .. amount.." FROM ("..no_(cardOwner)..", "..cardNumber..") TO ("..no_(target_ownerName)..", "..targetBankAccNo..", $".. (target_bankmoney + amount) ..") REASON ("..reason..", "..atmName..")")
		return true
	end
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
