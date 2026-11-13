--[[
* ***********************************************************************************************************************
* Copyright (c) 2015 OwlGaming Community - All Rights Reserved
* All rights reserved. This program and the accompanying materials are private property belongs to OwlGaming Community
* Unauthorized copying of this file, via any medium is strictly prohibited
* Proprietary and confidential
* ***********************************************************************************************************************
]]

local mysql = exports.mysql
local pendingSpawnLocations = {}
addEvent( "account:character:spawned", false )
addEvent( 'account:character:select', false )
addEvent( 'accounts:characters:fixCharacterSpawnPosition', true )

function characterList( theClient )
    local characters = { }
    local clientAccountID = getElementDataEx(theClient, "account:id") or -1

    local result = mysql:query("SELECT skincolor,`id`, `charactername`, `cked`, TIMESTAMPDIFF(YEAR, `date_of_birth`, CURDATE()) AS `real_age`, `weight`, `height`, `description`, `gender`, `skin`, `clothingid`, `hoursplayed` FROM `characters` WHERE `account`='" .. mysql:escape_string(clientAccountID) .. "' AND `active` = 1 ORDER BY `cked` ASC, `lastlogin` DESC")
    if not result then return characters end
    if (mysql:num_rows(result) > 0) then
        local i = 1
        while result do
            local row = mysql:fetch_assoc(result)
            if not row then break end

            characters[i] = { }
            characters[i][1] = tonumber(row["id"])
            characters[i][2] = row["charactername"]
            characters[i][3] = tonumber(row["cked"])
            characters[i][4] = tonumber(row["hoursplayed"])
            characters[i][5] = tonumber(row["real_age"])
            characters[i][6] = tonumber(row["gender"])
            characters[i][7] = tonumber(row["skincolor"])
            characters[i][8] = nil
            characters[i][9] = tonumber(row["skin"])
            characters[i][11] = tonumber(row["weight"])
            characters[i][12] = tonumber(row["height"])
            characters[i][13] = nil
            characters[i][14] = nil
            characters[i][15] = tonumber(row["clothingid"])

            i = i + 1
        end
    end
    mysql:free_result(result)
    return characters
end

function forumLogin(username, password)
    if not client or not isElement(client) or getElementType(client) ~= "player"
        or type(username) ~= "string" or #username < 1 or #username > 64
        or type(password) ~= "string" or #password < 1 or #password > 128 then
        return false
    end
    local result, er = exports.integration:logintoForumAccount(username, password)
    if result then
        local forumID = tonumber(result.member_id)
        local accountID = tonumber(getElementData(client, "account:id"))
        if not forumID or forumID < 1 or not accountID or accountID < 1 then
            result = false
            er = "Invalid forum or account identifier"
        else
            setElementData(client, "account:forumid", forumID)
            mysql:query_free("UPDATE accounts SET forumid=" .. forumID .. " WHERE id=" .. accountID)
            --exports.integration:fetchForumInfo(forumID, client)
        end
    end
    triggerClientEvent(client, "forum:loginResult", resourceRoot, result, er)
end
addEvent("forum:login", true)
addEventHandler("forum:login", resourceRoot, forumLogin)

function removeForum()
    if not client or not isElement(client) or getElementType(client) ~= "player" then return false end
    local username = getElementData(client, "account:username")
    if type(username) ~= "string" then return false end
    mysql:query_free("UPDATE accounts SET forumid=NULL WHERE username='"..mysql:escape_string(username).."'")
    removeElementData(client, "account:forumid")
end
addEvent("forum:remove", true)
addEventHandler("forum:remove", resourceRoot, removeForum)

function reloadCharacters(fromButton)
    if not client or not isElement(client) or getElementType(client) ~= "player" then return false end
    local player = client
    local chars = characterList(player)
    exports.anticheat:changeProtectedElementDataEx(player, "account:characters", chars)
    if fromButton == true then
        triggerClientEvent(player, "refreshCharacters", resourceRoot)
    end
    return true
