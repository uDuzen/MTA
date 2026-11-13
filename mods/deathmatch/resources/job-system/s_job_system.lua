mysql = exports.mysql
local vehicleLockTimers = setmetatable({}, { __mode = "k" })
chDimension = 125
chInterior = 3

-- CALL BACKS FROM CLIENT

function onEmploymentServer()
	local player = client
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then
		return false
	end
	exports.global:sendLocalText(player, "Jessie Smith says: Hello, are you looking for a new job?", nil, nil, nil, 10)
	exports.global:sendLocalText(player, " *Jessie Smith hands over a list with jobs to " .. getPlayerName(player):gsub("_", " ") .. ".", 255, 51, 102)
end

addEvent("onEmploymentServer", true)
addEventHandler("onEmploymentServer", getRootElement(), onEmploymentServer)

function givePlayerJob(jobID)
	local player = client
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then
		return false
	end
	jobID = tonumber(jobID)
	if not jobID or jobID ~= math.floor(jobID) or jobID < 1 or jobID > 4
		or tonumber(getElementData(player, "job")) ~= 0 then
		return false
	end
	if jobID <= 3 and tonumber(getElementData(player, "license.car")) ~= 1 then
		return false
	end
	if jobID == 4 and exports.factions:isInFactionType(player, 2) then
		return false
	end
	local charID = tonumber(getElementData(player, "dbid"))
	if not charID or charID < 1 or charID ~= math.floor(charID) then return false end
	if not mysql:query_free("UPDATE `characters` SET `job` = " .. jobID .. " WHERE `id` = " .. charID .. " AND `job` = 0")
		or not fetchJobInfoForOnePlayer(player) or tonumber(getElementData(player, "job")) ~= jobID then
		return false
	end
	if jobID == 4 then -- CITY MAINTENANCE
		if not exports.global:giveItem(player, 115, "41:1:Spraycan") then
			mysql:query_free("UPDATE characters SET job = 0 WHERE id = " .. charID .. " AND job = 4")
			fetchJobInfoForOnePlayer(player)
			return false
		end
		if not mysql:query_free("UPDATE characters SET tag = 9 WHERE id = " .. charID) then
			exports.global:takeItem(player, 115, "41:1:Spraycan")
			mysql:query_free("UPDATE characters SET job = 0 WHERE id = " .. charID .. " AND job = 4")
			fetchJobInfoForOnePlayer(player)
			return false
		end
		outputChatBox("Use this spray to paint over the graffiti you find.", player, 255, 194, 14)
		exports.anticheat:changeProtectedElementDataEx(player, "tag", 9, false)
	end
	return true
end
addEvent("acceptJob", true)
addEventHandler("acceptJob", getRootElement(), givePlayerJob)

function fetchJobInfo()
	for _, player in ipairs(getElementsByType("player")) do
		fetchJobInfoForOnePlayer(player)
	end
end

function fetchJobInfoForOnePlayer(thePlayer)
	if not isElement(thePlayer) or getElementType(thePlayer) ~= "player" then return false end
	local charID = tonumber(getElementData(thePlayer, "dbid"))
	if not charID or charID < 1 or charID ~= math.floor(charID) then return false end
	local jobInfo = mysql:query_fetch_assoc("SELECT characters.`job`, jobs.`jobID`, jobs.`jobLevel`, jobs.`jobProgress`, jobs.`jobTruckingRuns` FROM `characters` LEFT JOIN `jobs` ON characters.`id` = jobs.`jobCharID` AND characters.`job` = jobs.`jobID` WHERE characters.`id` = " .. charID .. " LIMIT 1")
	if jobInfo then
		local job = tonumber(jobInfo["job"])
		local jobID = tonumber(jobInfo["jobID"])
		if job and job == 0 then
			setElementData(thePlayer, "job", 0, true)
			setElementData(thePlayer, "jobLevel", 0 , true)
			setElementData(thePlayer, "jobProgress", 0, true)
			setElementData(thePlayer, "job-system-trucker:truckruns", 0, true)
			return true
		end
		
		if not jobID then
			mysql:query_free("INSERT INTO `jobs` SET `jobID`='"..tostring(job).."', `jobCharID`='"..mysql:escape_string(charID).."' ")
		end
	
		setElementData(thePlayer, "job", job, true)
		setElementData(thePlayer, "jobLevel", tonumber(jobInfo["jobLevel"]) or 1, true)
		setElementData(thePlayer, "jobProgress", tonumber(jobInfo["jobProgress"]) or 0, true)
		setElementData(thePlayer, "job-system-trucker:truckruns", tonumber(jobInfo["jobTruckingRuns"]) or 0, true)
	else
		outputDebugString("[Job system] fetchJobInfoForOnePlayer / DB error")
		return false
	end
end

