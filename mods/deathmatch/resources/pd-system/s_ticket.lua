local pedname = "Sergeant E. Stone"
local JFOX_MDC = 532
addCommandHandler("ticket", function(thePlayer, command, vin)
	if getElementData(thePlayer, "loggedin") == 1 then
		local inFaction = exports.factions:isPlayerInFaction(thePlayer, 1) or exports.factions:isPlayerInFaction(thePlayer, 2) or exports.factions:isPlayerInFaction(thePlayer, 50)
		if inFaction then -- LEO faction
			local found = false
			if vin then
				found = exports.pool:getElement("vehicle", vin)
			end
			triggerClientEvent(thePlayer, "showTicketGUI", thePlayer, found)
		end
	end
end)

addEvent("fetchTickets", true)
addEventHandler("fetchTickets", getRootElement(), function()
	if not client or tonumber(getElementData(client, "loggedin")) ~= 1 then return false end
	local player = client
	local characterID = tonumber(getElementData(player, "dbid"))
	if not characterID then return false end
	local tickets = {}
	local query = dbQuery(exports.mysql:getConn('mta'), "SELECT * FROM `mdc_crimes` WHERE `character` = ? ORDER BY `id` DESC", characterID)
	local result = dbPoll(query, -1)
	if result then
		for rid, row in pairs (result) do
			if string.find(row['crime'], "Ticket") and string.find(row['punishment'], "(UNPAID)") then
				table.insert(tickets, {
					row['id'],
					row['crime']:gsub("Ticket: ", ""),
					row['punishment']:gsub("Fine: ", ""),
					row['timestamp']
				})
			end
		end
		if #tickets > 0 then
			local quotes = {
				"I'm not very computer savvy, please be patient.",
				"My name is Emma, how may I help you " .. (getElementData(source, "gender") == 1 and "ma'am" or "sir") .. "?",
				"You have " .. #tickets .. " unpaid ticket" .. (#tickets > 1 and "s" or "") .. ", would you like to pay " .. (#tickets == 1 and "it" or "them") .. "?"
			}
			outputChatBox(" [English] " .. pedname .. " says: " .. quotes[math.random(1, 3)], source, 255, 255, 255)
			triggerClientEvent(source, "showPayGUI", source, tickets)
		else
			outputChatBox(" [English] " .. pedname .. " says: Sorry. You have no unpaid tickets on record.", source, 255, 255, 255)
		end
	end
end)

local function isTicketOfficer(player)
	return isElement(player) and getElementType(player) == "player"
		and tonumber(getElementData(player, "loggedin")) == 1
		and (exports.factions:isPlayerInFaction(player, 1)
			or exports.factions:isPlayerInFaction(player, 2)
			or exports.factions:isPlayerInFaction(player, 50))
end

local function validateFine(value)
	local fine = tonumber(value)
	if not fine or fine ~= fine or fine == math.huge or fine < 50 or fine > 10000 or fine ~= math.floor(fine) then
		return false
	end
	return fine
end

addEvent("givePlayerTicket", true)
addEventHandler("givePlayerTicket", getRootElement(), function(player, fine, offences, date)
	local officerPlayer = client
	fine = validateFine(fine)
	if not isTicketOfficer(officerPlayer) or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or player == officerPlayer or not fine
		or type(offences) ~= "string" or #offences > 100 then
		return false
	end

	local charid = tonumber(getElementData(officerPlayer, "dbid")) or 0
	local targetCharacterID = tonumber(getElementData(player, "dbid"))
	if not targetCharacterID then return false end
	local officer = JFOX_MDC
	if (getElementData(officerPlayer, "mdc_account") or exports.mdc:login(charid, true))
		and exports.mdc:canAccess(officerPlayer, "canSeeWarrants") then
		officer = charid
	end

	local ticketDate = type(date) == "string" and date:sub(1, 64) or tostring(getRealTime().timestamp)
	if not exports["item-system"]:giveItem(player, 267, ticketDate) then return false end
	local timestamp = getRealTime().timestamp
	local inserted = dbExec(exports.mysql:getConn('mta'),
		"INSERT INTO `mdc_crimes` ( `crime`, `punishment`, `character`, `officer`, `timestamp` ) VALUES ( ?, ?, ?, ?, ? )",
		"Ticket: " .. offences, "Fine: $" .. fine .. " (UNPAID)", targetCharacterID, officer, timestamp)
	if not inserted then
		exports["item-system"]:takeItem(player, 267, ticketDate)
		return false
	end

	triggerEvent("sendAme", officerPlayer, "rips off a ticket from their ticket book and issues it to " .. getPlayerName(player):gsub("_", " ") .. ".")
	outputChatBox("You have issued a $" .. exports.global:formatMoney(fine) .. " ticket to " .. getPlayerName(player):gsub("_", " ") .. ".", officerPlayer, 0, 255, 0)
	return true
end)