end
addEvent("updateCharacters", true)
addEventHandler("updateCharacters", getRootElement(), reloadCharacters)


function reconnectMe()
    if not client or not isElement(client) or getElementType(client) ~= "player" then return false end
    redirectPlayer(client, "", 0)
end
addEvent("accounts:reconnectMe", true)
addEventHandler("accounts:reconnectMe", getRootElement(), reconnectMe)

--/LOGINTO FOR LEAD+
function adminLoginToPlayerCharacter(thePlayer, commandName, ...)
    if exports.integration:isPlayerLeadAdmin(thePlayer) then
        if not (...) then
            outputChatBox("SYNTAX: /" .. commandName .. " [Exact Character Name]", thePlayer, 255, 194, 14, false)
            outputChatBox("Logs into player's character.", thePlayer, 255, 194, 0, false)
        else
            local targetChar = table.concat({...}, "_")
            local fetchData = mysql:query_fetch_assoc("SELECT `characters`.`id` AS `targetCharID` , `characters`.`account` AS `targetUserID` FROM `characters` WHERE `charactername`='"..mysql:escape_string(targetChar).."' LIMIT 1")
            if not fetchData then
                outputChatBox("No character name found.", thePlayer, 255,0,0)
                return false
            end
            local qh = dbQuery(exports.mysql:getConn("core"), "SELECT username, admin FROM accounts WHERE id=?", fetchData["targetUserID"])
            local result = dbPoll(qh, -1)
            if result and #result == 1 then
                local targetCharID = tonumber(fetchData["targetCharID"]) or false
                local targetUserID = tonumber(fetchData["targetUserID"]) or false
                local targetAdminLevel = tonumber(result[1]["admin"]) or 0
                local targetUsername = result[1]["username"] or false
                local theAdminPower = exports.global:getPlayerAdminLevel(thePlayer)

                if targetCharID and  targetUserID then
                    local adminTitle = exports.global:getPlayerFullIdentity(thePlayer)
                    if targetAdminLevel > theAdminPower then
                        local adminUsername = getElementData(thePlayer, "account:username")
                        outputChatBox("You can't log into Character of a higher rank admin than you.", thePlayer, 255,0,0)
                        exports.global:sendMessageToAdmins("[LOGINTO]: " .. tostring(adminTitle) .. " attempted to log into character of higher rank admin ("..targetUsername..").")
                        return false
                    end
                    exports.logs:dbLog(thePlayer, 4, thePlayer, commandName.." account "..targetUsername)
                    spawnCharacter(targetCharID, targetUserID, thePlayer, targetUsername)
                    exports.global:sendMessageToAdmins("[LOGINTO]: " .. tostring(adminTitle) .. " has logged into account '"..targetUsername.."'.")
                end
            end
        end
    end
end
addCommandHandler("loginto", adminLoginToPlayerCharacter, false, false)

