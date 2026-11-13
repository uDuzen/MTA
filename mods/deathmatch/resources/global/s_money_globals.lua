--[[
 * ***********************************************************************************************************************
 * Copyright (c) 2015 OwlGaming Community - All Rights Reserved
 * All rights reserved. This program and the accompanying materials are private property belongs to OwlGaming Community
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * ***********************************************************************************************************************
 ]]

mysql = exports.mysql

--TAX
tax = 15 -- percent
function getTaxAmount()
	return tax / 100
end
function setTaxAmount(new)
	tax = math.max( 0, math.min( 30, math.ceil( new ) ) )
	mysql:query_free("UPDATE settings SET value = " .. tax .. " WHERE name = 'tax'" )
end

--INCOME TAX
incometax = 10 -- percent
function getIncomeTaxAmount()
	return incometax / 100
end
function setIncomeTaxAmount(new)
	incometax = math.max( 0, math.min( 25, math.ceil( new ) ) )
	mysql:query_free("UPDATE settings SET value = " .. incometax .. " WHERE name = 'incometax'" )
end

-- load income and normal tax on startup
addEventHandler( "onResourceStart", getResourceRootElement( ),
	function( )
		local result = mysql:query("SELECT value FROM settings WHERE name = 'tax'" )
		if result then
			if mysql:num_rows( result ) == 0 then
				mysql:query_free("INSERT INTO settings (name, value) VALUES ('tax', " .. tax .. ")" )
			else
				local row = mysql:fetch_assoc(result)
				tax = tonumber( row["value"] ) or 15
			end
			mysql:free_result( result )
		end
		
		local result = mysql:query( "SELECT value FROM settings WHERE name = 'incometax'" )
		if result then
			if mysql:num_rows( result ) == 0 then
				mysql:query_free("INSERT INTO settings (name, value) VALUES ('incometax', " .. incometax .. ")" )
			else
				local row = mysql:fetch_assoc(result)
				incometax = tonumber( row["value"] ) or 10
			end
			mysql:free_result( result )
		end
	end
)

-- ////////////////////////////////////
local function restoreMoneyItems(player, values)
	local restored = true
	for _, value in ipairs(values or {}) do
		if not exports.global:giveItem(player, 134, value) then
			restored = false
			outputDebugString("[global] Failed to restore cash inventory item for " .. getPlayerName(player), 1)
		end
	end
	return restored
end

local function removeMoneyItems(player)
	local inventory = exports["item-system"]:getItems(player)
	if type(inventory) ~= "table" then return false, {} end
	local values = {}
	for _, item in ipairs(inventory) do
		if tonumber(item[1]) == 134 then table.insert(values, item[2]) end
	end
	local removed = {}
	for _, value in ipairs(values) do
		if not exports["item-system"]:takeItem(player, 134, value) then
			restoreMoneyItems(player, removed)
			return false, {}
		end
		table.insert(removed, value)
	end
	return true, removed
end

local function setMoneyElementData(element, balance)
	if exports.anticheat:changeProtectedElementDataEx(element, "money", balance, true) then
		return true
	end
	return setElementData(element, "money", balance, true)
end

function giveMoney(thePlayer, amount, fromBank)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0 then return false end
	amount = math.floor(amount)
	if amount == 0 then return true end
	if not isElement(thePlayer) then return false end

	local elementType = getElementType(thePlayer)
	local currentMoney = tonumber(getMoney(thePlayer, true)) or 0
	local newBalance = currentMoney + amount
	if newBalance > 2000000000 then return false end

	if elementType == "player" then
		local characterID = tonumber(getElementData(thePlayer, "dbid"))
		if not characterID or characterID < 1 then return false end
		local removed, oldItems = removeMoneyItems(thePlayer)
		if not removed then return false end
		if not mysql:query_free("UPDATE characters SET money = money + " .. amount .. " WHERE id = " .. characterID) then
			restoreMoneyItems(thePlayer, oldItems)
			return false
		end
		if not setMoneyElementData(thePlayer, newBalance) then
			mysql:query_free("UPDATE characters SET money = money - " .. amount .. " WHERE id = " .. characterID)
			restoreMoneyItems(thePlayer, oldItems)
			return false
		end
		if newBalance > 0 and not exports.global:giveItem(thePlayer, 134, newBalance) then
			outputDebugString("[global] Balance credited but cash inventory item could not be recreated for " .. getPlayerName(thePlayer), 1)
		end
		triggerClientEvent(thePlayer, "moneyUpdateFX", thePlayer, true, amount, fromBank)
		return true
	elseif elementType == "team" then
		local factionID = tonumber(getElementData(thePlayer, "id"))
		if not factionID or factionID < 1 then return false end
		if not mysql:query_free("UPDATE factions SET bankbalance = bankbalance + " .. amount .. " WHERE id = " .. factionID) then return false end
		if not setMoneyElementData(thePlayer, newBalance) then
			mysql:query_free("UPDATE factions SET bankbalance = bankbalance - " .. amount .. " WHERE id = " .. factionID)
			return false
		end
		return true
	end
	return false
end

