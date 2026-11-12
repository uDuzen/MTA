mods = {}

function showSpeedToAdmins(velocity)
	local player = client
	velocity = tonumber(velocity)
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or not velocity or velocity ~= velocity or velocity < 0 or velocity > 1000 then return false end
	local kph = math.ceil(velocity * 1.609344)
	exports.global:sendMessageToAdmins("[Possible Speedhack/HandlingHack] " .. getPlayerName(player) .. ": " .. velocity .. "Mph/".. kph .." Kph")
end
addEvent("alertAdminsOfSpeedHacks", true)
addEventHandler("alertAdminsOfSpeedHacks", getRootElement(), showSpeedToAdmins)

function showDMToAdmins(kills)
	local player = client
	kills = tonumber(kills)
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or not kills or kills ~= math.floor(kills) or kills < 0 or kills > 10000 then return false end
	exports.global:sendMessageToAdmins("[Possible DeathMatching] " .. getPlayerName(player) .. ": " .. kills .. " kills in <=2 Minutes.")
end
addEvent("alertAdminsOfDM", true)
addEventHandler("alertAdminsOfDM", getRootElement(), showDMToAdmins)

-- [MONEY HACKS]
function scanMoneyHacks()
	local hackers = { }
	local hackersMoney = { }
	local counter = 0

	local players = exports.pool:getPoolElementsByType("player")
	for key, value in ipairs(players) do
		local logged = getElementData(value, "loggedin")
		if (logged==1) then
			if not (exports.integration:isPlayerTrialAdmin(value)) then -- Only check if its not an admin...

				local money = tonumber(getPlayerMoney(value))
				local truemoney = tonumber(exports.global:getMoney(value))
				if money and truemoney and money == money and truemoney == truemoney
					and money ~= math.huge and truemoney ~= math.huge then
					if money > truemoney then
						counter = counter + 1
						hackers[counter] = value
						hackersMoney[counter] = (money-truemoney)
					end
				end
			end
		end
	end
	for key, value in ipairs(hackers) do
		local money = hackersMoney[key]
		if isElement(value) and getElementType(value) == "player" then
			local playerName = getPlayerName(value) or "Unknown"
			exports.global:sendMessageToAdmins(
				"[AntiCheat] Possible money hack: " .. playerName ..
				" has $" .. tostring(money) .. " more client-side money than the server account."
			)
		end
	end
end
setTimer(scanMoneyHacks, 3600000, 0) -- Every 60 minutes

function outputModInfo(thePlayer, command, targetPlayer)
	if not exports.integration:isPlayerTrialAdmin(thePlayer) then return end
	if not targetPlayer then
		outputChatBox("SYNTAX: /" .. command .. " [Player Partial Name/ID]", thePlayer, 255, 194, 14)
		return
	else
		local targetPlayer, targetPlayerName = exports.global:findPlayerByPartialNick(thePlayer, targetPlayer)
		if targetPlayer then
			if mods[targetPlayer] then
				for filename, modList in pairs(mods[targetPlayer]) do
					outputChatBox("===== "..filename.." =====", thePlayer, 255, 194, 14)
					-- Print details on each modification
					for idx,item in ipairs(modList) do
						outputChatBox( idx .. ") id: " .. item.id .. " name: " .. item.name, thePlayer, 255, 194, 14)
						if item.sizeX then
							outputChatBox( "size: " .. item.sizeX .. "," .. item.sizeY .. "," .. item.sizeZ, thePlayer, 255, 194, 14)
							outputChatBox( "originalSize: " .. item.originalSizeX .. "," .. item.originalSizeY .. "," .. item.originalSizeZ, thePlayer, 255, 194, 14)
						end
						if item.length then
							outputChatBox( "length: " .. item.length .. " md5: " .. item.md5, thePlayer, 255, 194, 14)
						end
					end
				end
			else
				outputChatBox("No modifications found.", thePlayer, 255, 194, 14)
			end
		else
			outputChatBox("Player not found.", thePlayer, 255, 0, 0)
		end
	end
end
addCommandHandler("mods", outputModInfo)

function handleOnPlayerModInfo ( filename, modList )
	if not mods[source] then
		mods[source] = {}
	end
	mods[source][filename] = modList
end
addEventHandler ( "onPlayerModInfo", getRootElement(), handleOnPlayerModInfo )

-- Ensure no one gets missed when the resource is (re)started
addEventHandler( "onResourceStart", resourceRoot,
    function()
        for _,plr in ipairs( exports.pool:getPoolElementsByType("player") ) do
            resendPlayerModInfo( plr )
        end
    end
)