function spawnCharacter(characterID, remoteAccountID, theAdmin, targetAccountName, location, freshSpawn)
    local player = theAdmin or (isElement(source) and getElementType(source) == "player" and source) or player
    if not isElement(player) or getElementType(player) ~= "player" then return false end

    characterID = tonumber(characterID)
    local accountID = theAdmin and tonumber(remoteAccountID) or tonumber(getElementDataEx(player, "account:id"))
    if not characterID or characterID < 1 or characterID ~= math.floor(characterID)
        or not accountID or accountID < 1 or accountID ~= math.floor(accountID) then
        return false
    end

    triggerEvent('setDrunkness', player, 0)
    setElementDataEx(player, "alcohollevel", 0, true)

    removeMasksAndBadges(player)

    setElementDataEx(player, "pd.jailserved")
    setElementDataEx(player, "pd.jailtime")
    setElementDataEx(player, "pd.jailtimer")
    setElementDataEx(player, "pd.jailstation")
    setElementDataEx(player, "loggedin", 0, true)
    setElementData(player, "faction", {})
    setElementData(player, "duty", 0)

    local timer = getElementData(player, "pd.jailtimer")
    if isTimer(timer) then
        killTimer(timer)
    end

    if (getPedOccupiedVehicle(player)) then
        removePedFromVehicle(player)
    end
    -- End cleaning up

    local characterData = false

    if theAdmin then
        characterData = mysql:query_fetch_assoc("SELECT *, DAY(`date_of_birth`) AS dob_day, MONTH(`date_of_birth`) AS dob_month, YEAR(`date_of_birth`) AS dob_year, TIMESTAMPDIFF(YEAR, `date_of_birth`, NOW()) AS dob_age FROM `characters` LEFT JOIN `jobs` ON `characters`.`id` = `jobs`.`jobCharID` AND `characters`.`job` = `jobs`.`jobID` WHERE `id`='" .. tostring(characterID) .. "' AND `account`='" .. tostring(accountID) .. "'")
    else
        characterData = mysql:query_fetch_assoc("SELECT *, DAY(`date_of_birth`) AS dob_day, MONTH(`date_of_birth`) AS dob_month, YEAR(`date_of_birth`) AS dob_year, TIMESTAMPDIFF(YEAR, `date_of_birth`, NOW()) AS dob_age FROM `characters` LEFT JOIN `jobs` ON `characters`.`id` = `jobs`.`jobCharID` AND `characters`.`job` = `jobs`.`jobID` WHERE `id`='" .. tostring(characterID) .. "' AND `account`='" .. tostring(accountID) .. "' AND `cked`=0")
    end

    if characterData then
        setElementDataEx(player, "look", fromJSON(characterData["description"]) or {"", "", "", "", characterData["description"], ""})
        setElementDataEx(player, "weight", characterData["weight"])
        setElementDataEx(player, "height", characterData["height"])
        setElementDataEx(player, "race", tonumber(characterData["skincolor"]))
        setElementDataEx(player, "maxvehicles", tonumber(characterData["maxvehicles"]))
        setElementDataEx(player, "maxinteriors", tonumber(characterData["maxinteriors"]))
        --DATE OF BIRTH
        setElementDataEx(player, "age", tonumber(characterData["dob_age"]))
        setElementDataEx(player, "month", tonumber(characterData["dob_month"]))
        setElementDataEx(player, "day", tonumber(characterData["dob_day"]))
        setElementDataEx(player, "year", tonumber(characterData["dob_year"]))

        -- LANGUAGES
        local lang1 = tonumber(characterData["lang1"])
        local lang1skill = tonumber(characterData["lang1skill"])
        local lang2 = tonumber(characterData["lang2"])
        local lang2skill = tonumber(characterData["lang2skill"])
        local lang3 = tonumber(characterData["lang3"])
        local lang3skill = tonumber(characterData["lang3skill"])
        local currentLanguage = tonumber(characterData["currlang"]) or 1
        setElementDataEx(player, "languages.current", currentLanguage, false)

        if lang1 == 0 then
            lang1skill = 0
        end

        if lang2 == 0 then
            lang2skill = 0
        end

        if lang3 == 0 then
            lang3skill = 0
        end

        setElementDataEx(player, "languages.lang1", lang1, false)
        setElementDataEx(player, "languages.lang1skill", lang1skill, false)

        setElementDataEx(player, "languages.lang2", lang2, false)
        setElementDataEx(player, "languages.lang2skill", lang2skill, false)

        setElementDataEx(player, "languages.lang3", lang3, false)
        setElementDataEx(player, "languages.lang3skill", lang3skill, false)
        -- END OF LANGUAGES

        setElementDataEx(player, "timeinserver", tonumber(characterData["timeinserver"]), false)
        setElementDataEx(player, "account:character:id", characterID, false)
        setElementDataEx(player, "dbid", characterID, true) -- workaround
        exports['item-system']:loadItems( player, true )


        setElementDataEx(player, "loggedin", 1, true)

        -- Check his name isn't in use by a squatter
        local playerWithNick = getPlayerFromName(tostring(characterData["charactername"]))
        if isElement(playerWithNick) and (playerWithNick~=player) then
            if theAdmin then
                local adminTitle = exports.global:getPlayerAdminTitle(theAdmin)
                local adminUsername = getElementData(theAdmin, "account:username")
                kickPlayer(playerWithNick, getRootElement(), adminTitle.." "..adminUsername.." has logged into your account.")
                outputChatBox("Account "..targetAccountName.." ("..tostring(characterData["charactername"]):gsub("_"," ")..") has been kicked out of game.", theAdmin, 0, 255, 0 )
            else
                kickPlayer(playerWithNick, getRootElement(), "Someone else has logged into your character.")
            end
        end

        setElementDataEx(player, "bleeding", 0, false)

        -- Set their name to the characters
        setElementDataEx(player, "legitnamechange", 1)
        setPlayerName(player, tostring(characterData["charactername"]))
        local pid = getElementData(player, "playerid")
        local fixedName = string.gsub(tostring(characterData["charactername"]), "_", " ")

        setElementDataEx(player, "legitnamechange", 0)


        setPlayerNametagShowing(player, false)
        setElementFrozen(player, true)
        setPedGravity(player, 0)

        local locationToSpawn = {}
        locationToSpawn.x = tonumber(characterData["x"])
        locationToSpawn.y = tonumber(characterData["y"])
        locationToSpawn.z = tonumber(characterData["z"])
        locationToSpawn.rot = tonumber(characterData["rotation"])
        locationToSpawn.int = tonumber(characterData["interior_id"])
        locationToSpawn.dim = tonumber(characterData["dimension_id"])
        spawnPlayer(player, locationToSpawn.x ,locationToSpawn.y ,locationToSpawn.z , locationToSpawn.rot, tonumber(characterData["skin"]))
        setElementDimension(player, locationToSpawn.dim)
        setElementInterior(player, locationToSpawn.int , locationToSpawn.x, locationToSpawn.y, locationToSpawn.z)
        setCameraInterior(player, locationToSpawn.int)


        setCameraTarget(player, player)
        setPedArmor(player, tonumber(characterData["armor"]))

        -- Handle all faction info
        local qh = dbQuery(mysql:getConn("mta"), "SELECT * FROM characters_faction WHERE character_id=? ORDER BY id ASC", tonumber(characterData["id"]))
        local result, num_affected_rows = dbPoll ( qh, 10000 )

        if result and num_affected_rows > 0 then
            local factionT = {}
            local count = 0
            for _, row in pairs(result) do
                count = count+1
                factionT[row.faction_id] = { rank = row.faction_rank, leader = row.faction_leader == 1 or false, phone = row.faction_phone, perks =  type(row.faction_perks) == "string" and fromJSON(row.faction_perks) or { }, count = count }
            end
            local duty = tonumber(characterData["duty"]) or 0
            setElementData(player, "duty", duty)

            -- check if the player has the duty package
            if duty > 0 then
                local foundPackage = false
                for k,v in pairs(factionT) do
                    for key, value in ipairs(v.perks) do
                        if tonumber(value) == tonumber(duty) then
                            foundPackage = true
                            break
                        end
                    end
                end

                if not foundPackage then
                    triggerEvent("duty:offduty", player)
                    outputChatBox("You don't have access to the duty you are using anymore - thus, removed.", player, 255, 0, 0)
                end
            end

            setElementData(player, "factionMenu", 0)
            setElementData(player, "faction", factionT)
        else -- Aren't in any faction, just a citizen.
            setElementData(player, "factionMenu", 0)
            setElementData(player, "faction", { })
            dbFree(qh)
        end

        local team = getTeamFromName("Citizen") -- Needed for using team chat.
        setPlayerTeam(player, team)
        local adminLevel = getElementDataEx(player, "admin_level")
        local gmLevel = getElementDataEx(player, "account:gmlevel")
        exports.global:updateNametagColor(player)
        -- ADMIN JAIL
        local jailed = getElementData(player, "adminjailed")
        local jailed_time = getElementData(player, "jailtime")
        local jailed_by = getElementData(player, "jailadmin")
        local jailed_reason = getElementData(player, "jailreason")

        if location then
            setElementPosition(player, location[1], location[2], location[3])
            setElementRotation(player, 0, 0, location[4])
        end

        if jailed then
            local incVal = getElementData(player, "playerid")

            setElementDimension(player, 55000+incVal)
            setElementInterior(player, 6)
            setCameraInterior(player, 6)
            setElementPosition(player, 263.821807, 77.848365, 1001.0390625)
            setPedRotation(player, 267.438446)

            setElementDataEx(player, "jailserved", 0, false)
            setElementDataEx(player, "adminjailed", true)
            setElementDataEx(player, "jailreason", jailed_reason, false)
            setElementDataEx(player, "jailadmin", jailed_by, false)

            if jailed_time ~= 999 then
                if not getElementData(player, "jailtimer") then
                    setElementDataEx(player, "jailtime", jailed_time+1, false)
                    triggerEvent("admin:timerUnjailPlayer", player, player)
                end
            else
                setElementDataEx(player, "jailtime", "Unlimited", false)
                setElementDataEx(player, "jailtimer", true, false)
            end
            setElementInterior(player, 6)
            setCameraInterior(player, 6)
        end

        setElementDataEx(player, "legitnamechange", 0)
        setElementDataEx(player, "muted", tonumber(getElementData(player, "muted")) or 0)
        setElementDataEx(player, "hoursplayed",  tonumber(characterData["hoursplayed"]), true)
        setPlayerAnnounceValue ( player, "score", characterData["hoursplayed"] )
        setElementDataEx(player, "alcohollevel", tonumber(characterData["alcohollevel"]) or 0, true)
        exports.global:setMoney(player, tonumber(characterData["money"]), true)
        exports.global:checkMoneyHacks(player)

        setElementDataEx(player, "restrain", tonumber(characterData["cuffed"]), true)
        setElementDataEx(player, "tazed", false, false)
        setElementDataEx(player, "realinvehicle", 0, false)

        -- Job system - MAXIME
        setElementData(player, "job", tonumber(characterData["job"]) or 0, true)
        setElementData(player, "jobLevel", tonumber(characterData["jobLevel"]) or 0, true)
        setElementData(player, "jobProgress", tonumber(characterData["jobProgress"]) or 0, true)

        -- MAXIME JOB SYSTEM
        if tonumber(characterData["job"]) == 1 then
            if characterData["jobTruckingRuns"] then
                setElementData(player, "job-system-trucker:truckruns", tonumber(characterData["jobTruckingRuns"]), true)
                mysql:query_free("UPDATE `jobs` SET `jobTruckingRuns`='0' WHERE `jobCharID`='"..tostring(characterID).."' AND `jobID`='1' " )
            end
            triggerClientEvent(player,"restoreTruckerJob",player)
        end
        triggerEvent("restoreJob", player)
        triggerClientEvent(player, "updateCollectionValue", player, tonumber(characterData["photos"]))
        --------------------------------------------------------------------------
        setElementDataEx(player, "license.car", tonumber(characterData["car_license"]), true)
        setElementDataEx(player, "license.bike", tonumber(characterData["bike_license"]), true)
        setElementDataEx(player, "license.boat", tonumber(characterData["boat_license"]), true)
        setElementDataEx(player, "license.pilot", tonumber(characterData["pilot_license"]), true)
        setElementDataEx(player, "license.fish", tonumber(characterData["fish_license"]), true)
        setElementDataEx(player, "license.gun", tonumber(characterData["gun_license"]), true)
        setElementDataEx(player, "license.gun2", tonumber(characterData["gun2_license"]), true)

        setElementDataEx(player, "bankmoney", tonumber(characterData["bankmoney"]), true)
        setElementDataEx(player, "fingerprint", tostring(characterData["fingerprint"]), false)
        setElementDataEx(player, "tag", tonumber(characterData["tag"]))
        setElementDataEx(player, "blindfold", tonumber(characterData["blindfold"]), false)
        setElementDataEx(player, "gender", tonumber(characterData["gender"]))
        setElementDataEx(player, "deaglemode", 1, true) -- Default to lethal
        setElementDataEx(player, "shotgunmode", 1, true) -- Default to lethal
        setElementDataEx(player, "firemode", 0, true) -- Default to auto
        setElementDataEx(player, "clothing:id", tonumber(characterData["clothingid"]) or nil, true)
        
        if tonumber(characterData["pdjail"]) == 1 then -- PD JAIL Chaos New System
            setElementData(player, "jailed", 1)
            exports["prison-system"]:checkForRelease(player, true)
        end

        if (tonumber(characterData["restrainedobj"])>0) then
            setElementDataEx(player, "restrainedObj", tonumber(characterData["restrainedobj"]), false)
        end

        if ( tonumber(characterData["restrainedby"])>0) then
            setElementDataEx(player, "restrainedBy",  tonumber(characterData["restrainedby"]), false)
        end

        -- Cleaning their old weapons
        takeAllWeapons(player)

        if (getElementType(player) == 'player') then
            triggerEvent("updateLocalGuns", player)
        end


        setPedStat(player, 70, 999)
        setPedStat(player, 71, 999)
        setPedStat(player, 72, 999)
        setPedStat(player, 74, 999)
        setPedStat(player, 76, 999)
        setPedStat(player, 77, 999)
        setPedStat(player, 78, 999)
        setPedStat(player, 77, 999)
        setPedStat(player, 78, 999)
        setPedStat(player, 79, 999) -- Strafeing fix

        toggleAllControls(player, true, true, true)
        setElementFrozen(player, false)

        -- Player is cuffed
        if (tonumber(characterData["cuffed"])==1) then
            toggleControl(player, "sprint", false)
            toggleControl(player, "fire", false)
            toggleControl(player, "jump", false)
            toggleControl(player, "next_weapon", false)
            toggleControl(player, "previous_weapon", false)
            toggleControl(player, "accelerate", false)
            toggleControl(player, "brake_reverse", false)
            toggleControl(player, "aim_weapon", false)
        end

        -- Impounded cars, old location


        setPedFightingStyle(player, tonumber(characterData["fightstyle"]))
        triggerEvent("onCharacterLogin", player, fixedName)

        if not location then
            location = { locationToSpawn.x, locationToSpawn.y, locationToSpawn.z, locationToSpawn.rot, locationToSpawn.int, locationToSpawn.dim }
        end
        pendingSpawnLocations[player] = location

        triggerClientEvent(player, "accounts:characters:spawn", player, fixedName, adminLevel, gmLevel, location)
        triggerClientEvent(player, "item:updateclient", player)

        if theAdmin then
            local adminTitle = exports.global:getPlayerAdminTitle(theAdmin)
            local adminUsername = getElementData(theAdmin, "account:username")
            outputChatBox("You've logged into player's character successfully!", theAdmin, 0, 255, 0 )
            local hiddenAdmin = getElementData(theAdmin, "hiddenadmin")
            if hiddenAdmin == 0 then
                exports.global:sendMessageToAdmins("AdmCmd: " .. tostring(adminTitle) .. " "..adminUsername.." logged into an other account ("..targetAccountName..") "..tostring(characterData["charactername"]):gsub("_"," ")..".")
            end
        else
            mysql:query_free("UPDATE characters SET lastlogin=NOW() WHERE id='" .. mysql:escape_string(characterID) .. "'")
            exports.logs:dbLog("ac"..tostring(accountID), 27, { "ac"..tostring(accountID), player } , "Spawned" )
            local monitored = getElementData(player, "admin:monitor")
            if monitored then
                if monitored ~= "New Player" then
                    exports.global:sendMessageToAdmins("[MONITOR] ".. getPlayerName(player):gsub("_", " ") .." ("..pid.."): "..monitored)
                    exports.global:sendMessageToSupporters("[MONITOR] ".. getPlayerName(player):gsub("_", " ") .." ("..pid.."): "..monitored)
                end
            end
        end

        setTimer(setPedGravity, 2000, 1, player, 0.008)
        setElementAlpha(player, 255)

        -- WALKING STYLE
        triggerEvent("realism:applyWalkingStyle", player, characterData["walkingstyle"] or 128, true)

        -- blindfolds
        if (tonumber(characterData["blindfold"])==1) then
            setElementDataEx(player, "blindfold", 1)
            outputChatBox("Your character is blindfolded. If this was an OOC action, please contact an administrator via F2.", player, 255, 194, 15)
            fadeCamera(player, false)
        else
            fadeCamera(player, true, 4)
        end

        if (tonumber(characterData["cuffed"])==1) then
            outputChatBox("Your character is restrained.", player, 255, 0, 0)
        end

        setElementHealth(player, tonumber(characterData["health"]))

        --character settings / MAXIME
        loadCharacterSettings(player,characterID)
        setTimer(executeCommandHandler, 3000, 1, "stats", player)
        triggerClientEvent(player, "drawAllMyInteriorBlips", player)

        --MOTD / MAXIME /2015.1.9
        triggerEvent("playerGetMotds", player)

        triggerEvent("item-system:addPlayerArtifacts", player)

        triggerEvent( "account:character:spawned", player ) -- have an event that we can call when a character is spawned.
        triggerClientEvent( player, "account:character:spawned", player ) -- have an event that we can call when a character is spawned.
        --outputDebugString('account:character:spawned')
        if freshSpawn then
            triggerEvent( "social:look", player, player, ":edit" )
        end
    end
