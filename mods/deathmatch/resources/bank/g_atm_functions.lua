--MAXIME 
--ATM Card system

function getATMCardFromATMMachine(theATM)
	local items = exports["item-system"]:getItems(theATM) 
	local foundAnATMCard = false
	
	if not items then
		return false
	end
	
	for key, item in pairs(items) do
		if tonumber(item[1]) == 150 then
			foundAnATMCard = item
			break
		end
	end
	
	if not foundAnATMCard then
		return false
	else
		return foundAnATMCard
	end
end

function getCardInfo(theCard) -- 1. card owner name, 2. card number, 3. card owner id, 4. limit type
	if not theCard or not theCard[2] then
		return "?", "?", false
	end
	
	theCard = explode(";", theCard[2])
	return exports.cache:getCharacterNameFromID(theCard[2]) , theCard[1] or "?", theCard[2] or false, theCard[3] or 1
end

function isAnyOneElseAround(theAtm) 
	local ax, ay, az = getElementPosition( theAtm )
	for _, player in pairs(getElementsByType("player")) do
		if player ~= localPlayer then
			local px, py, pz = getElementPosition( player ) 
			if getDistanceBetweenPoints3D( px, py, pz, ax, ay, az ) < 1.3 then 
				return true
			end
		end
	end
	return false
end

function updateBankMoney(thePlayer, charID, money, transfer)
	charID, money = tonumber(charID), tonumber(money)
	if not charID or charID ~= charID or charID == math.huge or charID == -math.huge
		or charID == 0 or charID ~= math.floor(charID)
		or not money or money ~= money or money == math.huge or money == -math.huge
		or money < 0 or money > 1000000000 or money ~= math.floor(money) then
		return false
	end

	if charID < 0 then
		local factionID = -charID
		local foundFaction
		for _, faction in ipairs(getElementsByType("team")) do
			if tonumber(getElementData(faction, "id")) == factionID then
				foundFaction = faction
				break
			end
		end
		if not isElement(foundFaction) then
			outputDebugString("[BANK] updateBankMoney could not find faction #" .. factionID, 1)
			return false
		end
		if transfer == nil then
			return exports.global:setMoney(foundFaction, money) == true
		elseif transfer == "minus" then
			return exports.global:takeMoney(foundFaction, money) == true
		elseif transfer == "plus" then
			return exports.global:giveMoney(foundFaction, money) == true
		end
		return false
	end

	if transfer ~= nil and transfer ~= "minus" and transfer ~= "plus" then return false end
	local row = mysql:query_fetch_assoc("SELECT bankmoney FROM characters WHERE id = " .. charID .. " LIMIT 1")
	local oldBalance = row and tonumber(row.bankmoney)
	if not oldBalance or oldBalance < 0 or oldBalance ~= oldBalance
		or oldBalance == math.huge or oldBalance == -math.huge then
		return false
	end

	local newBalance
	if transfer == "minus" then
		if oldBalance < money then return false end
		newBalance = oldBalance - money
	elseif transfer == "plus" then
		newBalance = oldBalance + money
	else
		newBalance = money
	end
	if newBalance < 0 or newBalance > 2000000000 then return false end

	local updated
	if transfer == "minus" then
		updated = mysql:query_free("UPDATE characters SET bankmoney = bankmoney - " .. money
			.. " WHERE id = " .. charID .. " AND bankmoney = " .. oldBalance)
	elseif transfer == "plus" then
		updated = mysql:query_free("UPDATE characters SET bankmoney = bankmoney + " .. money
			.. " WHERE id = " .. charID .. " AND bankmoney = " .. oldBalance)
	else
		updated = mysql:query_free("UPDATE characters SET bankmoney = " .. newBalance
			.. " WHERE id = " .. charID .. " AND bankmoney = " .. oldBalance)
	end
	if not updated then
		outputDebugString("[BANK] Failed to update bankmoney in SQL for character #" .. charID, 1)
		return false
	end

	local savedRow = mysql:query_fetch_assoc("SELECT bankmoney FROM characters WHERE id = " .. charID .. " LIMIT 1")
	if not savedRow or tonumber(savedRow.bankmoney) ~= newBalance then
		local rolledBack = mysql:query_free("UPDATE characters SET bankmoney = " .. oldBalance
			.. " WHERE id = " .. charID .. " AND bankmoney = " .. newBalance)
		if not rolledBack then
			outputDebugString("[BANK] Failed to roll back unverified bankmoney update for character #" .. charID, 1)
		end
		return false
	end

	local onlinePlayers = {}
	for _, player in ipairs(getElementsByType("player")) do
		if tonumber(getElementData(player, "dbid")) == charID then
			onlinePlayers[#onlinePlayers + 1] = {
				player = player,
				old = tonumber(getElementData(player, "bankmoney")) or oldBalance
			}
		end
	end
	local changed = {}
	for _, entry in ipairs(onlinePlayers) do
		if not setElementDataEx(entry.player, "bankmoney", newBalance, true) then
			local rollbackOK = mysql:query_free("UPDATE characters SET bankmoney = " .. oldBalance
				.. " WHERE id = " .. charID .. " AND bankmoney = " .. newBalance)
			for _, changedEntry in ipairs(changed) do
				if isElement(changedEntry.player) then
					setElementDataEx(changedEntry.player, "bankmoney", changedEntry.old, true)
				end
			end
			if not rollbackOK then
				outputDebugString("[BANK] Failed to roll back bankmoney database value after element-data update failed for #" .. charID, 1)
			end
			return false
		end
		table.insert(changed, entry)
	end
	return true