addEvent("giveVehicleTicket", true)
addEventHandler("giveVehicleTicket", getRootElement(), function(vehicle, info, fine, offences, date)
	local officerPlayer = client
	fine = validateFine(fine)
	if not isTicketOfficer(officerPlayer) or not isElement(vehicle) or getElementType(vehicle) ~= "vehicle"
		or not fine or type(offences) ~= "string" or #offences > 100 then
		return false
	end
	local owner = tonumber(getElementData(vehicle, "owner"))
	local faction = tonumber(getElementData(vehicle, "faction")) or 0
	local job = tonumber(getElementData(vehicle, "job")) or 0
	if not owner or faction > 0 or job > 0 then return false end
	local px, py, pz = getElementPosition(officerPlayer)
	local vx, vy, vz = getElementPosition(vehicle)
	if getElementDimension(officerPlayer) ~= getElementDimension(vehicle)
		or getElementInterior(officerPlayer) ~= getElementInterior(vehicle)
		or getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) > 10 then
		return false
	end

	local charid = tonumber(getElementData(officerPlayer, "dbid")) or 0
	local officer = JFOX_MDC
	if (getElementData(officerPlayer, "mdc_account") or exports.mdc:login(charid, true))
		and exports.mdc:canAccess(officerPlayer, "canSeeWarrants") then
		officer = charid
	end
	local ticketDate = type(date) == "string" and date:sub(1, 64) or tostring(getRealTime().timestamp)
	if not exports["item-system"]:giveItem(vehicle, 267, ticketDate) then return false end
	local timestamp = getRealTime().timestamp
	local inserted = dbExec(exports.mysql:getConn('mta'),
		"INSERT INTO `mdc_crimes` ( `crime`, `punishment`, `character`, `officer`, `timestamp` ) VALUES ( ?, ?, ?, ?, ? )",
		"Ticket: " .. offences, "Fine: $" .. fine .. " (UNPAID)", owner, officer, timestamp)
	if not inserted then
		exports["item-system"]:takeItem(vehicle, 267, ticketDate)
		return false
	end

	local plate = type(info) == "string" and info:sub(1, 16) or tostring(getElementData(vehicle, "plate") or "")
	triggerEvent("sendAme", officerPlayer, "rips off a ticket from their ticket book and sticks it to the windshield of the " .. tostring(getElementData(vehicle, "year")) .. " " .. tostring(getElementData(vehicle, "brand")) .. " " .. tostring(getElementData(vehicle, "maximemodel")) .. ".")
	outputChatBox("You have issued a $" .. exports.global:formatMoney(fine) .. " ticket to the vehicle with plate " .. plate .. ".", officerPlayer, 0, 255, 0)
	return true
end)

local processingTickets = {}
addEvent("chargePlayer", true)
addEventHandler("chargePlayer", getRootElement(), function(amount, method, crimeID, date)
	local player = client
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	crimeID = tonumber(crimeID)
	method = tonumber(method)
	local characterID = tonumber(getElementData(player, "dbid"))
	if not crimeID or crimeID < 1 or crimeID ~= math.floor(crimeID)
		or (method ~= 1 and method ~= 2) or not characterID then return false end
	local lockKey = tostring(characterID) .. ":" .. tostring(crimeID)
	if processingTickets[lockKey] then return false end
	processingTickets[lockKey] = true

	local query = dbQuery(exports.mysql:getConn('mta'),
		"SELECT `punishment`, `timestamp` FROM `mdc_crimes` WHERE `id` = ? AND `character` = ? LIMIT 1",
		crimeID, characterID)
	local rows = dbPoll(query, 10000)
	local row = rows and rows[1]
	local punishment = row and row.punishment
	local fine = type(punishment) == "string" and tonumber(punishment:match("Fine:%s*%$(%d+)%s*%(UNPAID%)"))
	if not fine or fine < 50 or fine > 10000 then
		processingTickets[lockKey] = nil
		return false
	end

	local paidText = "Fine: $" .. fine
	local updated = dbExec(exports.mysql:getConn('mta'),
		"UPDATE `mdc_crimes` SET `punishment` = ? WHERE `id` = ? AND `character` = ? AND `punishment` = ?",
		paidText, crimeID, characterID, punishment)
	if not updated then
		processingTickets[lockKey] = nil
		return false
	end

	local paid = method == 1 and exports.global:takeMoney(player, fine) or (method == 2 and exports.bank:takeBankMoney(player, fine))
	if not paid then
		dbExec(exports.mysql:getConn('mta'),
			"UPDATE `mdc_crimes` SET `punishment` = ? WHERE `id` = ? AND `character` = ? AND `punishment` = ?",
			punishment, crimeID, characterID, paidText)
		processingTickets[lockKey] = nil
		return false
	end

	if method == 2 then
		outputChatBox("$" .. exports.global:formatMoney(fine) .. " has been taken from your bank account.", player, 0, 255, 0)
	end
	local tax = exports.global:getTaxAmount()
	exports.global:giveMoney(exports.factions:getFactionFromID(1), math.ceil((1-tax)*fine))
	exports.global:giveMoney(exports.factions:getFactionFromID(3), math.ceil(tax*fine))

	if type(date) == "string" and #date <= 64 then
		for i, item in ipairs(exports["item-system"]:getItems(player) or {}) do
			if item[1] == 217 and tostring(item[2]) == date then
				exports["item-system"]:takeItemFromSlot(player, i)
				break
			end
		end
	end
	processingTickets[lockKey] = nil
	return true
end)

addEventHandler("onVehicleEnter", getRootElement(), function(thePlayer)
	if exports['item-system']:hasItem(source, 267) then
		outputChatBox("★ A white citation is visible on the windshield of the vehicle.", thePlayer, 255, 51, 102)
	end
end)