end
addEventHandler("accounts:characters:spawn", getRootElement(), spawnCharacter)

function Characters_onCharacterChange()
    if not client then return false end
    pendingSpawnLocations[client] = nil
    triggerClientEvent(client, "items:inventory:hideinv", client)
    --triggerEvent("updateCharacters", client) -- Refresh the character selection screen, perhaps? / No it's too late to update shit here
    triggerEvent("savePlayer", client, "Change Character")
    triggerEvent('setDrunkness', client, 0)
    setElementDataEx(client, "alcohollevel", 0, true)
    setElementDataEx(client, "clothing:id", nil, true)
    removeMasksAndBadges(client)

    setElementDataEx(client, "loggedin", 0, true)
    setElementDataEx(client, "dbid", 0, true)
    setElementDataEx(client, "bankmoney", 0)
    setElementDataEx(client, "account:character:id", false)
    setElementAlpha(client, 0)

    --[[removeElementData(client, "jailed")
    removeElementData(client, "jail_time")
    removeElementData(client, "jail:id")
    removeElementData(client, "jail:cell")
    removeElementData(client, "jail_time_online")
    removeElementData(client, "jail:timer")]]
    setElementData(client, "dispatch:onDuty", false)
    triggerClientEvent(root, "dispatch:onDutyChange", root, false, client)
    removeElementData(client, "enableGunAttach")
    triggerEvent("destroyWepObjects", client)
    triggerEvent("cards:leave_session", client)
    triggerEvent("endViewPropertyInterior", client, client, true)

    if (getPedOccupiedVehicle(client)) then
        removePedFromVehicle(client)
    end
    exports.global:updateNametagColor(client)
    local clientAccountID = getElementDataEx(client, "account:id") or -1

    setElementInterior(client, 0)
    setElementDimension(client, 1)
    setElementPosition(client, -26.8828125, 2320.951171875, 24.303373336792)

    setElementDataEx(client, "legitnamechange", 1)
    makeOwlName(client)
    setElementDataEx(client, "legitnamechange", 0)

    exports.logs:dbLog("ac"..tostring(clientAccountID), 27, { "ac"..tostring(clientAccountID), client } , "Went to character selection" )
    triggerEvent("shop:removeMeFromCurrentShopUser",client, client)
    triggerClientEvent(client, "hideGeneralshopUI", client)
    triggerEvent("artifacts:removeAllOnPlayer",client, client)

    removeElementData(client, "chat:status")

    --outputDebugString('account:character:select')
    triggerEvent( "account:character:select", client ) -- have an event that we can call when player comes to character selectio screen.
    triggerClientEvent( client, "account:character:select", client ) -- have an event that we can call when player comes to character selectio screen.

    --keypad door lock
    local padId = getElementData(client, "padUsing")
    if padId then
        removeElementData(client, "padUsing")
        for key, thePad in pairs(getElementsByType("object", getResourceRootElement(getResourceFromName("item-world")))) do
            if getElementData(thePad, "id") == padId then
                removeElementData(thePad, "playerUsing")
                break
            end
        end
    end