end

function toSQL(text)
	return tostring(text):gsub("'","''")
end

function no_(text)
	return tostring(text):gsub("_", " ")
end

--ANTI-ALT->ALT
local function getCharacterAccountAndSerial(characterID)
	local id = tonumber(characterID)
	if not id or id < 1 or id ~= math.floor(id) then return false end
	return mysql:query_fetch_assoc("SELECT c.account, a.mtaserial FROM characters c "
		.. "LEFT JOIN account_details a ON a.account_id = c.account WHERE c.id = " .. id .. " LIMIT 1")
end

function areYouAltAlting(thePlayer, cardInfo, targetID)
	if not isElement(thePlayer) or getElementType(thePlayer) ~= "player"
		or tonumber(getElementData(thePlayer, "loggedin")) ~= 1
		or type(cardInfo) ~= "table" then
		return false
	end
	local cardOwnerID = tonumber(cardInfo[3])
	local accountID = tonumber(getElementData(thePlayer, "account:id"))
	local playerCharacterID = tonumber(getElementData(thePlayer, "dbid"))
	if not cardOwnerID or cardOwnerID < 1 or not accountID or accountID < 1
		or not playerCharacterID or playerCharacterID < 1 then
		return false
	end

	local comparisonID = targetID and tonumber(targetID) or cardOwnerID
	if not comparisonID or comparisonID < 1 or comparisonID ~= math.floor(comparisonID) then
		return false
	end
	if comparisonID == playerCharacterID then return false end

	local comparison = getCharacterAccountAndSerial(comparisonID)
	if not comparison then return nil end
	if tonumber(comparison.account) == accountID then
		return "between alts"
	end

	local playerSerial = tostring(getPlayerSerial(thePlayer) or "")
	local comparisonSerial = tostring(comparison.mtaserial or "")
	if playerSerial ~= "" and comparisonSerial ~= "" and playerSerial == comparisonSerial then
		return "between chars over the same mtaserial"
	end
	return false
end

function disableATMCard(carNo)
	mysql:query_free("UPDATE `atm_cards` SET `card_locked`='1' WHERE `card_number`='"..carNo.."' ")
end

function copyATMCardNumber(text)
	if setClipboard(text) then
		exports.hud:sendBottomNotification(getLocalPlayer(), "ATM Machine", "Copied '"..text.."' to clipboard.")
	end
end
addEvent("bank:copyATMCardNumber", true)
addEventHandler("bank:copyATMCardNumber", getRootElement(), copyATMCardNumber)

------------------------END ATM CARD SYSTEM----------------------------
function saveBank(thePlayer)
	if not isElement(thePlayer) or getElementType(thePlayer) ~= "player"
		or tonumber(getElementData(thePlayer, "loggedin")) ~= 1 then
		return false
	end
	local characterID = tonumber(getElementData(thePlayer, "dbid"))
	local bankBalance = tonumber(getElementData(thePlayer, "bankmoney"))
	if not characterID or characterID < 1 or not bankBalance
		or bankBalance ~= bankBalance or bankBalance == math.huge
		or bankBalance < 0 or bankBalance ~= math.floor(bankBalance) then
		return false
	end
	local exists = mysql:query_fetch_assoc("SELECT id FROM characters WHERE id = " .. characterID .. " LIMIT 1")
	if not exists then return false end
	return mysql:query_free("UPDATE characters SET bankmoney = " .. bankBalance .. " WHERE id = " .. characterID)
end

function explode(div,str) -- credit: http://richard.warburton.it
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
	table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
	pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

local withdraws = {} 
local limitedAmount = 10000 --dollars
local limitedInterval = 1000*60*60*5 --hours
local limits = {
		[1] = 10000,
		[2] = 50000,
		[3] = 0,
	}

function isThisTransactionWithinLimitation(cardNumber,amount, limitType)
	if not cardNumber or not amount or not tonumber(amount) or not limitType or not tonumber(limitType) then
		return false, "Internal Error"
	end

	amount = tonumber(amount)
	limitType = tonumber(limitType)

	if limits[limitType] == 0 then
		return true
	end

	if not withdraws[cardNumber] then
		withdraws[cardNumber] = {}
	end

	local total = 0
	local now = getTickCount()
	local start = now - limitedInterval
	for timestamp, amount in pairs (withdraws[cardNumber]) do
		if timestamp > start then
			total = total + amount
		end
	end

	total = total + amount

	if total > limits[limitType] then
		return false, "You can only withdraw/transfer $"..exports.global:formatMoney(limits[limitType]).." from this ATM card a day ((Every "..math.floor(limitedInterval/60/60/1000).." hours))\n You have already made in total of $"..exports.global:formatMoney(total-amount).." worth of transactions recently."
	end

	return true
end

function addTransactionLimit(cardNumber, amount, limitType)
	if not cardNumber or not amount or not tonumber(amount) or not limitType or not tonumber(limitType) then
		return false, "Internal Error"
	end

	amount = tonumber(amount)
	limitType = tonumber(limitType)

	if limits[limitType] == 0 then
		return true
	end

	if not withdraws[cardNumber] then
		withdraws[cardNumber] = {}
	end

	local now = getTickCount()
	withdraws[cardNumber][now] = amount

	return true
end