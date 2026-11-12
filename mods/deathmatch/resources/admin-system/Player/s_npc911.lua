local outboundPhoneNumber = "Hidden No."
local npc911Cooldown = {}

function promptGUI(thePlayer)
	if exports.integration:isPlayerSupporter(thePlayer) or exports.integration:isPlayerTrialAdmin(thePlayer) then
		triggerClientEvent(thePlayer, "buildGUI_npc911", getResourceRootElement())
	end
end
addCommandHandler("911", promptGUI)

function doTheCall(thePlayer, location, message)
	local caller = client
	if not caller or not isElement(caller) or getElementType(caller) ~= "player"
		or not (exports.integration:isPlayerSupporter(caller) or exports.integration:isPlayerTrialAdmin(caller))
		or tonumber(getElementData(caller, "loggedin")) ~= 1
		or type(location) ~= "string" or #location < 1 or #location > 100
		or type(message) ~= "string" or #message < 1 or #message > 250 then
		return false
	end
	local now = getTickCount()
	if npc911Cooldown[caller] and now - npc911Cooldown[caller] < 15000 then
		return false
	end
	npc911Cooldown[caller] = now
	local thePlayer = caller
	location = location:gsub("[%c]", " ")
	message = message:gsub("[%c]", " ")

	local playerStack = { }

	for key, value in ipairs( exports.factions:getPlayersInFaction(1) ) do -- LSPD
		table.insert(playerStack, value)
	end

	for key, value in ipairs( exports.factions:getPlayersInFaction(2)) do -- LSFD
		table.insert(playerStack, value)
	end

	--[[for key, value in ipairs( exports.factions:getPlayersInFaction(59)) do
		table.insert(playerStack, value)
	end]]

	for key, value in ipairs( exports.factions:getPlayersInFaction(50)) do -- SCoSA
		table.insert(playerStack, value)
	end

	for key, value in ipairs( exports.factions:getPlayersInFaction(164)) do -- ASH
		table.insert(playerStack, value)
	end
	
	local affectedElements = { }

	for key, value in ipairs( playerStack ) do
		for _, itemRow in ipairs(exports['item-system']:getItems(value)) do
			local setIn = false
			if (not setIn) and (itemRow[1] == 6 and itemRow[2] > 0) then
				table.insert(affectedElements, value)
				setIn = true
				break
			end
		end
	end
	local query = exports.mysql:query_insert_free("INSERT INTO `mdc_calls` (`caller`,`number`,`description`) VALUES ('Unknown Person','"..outboundPhoneNumber.."','"..exports.mysql:escape_string(tostring(location) .. " - " .. message ).."')")
	local debug = exports.logs:dbLog(thePlayer, 4, affectedElements, "911 NPC CALL - SIT: "..message.." -- LOC: "..tostring(location))
	for key, value in ipairs( affectedElements ) do
		triggerClientEvent(value, "phones:radioDispatchBeep", value)
		outputChatBox("[RADIO] This is dispatch, We've got an incident call from #" .. outboundPhoneNumber .. ", over.", value, 0, 183, 239)
		outputChatBox("[RADIO] Situation: '" .. message .. "', over.", value, 0, 183, 239)
		outputChatBox("[RADIO] Location: '" .. tostring(location) .. "', out.", value, 0, 183, 239)
	end
end
addEvent("npc911", true)
addEventHandler("npc911", getResourceRootElement(), doTheCall)
addEventHandler("onPlayerQuit", root, function() npc911Cooldown[source] = nil end)