end
addEventHandler("accounts:characters:change", getRootElement(), Characters_onCharacterChange)

-- sometimes your character position is not properly set, and your position is retained from the char selection (somewhere near angel pine) albeit it shouldn't be.
function fixCharacterSpawnPosition()
    local player = client
    if not player or not isElement(player) or getElementType(player) ~= "player"
        or tonumber(getElementData(player, "loggedin")) ~= 1 then
        return false
    end
    local expectedLocation = pendingSpawnLocations[player]
    pendingSpawnLocations[player] = nil
    if type(expectedLocation) ~= "table" then return false end
    local expectedPositionX = tonumber(expectedLocation[1])
    local expectedPositionY = tonumber(expectedLocation[2])
    local expectedPositionZ = tonumber(expectedLocation[3])
    local expectedInterior = tonumber(expectedLocation[5]) or 0
    local expectedDimension = tonumber(expectedLocation[6]) or 0
    if not expectedPositionX or not expectedPositionY or not expectedPositionZ then return false end

    local currentPositionX, currentPositionY = getElementPosition(player)
    if getDistanceBetweenPoints2D(currentPositionX, currentPositionY, unpack(defaultCharacterSelectionSpawnPosition)) < 20
        and getDistanceBetweenPoints2D(expectedPositionX, expectedPositionY, unpack(defaultCharacterSelectionSpawnPosition)) > 20 then
        setElementPosition(player, expectedPositionX, expectedPositionY, expectedPositionZ)
        setElementInterior(player, expectedInterior)
        setElementDimension(player, expectedDimension)
        return true
    end
    return false
end
addEventHandler("onPlayerQuit", root, function()
    pendingSpawnLocations[source] = nil
end)
addEventHandler("accounts:characters:fixCharacterSpawnPosition", root, fixCharacterSpawnPosition)

function removeMasksAndBadges(client)
    for k, v in ipairs({exports['item-system']:getMasks(), exports['item-system']:getBadges()}) do
        for kx, vx in pairs(v) do
            if getElementData(client, vx[1]) then
                setElementDataEx(client, vx[1], false, true)
            end
        end
    end
end

function flushPlayerAvatars ( quitType )
    local id = getElementData(source, 'account:id')
    local fid = getElementData(source, 'account:forumid')
    if id then
        exports.cache:removeImage(id, false)
    end
    if fid then
        --exports.cache:removeImage('http://owlgaming.net/favatar.php?id='..fid, true)
    end
end
addEventHandler ( "onPlayerQuit", getRootElement(), flushPlayerAvatars )