function printJobInfo(thePlayer)
	outputChatBox("~-~-~-~-~-~-~-~-~-~Career Information~-~-~-~-~-~-~-~-~-~-~", thePlayer, 255, 194, 14)
	outputChatBox("Job: "..(getJobTitleFromID(getElementData(thePlayer, "job")) or "Unemployed") , thePlayer, 255, 194, 14)
	outputChatBox("Title/Level: "..(tonumber(getElementData(thePlayer, "jobLevel")) or "0") , thePlayer, 255, 194, 14)
	outputChatBox("Progress: "..(tonumber(getElementData(thePlayer, "jobProgress")) or "0") , thePlayer, 255, 194, 14)
	outputChatBox("~-~-~-~--~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-", thePlayer, 255, 194, 14)
end
addCommandHandler("myjob", printJobInfo)

function quitJob(source)
	local logged = getElementData(source, "loggedin")
	if logged == 1 then
		local job = tonumber(getElementData(source, "job")) or 0
		if job == 0 then
			outputChatBox("You are currently unemployed.", source, 255, 0, 0)
		else
			local charID = tonumber(getElementData(source, "dbid"))
			if not charID or charID < 1 or charID ~= math.floor(charID)
				or not mysql:query_free("UPDATE `characters` SET `job` = 0 WHERE `id` = " .. charID)
				or not fetchJobInfoForOnePlayer(source)
				or tonumber(getElementData(source, "job")) ~= 0 then
				outputChatBox("Your job could not be ended. Please try again later.", source, 255, 0, 0)
				return false
			end
			if job == 4 then
				if not mysql:query_free("UPDATE characters SET tag = 1 WHERE id = " .. charID) then
					outputDebugString("[Job system] Failed to reset city maintenance tag for " .. getPlayerName(source), 1)
				else
					exports.anticheat:changeProtectedElementDataEx(source, "tag", 1, false)
				end
			end
			triggerClientEvent(source, "quitJob", source, job)
		end
	end
end
addCommandHandler("endjob", quitJob, false, false)
addCommandHandler("quitjob", quitJob, false, false)

-- PREVENT UNEMPLOYED PLAYER GETTING IN DRIVER SEAT OR JACKING JOB VEHICLES -- MAXIME
function startEnterVehJob(thePlayer, seat, jacked)
	if not isElement(source) or getElementType(source) ~= "vehicle" or not isElement(thePlayer)
		or getElementType(thePlayer) ~= "player" then return end
	local vjob = tonumber(getElementData(source, "job")) or 0
	local job = tonumber(getElementData(thePlayer, "job")) or 0
	if vjob > 0 and job ~= vjob and tonumber(seat) == 0
		and tonumber(getElementData(thePlayer, "duty_admin")) ~= 1
		and tonumber(getElementData(thePlayer, "duty_supporter")) ~= 1 then
		if (vjob==1) then
			outputChatBox("You are not a delivery driver. Visit city hall to obtain this job.", thePlayer, 255, 0, 0)
		elseif (vjob==2) then
			outputChatBox("You are not a taxi driver. Visit city hall to obtain this job.", thePlayer, 255, 0, 0)
		elseif (vjob==3) then
			outputChatBox("You are not a bus driver. Visit city hall to obtain this job.", thePlayer, 255, 0, 0)
		end
		if not isVehicleLocked(source) and not isTimer(vehicleLockTimers[source]) then
			setVehicleLocked(source, true)
			vehicleLockTimers[source] = setTimer(function(vehicle)
				if isElement(vehicle) then setVehicleLocked(vehicle, false) end
				vehicleLockTimers[vehicle] = nil
			end, 5000, 1, source)
		end
	end
end
addEventHandler("onVehicleStartEnter", getRootElement(), startEnterVehJob)

addEventHandler("onElementDestroy", root, function()
	if getElementType(source) == "vehicle" and isTimer(vehicleLockTimers[source]) then
		killTimer(vehicleLockTimers[source])
		vehicleLockTimers[source] = nil
	end
end)

--[[ -- Removed by MAXIME  
function resetContract( thePlayer, commandName, targetPlayerName )
	if (exports.integration:isPlayerTrialAdmin(thePlayer) or exports.integration:isPlayerSupporter(thePlayer)) then
		if targetPlayerName then
			local targetPlayer, targetPlayerName = exports.global:findPlayerByPartialNick( thePlayer, targetPlayerName )
			if targetPlayer then
				if getElementData( targetPlayer, "loggedin" ) == 1 then
					local result = mysql:query_free("UPDATE characters SET jobcontract = 0 WHERE id = " .. mysql:escape_string(getElementData( targetPlayer, "dbid" )) .. " AND jobcontract > 0" )
					if result then
						outputChatBox( "Reset Job Contract for " .. targetPlayerName, thePlayer, 0, 255, 0 )
					else
						outputChatBox( "Failed to reset Job Contract Time.", thePlayer, 255, 0, 0 )
					end
				else
					outputChatBox( "Player is not logged in.", thePlayer, 255, 0, 0 )
				end
			end
		else
			outputChatBox( "SYNTAX: /" .. commandName .. " [player]", thePlayer, 255, 194, 14 )
		end
	end
end
--addCommandHandler("resetcontract", resetContract, false, false)
]]