function takeMoney(thePlayer, amount, rest, toBank)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge or amount < 0 then return false, 0 end
	amount = math.ceil(amount)
	if amount == 0 then return true, 0 end
	if not isElement(thePlayer) then return false, 0 end

	local elementType = getElementType(thePlayer)
	local currentMoney = tonumber(getMoney(thePlayer, true)) or 0
	if rest and amount > currentMoney then amount = math.max(0, currentMoney) end
	if amount == 0 then return true, 0 end
	if currentMoney < amount then return false, 0 end
	local newBalance = currentMoney - amount

	if elementType == "player" then
		local characterID = tonumber(getElementData(thePlayer, "dbid"))
		if not characterID or characterID < 1 then return false, 0 end
		local removed, oldItems = removeMoneyItems(thePlayer)
		if not removed then return false, 0 end
		if not mysql:query_free("UPDATE characters SET money = money - " .. amount .. " WHERE id = " .. characterID .. " AND money >= " .. amount) then
			restoreMoneyItems(thePlayer, oldItems)
			return false, 0
		end
		if not setMoneyElementData(thePlayer, newBalance) then
			mysql:query_free("UPDATE characters SET money = money + " .. amount .. " WHERE id = " .. characterID)
			restoreMoneyItems(thePlayer, oldItems)
			return false, 0
		end
		if newBalance > 0 and not exports.global:giveItem(thePlayer, 134, newBalance) then
			outputDebugString("[global] Balance debited but cash inventory item could not be recreated for " .. getPlayerName(thePlayer), 1)
		end
		triggerClientEvent(thePlayer, "moneyUpdateFX", thePlayer, false, amount, toBank)
		return true, amount
	elseif elementType == "team" then
		local factionID = tonumber(getElementData(thePlayer, "id"))
		if not factionID or factionID < 1 then return false, 0 end
		if not mysql:query_free("UPDATE factions SET bankbalance = bankbalance - " .. amount .. " WHERE id = " .. factionID) then return false, 0 end
		if not setMoneyElementData(thePlayer, newBalance) then
			mysql:query_free("UPDATE factions SET bankbalance = bankbalance + " .. amount .. " WHERE id = " .. factionID)
			return false, 0
		end
		return true, amount
	end
	return false, 0
end

function setMoney(thePlayer, amount, onSpawn)
	amount = tonumber(amount)
	if not amount or amount ~= amount or amount == math.huge or amount == -math.huge
		or (amount < 0 and not onSpawn) or amount > 2000000000 then return false end
	amount = math.floor(amount)
	if not isElement(thePlayer) then return false end

	local elementType = getElementType(thePlayer)
	local currentMoney = tonumber(getMoney(thePlayer, true)) or 0
	if elementType == "player" then
		local characterID = tonumber(getElementData(thePlayer, "dbid"))
		if not onSpawn and (not characterID or characterID < 1) then return false end
		local removed, oldItems = removeMoneyItems(thePlayer)
		if not removed then return false end
		if not onSpawn and not mysql:query_free("UPDATE characters SET money = " .. amount .. " WHERE id = " .. characterID) then
			restoreMoneyItems(thePlayer, oldItems)
			return false
		end
		if not setMoneyElementData(thePlayer, amount) then
			if not onSpawn then mysql:query_free("UPDATE characters SET money = " .. currentMoney .. " WHERE id = " .. characterID) end
			restoreMoneyItems(thePlayer, oldItems)
			return false
		end
		if amount > 0 and not exports.global:giveItem(thePlayer, 134, amount) then
			outputDebugString("[global] Balance set but cash inventory item could not be recreated for " .. getPlayerName(thePlayer), 1)
		end
		if not onSpawn then
			if amount > currentMoney then
				triggerClientEvent(thePlayer, "moneyUpdateFX", thePlayer, true, amount - currentMoney)
			elseif amount < currentMoney then
				triggerClientEvent(thePlayer, "moneyUpdateFX", thePlayer, false, currentMoney - amount)
			end
		end
		return true
	elseif elementType == "team" then
		local factionID = tonumber(getElementData(thePlayer, "id"))
		if not factionID or factionID < 1 then return false end
		if not mysql:query_free("UPDATE factions SET bankbalance = " .. amount .. " WHERE id = " .. factionID) then return false end
		if not setMoneyElementData(thePlayer, amount) then
			mysql:query_free("UPDATE factions SET bankbalance = " .. currentMoney .. " WHERE id = " .. factionID)
			return false
		end
		return true
	end
	return false
end
function hasMoney(thePlayer, amount)
	amount = tonumber(amount) or 0
	if isElement(thePlayer) and amount >= 0 then
		amount = math.floor(amount)
		return (tonumber(getMoney(thePlayer, true)) or 0) >= amount
	end
	return false
end

function getMoney(thePlayer, nocheck)
	if not isElement(thePlayer) then return 0 end
	if not nocheck then
		--checkMoneyHacks(thePlayer) -- Disabled because we don't use MTA's setPlayerMoney/getPlayerMoney at all. /MAXIME
	end
	return tonumber(getElementData(thePlayer, "money")) or 0
end

function checkMoneyHacks(thePlayer)
	if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then return end
	
	local safemoney = getMoney(thePlayer, true)
	local hackmoney = getPlayerMoney(thePlayer)
	if (safemoney < hackmoney) then
		setPlayerMoney(thePlayer, safemoney)
		sendMessageToAdmins("Possible money hack detected: "..getPlayerName(thePlayer))
		return true
	else
		return false
	end
end

-- ////////////////////////////////////

function formatMoney(amount)
	local left,num,right = string.match(tostring(amount),'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end
