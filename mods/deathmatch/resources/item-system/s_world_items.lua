--[[
* ***********************************************************************************************************************
* Copyright (c) 2015 OwlGaming Community - All Rights Reserved
* All rights reserved. This program and the accompanying materials are private property belongs to OwlGaming Community
* Unauthorized copying of this file, via any medium is strictly prohibited
* Proprietary and confidential
* ***********************************************************************************************************************
]]

local function isWorldItemObject(item)
	if not isElement(item) or getElementType(item) ~= "object" then return false end
	local itemWorld = getResourceFromName("item-world")
	local itemWorldRoot = itemWorld and getResourceRootElement(itemWorld)
	return isElement(itemWorldRoot) and getElementParent(getElementParent(item)) == itemWorldRoot
end

-- Item protection
function isProtected(player, item)
	if not isElement(item) then
		if item then
			local team = getPlayerTeam(player)
			if item[4] ~= 0 and (not exports.factions:isPlayerInFaction(player, item[4])) then
				return true
			end
			return false
		end
	else
		local protected = getElementData(item, "protected")
		if not protected or exports.factions:isPlayerInFaction(player, protected) then
			return false
		end
		return true
	end
end

function canPickup(player, item)
	if isWatchingTV(player) then
		return false
	elseif isProtected(player, item) then
		return false
	else
		if isElement(item) then
			if exports['item-world']:can(player, "pickup", item) then
				return true
			else
				return false
			end
		end
	end
	return true
end

function canMove(player, item)
	if isWatchingTV(player) then
		return false
	elseif isProtected(player, item) then
		return false
	else
		if isElement(item) then
			if exports['item-world']:can(player, "move", item) then
				return true
			else
				return false
			end
		end
	end
	return true
end

function protectItem(faction, item, slot)
	local player = client
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not exports.global:isStaffOnDuty(player) then return false end
	if not isElement(source) then return false end
	faction = tonumber(faction)
	if not faction or faction ~= math.floor(faction) or faction < -100 then return false end
	if faction > 0 and not isElement(exports.factions:getFactionFromID(faction)) then return false end

	if isWorldItemObject(source) then
		local itemID = tonumber(getElementData(source, "itemID"))
		local itemIndex = tonumber(getElementData(source, "id"))
		if not itemID or itemID == 169 or not itemIndex or itemIndex < 1 then return false end
		local currentProtection = tonumber(getElementData(source, "protected")) or 0
		local newProtection = currentProtection ~= 0 and 0 or faction
		if not mysql:query_free("UPDATE worlditems SET protected = " .. newProtection .. " WHERE id = " .. itemIndex .. " LIMIT 1") then
			outputChatBox("World item protection could not be saved.", player, 255, 0, 0)
			return false
		end
		exports.anticheat:changeProtectedElementDataEx(source, "protected", newProtection ~= 0 and newProtection or false, true)
		outputChatBox(newProtection == 0 and "Protection removed." or ("Protection set to faction " .. newProtection .. "."), player, 0, 255, 0)
		return true
	end

	local container = source
	local itemSlot = tonumber(slot)
	if not itemSlot or itemSlot < 1 or itemSlot ~= math.floor(itemSlot) then return false end
	if not loadItems(container) then return false end
	local items = getItems(container)
	local inventoryItem = type(items) == "table" and items[itemSlot] or nil
	if type(inventoryItem) ~= "table" or not tonumber(inventoryItem[3]) then return false end
	local itemID = tonumber(inventoryItem[1])
	if not itemID or itemID == 169 then return false end
	local currentProtection = tonumber(inventoryItem[4]) or 0
	local newProtection = currentProtection ~= 0 and 0 or faction
	local itemIndex = tonumber(inventoryItem[3])
	if not mysql:query_free("UPDATE items SET protected = " .. newProtection .. " WHERE `index` = " .. itemIndex .. " LIMIT 1") then
		outputChatBox("Inventory item protection could not be saved.", player, 255, 0, 0)
		return false
	end
	updateProtection(inventoryItem, newProtection, itemSlot, container)
	outputChatBox(newProtection == 0 and "Protection removed." or ("Protection set to faction " .. newProtection .. "."), player, 0, 255, 0)
	return true
end
addEvent("protectItem", true)
addEventHandler("protectItem", root, protectItem)


-- This is simply to MANAGE world items. Not to create them.
local badges = getBadges()
local masks = getMasks()

function dropItemOnDead(itemID,itemValue, x, y, z, ammo, keepammo)

end
addEvent("dropItemOnDead", true)
addEventHandler("dropItemOnDead", getRootElement(), dropItemOnDead)

disableCanDropPick = false
function toggleDropPick(player, cmd, state)
	if exports.integration:isPlayerScripter(player) then
		disableCanDropPick = not disableCanDropPick
		outputChatBox("Droppick is "..(disableCanDropPick and "Disabled." or "Enabled."), player)
	end
end
addCommandHandler("togpick" ,toggleDropPick)

function dropItem(itemID, x, y, z, ammo, keepammo, cancelAnim)
	if client and client ~= source then return false end
	if not isElement(source) or getElementType(source) ~= "player"
		or tonumber(getElementData(source, "loggedin")) ~= 1 then return false end
	itemID = tonumber(itemID)
	x, y, z = tonumber(x), tonumber(y), tonumber(z)
	if not itemID or itemID ~= math.floor(itemID)
		or not x or not y or not z
		or x ~= x or y ~= y or z ~= z
		or x == math.huge or x == -math.huge or y == math.huge or y == -math.huge or z == math.huge or z == -math.huge
		or math.abs(x) > 3000 or math.abs(y) > 3000 or z < -100 or z > 2000 then
		triggerClientEvent(source, "finishItemDrop", source)
		return false
	end
	local px, py, pz = getElementPosition(source)
	if getDistanceBetweenPoints3D(px, py, pz, x, y, z) > 5 then
		outputChatBox("You cannot drop an item that far away.", source, 255, 0, 0)
		triggerClientEvent(source, "finishItemDrop", source)
		return false
	end
	if ammo ~= nil then
		ammo = tonumber(ammo)
		keepammo = tonumber(keepammo) or 0
		local isArmorDrop = itemID == 100
		if (not isArmorDrop and (itemID < 1 or itemID > 46 or not getWeaponNameFromID(itemID)))
			or not ammo or ammo < 1 or ammo ~= math.floor(ammo)
			or keepammo < 0 or keepammo ~= math.floor(keepammo) or keepammo > 10000
			or (isArmorDrop and (keepammo ~= 0 or ammo > getPedArmor(source))) then
			triggerClientEvent(source, "finishItemDrop", source)
			return false
		end
	end
	if disableCanDropPick then
		outputChatBox("Item dropping is currently disabled. While our scripters are investigating the issue.", source, 255, 0, 0)
		triggerClientEvent( source, "finishItemDrop", source )
		return
	end

	if isWatchingTV(source) or isPedDead(source) or getElementData(source, "injuriedanimation") then
		triggerClientEvent( source, "finishItemDrop", source )
		return false
	end



	local interior = getElementInterior(source)
	local dimension = getElementDimension(source)

	local rz2 = getPedRotation(source)

	if not ammo then
		local itemSlot = itemID
		if itemSlot < 1 or itemSlot ~= math.floor(itemSlot) or not loadItems(source) then
			triggerClientEvent(source, "finishItemDrop", source)
			return false
		end
		local inventory = getItems(source)
		local selectedItem = type(inventory) == "table" and inventory[itemSlot] or nil
		if type(selectedItem) ~= "table" then
			triggerClientEvent(source, "finishItemDrop", source)
			return false
		end
		local itemID, itemValue, itemIndex, itemProtected, metadata = unpack(selectedItem)

		--ANTI ALT-ALT
		if not exports.global:isStaffOnDuty(source) then
			if ((itemID >= 31) and (itemID <= 43)) or itemBannedByAltAltChecker[itemID] then
				local hoursPlayedFrom = getElementData( source, "hoursplayed" )
				if hoursPlayedFrom < 10 then
					outputChatBox("You require 10 hours of playing time to drop a "..getItemName( itemID )..".", source, 255, 0, 0)
					triggerClientEvent( source, "finishItemDrop", source )
					return
				end
			end
		end

		local weaponBlock = false

		if itemID == 2 then
			--triggerClientEvent(source,"phone:clearAllCaches", source, itemValue)
		end

		-- armors
		if itemID == 220 or itemID == 221 or itemID == 219 or itemID == 162 then
			outputChatBox("You can not drop this item.", source, 255, 0, 0)
			triggerClientEvent( source, "finishItemDrop", source )
			return
		end

		if itemID == 223 then
			local v = split(itemValue, ":")
			if not v or not v[1] or not v[2] or not v[3] then
				outputChatBox("You broke this item! Get it spawned in properly next time.", source, 255, 0, 0)
				return
			end
		end

		if itemID == 115 or itemID == 116 then -- Weapons
			local itemCheckExplode = exports.global:explode(":", itemValue)
			local serial = itemCheckExplode[itemID==115 and 2 or 3]
			local weaponDetails = serial and exports.global:retrieveWeaponDetails( serial )
			if weaponDetails and weaponDetails[2] and tonumber(weaponDetails[2]) and tonumber(weaponDetails[2]) == 2  then -- /duty
				outputChatBox("You cannot drop your duty gun, sorry.", source, 255, 0, 0)
				weaponBlock = true
			end

			if isThisGunDuplicated(itemID, itemValue, source) then
				takeItemFromSlot( source, itemSlot )
				outputChatBox("The weapon has dropped was duplicated by bug abuser. And can not be used anymore. We're sorry to delete it now.", source, 255,0,0)
				triggerClientEvent( source, "finishItemDrop", source )
				return false
			end
		end

		if itemID == 60 or itemID == 137 or itemID == 138 or itemID == 175 and not exports.integration:isPlayerAdmin(source) then
			outputChatBox( "This item can't be dropped.", source, 255, 0, 0 )
		elseif ( itemID == 81 or itemID == 103 or itemID == 223 ) and dimension == 0 then
			outputChatBox( "You need to drop this item in an interior.", source )
		elseif (weaponBlock) then
			-- Do nothing
		elseif itemID == 139 or itemID == 262 or itemID == 263 then
			outputChatBox("This item cannot be dropped.", source, 255, 0, 0)
		else
			local keypadDoorInterior = nil
			if itemID == 48 and countItems( source, 48 ) == 1 then
				if getCarriedWeight( source ) > 10 - getItemWeight( 48, 1 ) then
					triggerClientEvent( source, "finishItemDrop", source )
					return
				end
			elseif itemID == 134 then
				if not exports.global:takeMoney(source, itemValue) then
					outputDebugString(getPlayerName(source) .. ' (' .. getPlayerSerial(source) .. ') tried dropping money he doesnt have')

					while exports['item-system']:takeItem(source, 134) do
					end

					local amount = exports.global:getMoney(source)
					if amount > 0 then
						exports.global:giveItem(source, 134, amount)
					end

					triggerClientEvent( source, "finishItemDrop", source )
					return
				end
			elseif (itemID == 147) then -- Picture Frame
				local dimension = getElementDimension(source)
				if dimension > 0 or (exports.integration:isPlayerLeadAdmin(source) and exports.global:isAdminOnDuty(source)) or exports.integration:isPlayerScripter(source) then
					local split = exports.global:explode(";", itemValue)
					local url = split[1]
					local texture = split[2]
					if url and texture then
						if exports['texture-system']:newTexture(source, url, texture) then
							takeItem ( source, 147, itemValue )
						end
						triggerClientEvent( source, "finishItemDrop", source )
						return
					end
				end
			elseif itemID == 169 then --Keypad Door Lock
				local maxRange = 10
				local doorOutside = nil
				local doorInside = nil
				local validInterior = false
				local validDropper = false
				local interiorName = "Unknown"
				local isIntLocked = true
				--check if int is existed and int is owned by dropper
				for key, interior in ipairs(getElementsByType("interior")) do
					if isElement(interior) and getElementData(interior, "dbid") == tonumber(itemValue) then
						validInterior = true
						interiorName = getElementData(interior, "name")
						local status = getElementData(interior, "status")
						isIntLocked = status.locked
						if status.owner == getElementData(source, "dbid") then
							validDropper = true
							doorOutside = getElementData(interior, "entrance")
							doorInside = getElementData(interior, "exit")
							keypadDoorInterior = interior
							break
						end
					end
				end

				if not validInterior then
					exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "The interior that this device is made for is no longer existed. Thus far this device is not usable anymore.")
					triggerClientEvent( source, "finishItemDrop", source )
					return false
				end

				if not validDropper then
					exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "Interior '"..interiorName.."' is no longer owned by you. Thus far this device is not usable anymore.")
					triggerClientEvent( source, "finishItemDrop", source )
					return false
				end

				--check if the interior is unlocked / maxime
				if isIntLocked then
					exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "Interior '"..interiorName.."' is locked, please unlock it first.")
					triggerClientEvent( source, "finishItemDrop", source )
					return false
				end

				-- Making sure the interior door is valid / maxime
				if not doorOutside or not doorInside then
					exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "Interior '"..interiorName.."' is defected, please notify scripters.")
					triggerClientEvent( source, "finishItemDrop", source )
					return false
				end

				-- check if the devide is placed outside within maxRange / maxime
				if interior == doorOutside.int and dimension == doorOutside.dim then
					if getDistanceBetweenPoints3D(x,y,z, doorOutside.x, doorOutside.y, doorOutside.z) > maxRange then
						exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "This device can only be installed within "..math.floor(maxRange/2).." meters from its out-door.")
						triggerClientEvent( source, "finishItemDrop", source )
						return false
					end
				-- check if the devide is placed inside within maxRange / maxime
				elseif interior == doorInside.int and dimension == tonumber(itemValue) then
					if getDistanceBetweenPoints3D(x,y,z,doorInside.x, doorInside.y, doorInside.z) > maxRange then
						exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "This device can only be installed within "..math.floor(maxRange/2).." meters from its in-door.")
						triggerClientEvent( source, "finishItemDrop", source )
						return false
					end
				else
					exports.hud:sendBottomNotification(source, getItemName( itemID, itemValue ), "This device can only be installed within "..math.floor(maxRange/2).." meters from its door.")
					triggerClientEvent( source, "finishItemDrop", source )
					return false
				end
			end

			--Restrict textured items in exterior world. /Exciter 2016-06-27
			if getItemTexture(itemID, itemValue, metadata) then --if item is textured
				local dimension = getElementDimension(source)
				local exceptions = { --items allowed to be dropped in exterior even if textured.
					--[itemID] = true, --item name
				}
				if dimension ~= 0 or exceptions[itemID] or (exports.integration:isPlayerSupporter(source) and exports.global:isStaffOnDuty(source)) or (exports.integration:isPlayerTrialAdmin(source) and exports.global:isStaffOnDuty(source)) or exports.integration:isPlayerScripter(source) then
					--TODO: filesize check.
					--all good
				else
					exports.hud:sendBottomNotification(source, getItemName(itemID, itemValue, metadata), "Only supporters and admins may drop textured items in the exterior world. Use it in your interior instead.")
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end
			end

			local insert = mysql:query("INSERT INTO worlditems SET itemid='" .. itemID .. "', itemvalue='" .. mysql:escape_string( itemValue) .. "', creationdate = NOW(), x = " .. x .. ", y = " .. y .. ", z= " .. z .. ", dimension = " .. dimension .. ", interior = " .. interior .. ", rz = " .. rz2 .. ", creator=" .. getElementData(source, "dbid") .. ", metadata = " .. (metadata and ("'" .. mysql:escape_string(toJSON(metadata)) .. "'") or "NULL"))
			if insert then
				local id = mysql:insert_id()
				mysql:free_result(insert)

				-- Animation
				if (not cancelAnim) then
					exports.global:applyAnimation(source, "CARRY", "putdwn", 500, false, false, true)
				end

				if getPedOccupiedVehicle(source) then
					if getElementModel(getPedOccupiedVehicle(source)) == 490 then
					end
				else
					toggleAllControls( source, true, true, true )
				end

				-- Create Object
				local modelid = getItemModel(tonumber(itemID), itemValue, metadata)

				if (itemID==178) then
					local yup = split(itemValue, ":")
					name = ("book titled ".. yup[1].." by ".. yup[2])
				end

				if itemID == 134 then
					outputChatBox("You dropped $" .. exports.global:formatMoney(itemValue) .. ".", source, 255, 194, 14)
				elseif (not cancelAnim) then
					outputChatBox("You dropped a " .. getItemName( itemID, itemValue, metadata ) .. ".", source, 255, 194, 14)
				end


				local rx, ry, rz, zoffset = getItemRotInfo(itemID, itemValue)
				local obj = exports["item-world"]:createItem(id, itemID, itemValue, modelid, x, y, z + zoffset - 0.05, rx, ry, rz + rz2)
				if not isElement(obj) then
					mysql:query_free("DELETE FROM worlditems WHERE id = " .. tonumber(id) .. " LIMIT 1")
					if itemID == 134 then exports.global:giveMoney(source, tonumber(itemValue)) end
					outputChatBox("The world item could not be created. Your item was returned.", source, 255, 0, 0)
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end
				exports.pool:allocateElement(obj)

				setElementInterior(obj, interior)
				setElementDimension(obj, dimension)

				if (itemID==76) then
					moveObject(obj, 200, x, y, z + zoffset, 90, 0, 0)
				else
					moveObject(obj, 200, x, y, z + zoffset)
				end

				local objScale = getItemScale(tonumber(itemID), itemValue, metadata)
				if objScale then
					setObjectScale(obj, objScale)
				end
				local objDoubleSided = getItemDoubleSided(tonumber(itemID), itemValue)
				if objDoubleSided then
					setElementDoubleSided(obj, objDoubleSided)
				end
				local objTexture = getItemTexture(tonumber(itemID), itemValue, metadata)
				if objTexture then
					for objTexKey, objTexVal in ipairs(objTexture) do
						exports['item-texture']:addTexture(obj, objTexVal[2], objTexVal[1])
					end
				end

				exports.anticheat:changeProtectedElementDataEx(obj, "creator", getElementData(source, "dbid"), false)
				exports.anticheat:changeProtectedElementDataEx(obj, "createdTimestamp", exports.datetime:now(), false)

				local permissions = { use = 1, move = 1, pickup = 1, useData = {}, moveData = {}, pickupData = {} }
				exports.anticheat:changeProtectedElementDataEx(obj, "worlditem.permissions", permissions)

				exports.anticheat:changeProtectedElementDataEx(obj, "metadata", metadata)

				-- Remove the source item only after the world object exists.
				if itemID ~= 134 and not takeItemFromSlot(source, itemSlot) then
					mysql:query_free("DELETE FROM worlditems WHERE id = " .. tonumber(id) .. " LIMIT 1")
					destroyElement(obj)
					outputChatBox("The item could not be removed from your inventory; the drop was cancelled.", source, 255, 0, 0)
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end

				exports.logs:dbLog(source, 39, source, getPlayerName(source) .. " -> ~World #" .. getElementID(obj) .. " - " .. getItemName( itemID, itemValue, metadata ) .. " - " .. itemValue .. " @ ("..x..", "..y..", "..z..") in (int "..interior..", dim "..dimension..")" )
				doItemGiveawayChecks(source, itemID, itemValue)

				--misc post-spawn itemID conditionals
				if itemID == 166 then --video player
					--local dimensionPlayers = {}
					for key, value in ipairs(getElementsByType("player")) do
						if getElementDimension(value)==getElementDimension(obj) then
							--table.insert(dimensionPlayers,value)
							triggerEvent("fakevideo:loadDimension", value)
						end
					end
					--triggerClientEvent(dimensionPlayers, "fakevideo:addOne", source, 2, itemValue, nil, "clubtec_load.png")
				end

				if itemID == 169 then --Keypad Door Lock / maxime
					triggerEvent("installKeypad", source, obj, keypadDoorInterior)
				end

				--SEND ME FOR WHAT HAS BEEN DROPPED
				if itemID == 134 then
					triggerEvent('sendAme', source, "dropped $" .. exports.global:formatMoney(itemValue) .. ".")
				elseif (itemID==178) and tostring(itemValue):find( ":" ) then
					triggerEvent('sendAme', source, "dropped a " .. name .. ".")
				elseif (not cancelAnim) then
					triggerEvent('sendAme', source, "dropped a " .. getItemName( itemID, itemValue, metadata ) .. ".")
				end
			else
				if itemID == 134 and not exports.global:giveMoney(source, tonumber(itemValue)) then
					outputDebugString("[item-system] Failed to refund cash after world item insert failure for " .. getPlayerName(source), 1)
					outputChatBox("The cash drop failed and the refund could not be completed. Contact staff.", source, 255, 0, 0)
				else
					outputChatBox("The item could not be dropped. Please try again.", source, 255, 0, 0)
				end
				triggerClientEvent(source, "finishItemDrop", source)
			end
		end
	else
		if tonumber(getElementData(source, "duty")) > 0 then
			outputChatBox("You can't drop your weapons while being on duty.", source, 255, 0, 0)
		elseif tonumber(getElementData(source, "job")) == 4 and itemID == 41 then
			outputChatBox("You can't drop this spray can.", source, 255, 0, 0)
		else


			if ammo <= 0 then
				triggerClientEvent( source, "finishItemDrop", source )
				return
			end

			outputChatBox("You dropped a " .. ( getWeaponNameFromID( itemID ) or "Body Armor" ) .. ".", source, 255, 194, 14)

			-- Animation
			exports.global:applyAnimation(source, "CARRY", "putdwn", 500, false, false, true)

			if getPedOccupiedVehicle(source) then
				if getElementModel(getPedOccupiedVehicle(source)) == 490 then
				end
			else
				toggleAllControls( source, true, true, true )
			end

			if itemID == 100 then
				z = z + 0.1
			end

			local weaponSlot
			local previousAmmo
			if itemID == 100 then
				previousAmmo = getPedArmor(source)
			else
				weaponSlot = getSlotFromWeapon(itemID)
				if not weaponSlot or weaponSlot < 1 then
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end
				previousAmmo = getPedTotalAmmo(source, weaponSlot)
			end
			if not previousAmmo or ammo + keepammo > previousAmmo then
				outputChatBox("You do not have that amount of ammunition to drop.", source, 255, 0, 0)
				triggerClientEvent(source, "finishItemDrop", source)
				return false
			end

			local query = mysql:query("INSERT INTO worlditems SET itemid=" .. -itemID .. ", itemvalue=" .. ammo .. ", creationdate=NOW(), x=" .. x .. ", y=" .. y .. ", z=" .. (z + 0.1) .. ", dimension=" .. dimension .. ", interior=" .. interior .. ", rz=" .. rz2 .. ", creator=" .. tonumber(getElementData(source, "dbid")) .. ", metadata=" .. (metadata and ("'" .. mysql:escape_string(toJSON(metadata)) .. "'") or "NULL"))
			if not query then
				outputChatBox("The weapon could not be dropped. Your weapon was not changed.", source, 255, 0, 0)
				triggerClientEvent(source, "finishItemDrop", source)
				return false
			end

			local id = mysql:insert_id()
			mysql:free_result(query)
			local modelid = itemID == 100 and 1242 or (itemID == 42 and 2690 or weaponmodels[itemID])
			local obj = exports["item-world"]:createItem(id, -itemID, ammo, modelid, x, y, z - 0.4, 75, -10, rz2)
			if not isElement(obj) then
				mysql:query_free("DELETE FROM worlditems WHERE id = " .. tonumber(id) .. " LIMIT 1")
				outputChatBox("The world object could not be created. Your weapon was not changed.", source, 255, 0, 0)
				triggerClientEvent(source, "finishItemDrop", source)
				return false
			end

			if itemID == 100 then
				setPedArmor(source, 0)
			else
				if not takeWeapon(source, itemID) then
					mysql:query_free("DELETE FROM worlditems WHERE id = " .. tonumber(id) .. " LIMIT 1")
					destroyElement(obj)
					outputChatBox("The weapon could not be removed from your hands. The drop was cancelled.", source, 255, 0, 0)
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end
				if keepammo > 0 and not giveWeapon(source, itemID, keepammo, true) then
					local restored = giveWeapon(source, itemID, previousAmmo, true)
					mysql:query_free("DELETE FROM worlditems WHERE id = " .. tonumber(id) .. " LIMIT 1")
					destroyElement(obj)
					if not restored then
						outputDebugString("[item-system] Failed to restore dropped weapon " .. itemID .. " for " .. getPlayerName(source), 1)
						outputChatBox("Weapon rollback failed. Contact staff immediately.", source, 255, 0, 0)
					else
						outputChatBox("The weapon could not be stored on the ground; your original weapon was restored.", source, 255, 0, 0)
					end
					triggerClientEvent(source, "finishItemDrop", source)
					return false
				end
			end

			setElementInterior(obj, interior)
			setElementDimension(obj, dimension)
			moveObject(obj, 200, x, y, z + 0.1)
			exports.anticheat:changeProtectedElementDataEx(obj, "creator", getElementData(source, "dbid"), false)
			exports.anticheat:changeProtectedElementDataEx(obj, "metadata", metadata)
			exports.logs:dbLog(source, 39, source, getPlayerName(source) .. " -> ~World #" .. getElementID(obj) .. " - " .. getItemName(-itemID) .. " - " .. ammo .. " @ (" .. x .. ", " .. y .. ", " .. z .. ") in (int " .. interior .. ", dim " .. dimension .. ")")
			triggerEvent("sendAme", source, "drops a " .. (getWeaponNameFromID(itemID) or "Body Armor") .. ".")
			if isElement(obj) then
				triggerClientEvent(source, "saveGuns", source, getPlayerName(source))
			end
		end
	end

	triggerClientEvent( source, "finishItemDrop", source )
end
addEvent("dropItem", true)
addEventHandler("dropItem", getRootElement(), dropItem)

function doItemGiveawayChecks(player, itemID, itemValue)
	local source = player
	local mask = masks[itemID]
	if mask and getElementData(source, mask[1]) and not hasItem(source, itemID) then
		triggerEvent('sendAme', source, mask[3] .. ".")
		exports.anticheat:changeProtectedElementDataEx(source, mask[1])
	end
	if itemID == 270 and getElementData(source, "gloves") and not hasItem(source, itemID) then
		triggerEvent('sendAme', source, "slips a pair of gloves from their hands.")
		exports.anticheat:changeProtectedElementDataEx(source, "gloves", false, true)
	end

	--Cellphone
	if itemID == 2 then
		triggerClientEvent(source,"phone:clearAllCaches", source, itemValue)
	end

	-- Clothes
	local requiredClothesValue = getElementModel(source) .. (getElementData(source, 'clothing:id') and (':' .. getElementData(source, 'clothing:id')) or '')
	if itemID == 16 and not hasItem(source, 16, tonumber(requiredClothesValue) or requiredClothesValue) then
	--if itemID == 16 and not hasItem(source, 16, getPedSkin(source)) then
		local gender = getElementData(source,"gender")
		local race = getElementData(source,"race")
		local result = mysql:query_fetch_assoc("SELECT skincolor, gender FROM characters WHERE id='" .. getElementData(source, "dbid") .. "' LIMIT 1")
		local skincolor = tonumber(result["skincolor"])
		local gender = tonumber(result["gender"])

		if (gender==0) then -- MALE
			if (skincolor==0) then -- BLACK
				setElementModel(source, 80)
			elseif (skincolor==1 or skincolor==2) then -- WHITE
				setElementModel(source, 252)
			end
		elseif (gender==1) then -- FEMALE
			if (skincolor==0) then -- BLACK
				setElementModel(source, 139)
			elseif (skincolor==1) then -- WHITE
				setElementModel(source, 138)
			elseif (skincolor==2) then -- ASIAN
				setElementModel(source, 140)
			end
		end
		--exports.mysql:query_free( "UPDATE characters SET skin = '" .. exports.mysql:escape_string(getElementModel(source)) .. "' WHERE id = '" .. exports.mysql:escape_string(getElementData( source, "dbid" )).."'" )
		exports.anticheat:changeProtectedElementDataEx(source, 'clothing:id', nil, true)
		exports.mysql:query_free( "UPDATE characters SET skin = '" .. exports.mysql:escape_string(getElementModel(source)) .. "', clothingid = NULL WHERE id = '" .. exports.mysql:escape_string(getElementData( source, "dbid" )).."'" )
	end

	-- Badges
	local badge = badges[itemID]
	if badge and getElementData(source, badge[1]) and not hasItem(source, itemID, removeOOC(getElementData(source, badge[1]))) then
		triggerEvent('sendAme', source, "removes a " .. badge[2] .. ".")
		exports.anticheat:changeProtectedElementDataEx(source, badge[1])
		exports.global:updateNametagColor(source)
	end

	-- Riot Shield
	if itemID == 76 and shields[source] and not hasItem(source, 76) then
		destroyElement(shields[source])
		shields[source] = nil
	end

	-- MP3-player
	if itemID == 19 and not hasItem(source, itemID) then
		triggerClientEvent(source, "realism:mp3:off", source)
	end

	if itemID == 77 and not hasItem(source, 77, itemValue) then
		triggerEvent("cards:leave_session_if_host", source, itemValue)
	end

	if itemID == 90 then -- Helmet
		triggerEvent("artifacts:remove", source, source, "helmet")
	elseif itemID == 26 then -- Gas mask
		triggerEvent("artifacts:remove", source, source, "gasmask")
	elseif itemID == 160 then -- briefcase
		triggerEvent("artifacts:remove", source, source, "briefcase")
	elseif itemID == 48 then --backpack
		triggerEvent("artifacts:remove", source, source, "backpack")
	elseif itemID == 145 then --flashlight
		triggerClientEvent( source, 'flashlight:toggleFlashLight', source, false )
	elseif itemID == 162 then --body armour
		triggerEvent("artifacts:remove", source, source, "kevlar")
	elseif itemID == 163 then --duffle bag
		triggerEvent("artifacts:remove", source, source, "dufflebag")
	elseif itemID == 164 then --medical bag
		triggerEvent("artifacts:remove", source, source, "medicbag")
	elseif itemID == 111 then
		triggerClientEvent(source, "item:updateclient", source)
	elseif itemID == 171 then -- Biker Helmet
		triggerEvent("artifacts:remove", source, source, "bikerhelmet")
	elseif itemID == 172 then -- Full Face Helmet
		triggerEvent("artifacts:remove", source, source, "fullfacehelmet")
	elseif itemID == 240 then --christmas hat
		triggerEvent("artifacts:remove", source, source, "christmashat")
	elseif itemID == 268 then --surfboard
		triggerEvent("artifacts:remove", source, source, "surfboard")
		triggerEvent("activities:surf:unlaunchSurfboard", source, source)
	end
end

function doItemGivenChecks(player, itemID, itemValue)
	if itemID == 2 then --cellphone
		triggerClientEvent(player,"phone:clearAllCaches", player, itemValue)
	elseif itemID == 48 then --backpack
		triggerEvent("artifacts:add", player, player, "backpack")
	elseif itemID == 162 then --body armour
		triggerEvent("artifacts:add", player, player, "kevlar")
	elseif itemID == 163 then --duffle bag
		triggerEvent("artifacts:add", player, player, "dufflebag")
	elseif itemID == 164 then --medical bag
		triggerEvent("artifacts:add", player, player, "medicbag")
	elseif itemID == 111 then
		setPlayerHudComponentVisible( player, 'radar', true )
	elseif itemID == 268 then --surfboard
		triggerEvent("artifacts:add", player, player, "surfboard")
	end
end

local function moveItem(item, x, y, z)
	local player = client or source
	if client and source ~= client then return false end
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not isWorldItemObject(item) then return false end

	local itemID = tonumber(getElementData(item, "itemID"))
	local itemIndex = tonumber(getElementData(item, "id"))
	if not itemID or itemID ~= math.floor(itemID) or not itemIndex or itemIndex < 1 then return false end
	if isWatchingTV(player) or isPedDead(player) or getElementData(player, "injuriedanimation") then return false end
	if itemID == 169 then return false end
	if not exports.global:isStaffOnDuty(player)
		and ((itemID >= 31 and itemID <= 43) or itemBannedByAltAltChecker[itemID]) then
		outputChatBox(getItemName(itemID) .. " can't be moved this way.", player, 255, 0, 0)
		return false
	end
	if not canMove(player, item) then
		outputChatBox("You can not move this item. Contact an admin via F1.", player, 255, 0, 0)
		return false
	end
	if not z then
		if not exports.integration:isPlayerTrialAdmin(player) then return false end
		if not mysql:query_free("DELETE FROM worlditems WHERE id = " .. itemIndex .. " LIMIT 1") then return false end
		destroyElement(item)
		return true
	end

	x, y, z = tonumber(x), tonumber(y), tonumber(z)
	if not x or not y or not z or x ~= x or y ~= y or z ~= z
		or x == math.huge or x == -math.huge or y == math.huge or y == -math.huge or z == math.huge or z == -math.huge
		or math.abs(x) > 3000 or math.abs(y) > 3000 or z < -100 or z > 2000 then return false end
	if not exports.integration:isPlayerTrialAdmin(player) and (itemID == 81 or itemID == 103) then return false end
	if itemID == 138 and not exports.integration:isPlayerAdmin(player) then
		outputChatBox("Only a Lead+ admin can move this item.", player, 255, 0, 0)
		return false
	end
	if itemID == 139 and not exports.integration:isPlayerTrialAdmin(player) then
		outputChatBox("Only a Super+ admin can move this item.", player, 255, 0, 0)
		return false
	end

	local oldx, oldy, oldz = getElementPosition(item)
	for _, nearbyPlayer in ipairs(getElementsByType("player")) do
		if getPedContactElement(nearbyPlayer) == item then return false end
		local px, py, pz = getElementPosition(nearbyPlayer)
		if getDistanceBetweenPoints3D(oldx, oldy, oldz, px, py, pz) < 1 then
			outputChatBox("Someone is trying to move the item you are standing on. Move out of the way.", nearbyPlayer, 255, 0, 0)
			return false
		end
	end

	if not mysql:query_free("UPDATE worlditems SET x = " .. x .. ", y = " .. y .. ", z = " .. z .. " WHERE id = " .. itemIndex) then
		return false
	end
	if itemID > 0 then
		local rx, ry, rz, zoffset = getItemRotInfo(itemID)
		z = z + zoffset
	elseif itemID == 100 then
		z = z + 0.1
	end
	setElementPosition(item, x, y, z)
	return true
end
addEvent("moveItem", true)
addEventHandler("moveItem", getRootElement(), moveItem)

addEvent('item:move:save', true)
addEventHandler('item:move:save', root,
	function(x, y, z, rx, ry, rz)
		local reset = function()
			setElementPosition(source, getElementPosition(source))
			setElementRotation(source, getElementRotation(source))
		end
		--get int and dim from object
		local dimension = getElementDimension(source)
		local interior = getElementInterior(source)
		--old method: if (exports.global:isStaffOnDuty(client) or exports.integration:isPlayerTrialAdmin(client) or exports.integration:isPlayerScripter(client)) or (getElementDimension(client) ~= 0 and hasItem(client, 4, getElementDimension(client)) or hasItem(client, 5, getElementDimension(client))) then
		if (dimension < 20000 and interior > 0 and hasItem(client, 4, dimension)) or (dimension < 20000 and interior > 0 and hasItem(client, 5, dimension)) or (dimension > 20000 and interior > 0 and hasItem(client, 3, dimension-20000)) or (exports.integration:isPlayerTrialAdmin(client) and exports.global:isAdminOnDuty(client)) or (exports.integration:isPlayerScripter(client) and exports.global:isStaffOnDuty(client)) or (dimension == 0) or (interior == 0) then
			if not canMove(client, source) then
				outputChatBox("You can not move this item. Contact an admin via F1.", client, 255, 0, 0)
				reset()
				return
			end

			local itemID = getElementData(source, "itemID")
			if itemID == 138 and not exports.integration:isPlayerAdmin(client) then
				outputChatBox("Only a Lead+ admin can move this item.", client, 255, 0, 0)
				reset()
				return
			end

			if itemID == 139 and not exports.integration:isPlayerTrialAdmin(client) then
				outputChatBox("Only a Super+ admin can move this item.", client, 255, 0, 0)
				reset()
				return
			end


			if mysql:query_free("UPDATE worlditems SET x = " .. x .. ", y = " .. y .. ", z = " .. z .. ", rx = " .. rx .. ", ry = " .. ry .. ", rz = " .. rz .. ", useExactValues = 1 WHERE id = " .. getElementData( source, "id" ) ) then
				setElementPosition(source, x, y, z)
				setElementData(source, "useExactValues", true)
				setElementRotation(source, rx, ry, rz)

				outputChatBox('Saved item position for item #' .. getElementData( source, 'id' ) .. '.', client, 0, 255, 0)
			end
		else
			reset()
		end
	end)

local function rotateItem(item, rz)
	local player = client or source
	if client and source ~= client then return false end
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not exports.integration:isPlayerTrialAdmin(player)
		or not isWorldItemObject(item) then return false end
	local itemIndex = tonumber(getElementData(item, "id"))
	if not itemIndex or itemIndex < 1 then return false end
	if not rz then
		if not mysql:query_free("DELETE FROM worlditems WHERE id = " .. itemIndex .. " LIMIT 1") then return false end
		destroyElement(item)
		return true
	end
	rz = tonumber(rz)
	if not rz or rz ~= rz or rz == math.huge or rz == -math.huge or math.abs(rz) > 360 then return false end
	local rx, ry, currentRZ = getElementRotation(item)
	local newRZ = rz + currentRZ
	if not mysql:query_free("UPDATE worlditems SET rz = " .. newRZ .. " WHERE id = " .. itemIndex) then return false end
	setElementRotation(item, rx, ry, newRZ)
	return true
end
addEvent("rotateItem", true)
addEventHandler("rotateItem", getRootElement(), rotateItem)

function pickupItem(object, leftammo)
	if client and client ~= source then return false end
	if not isElement(source) or getElementType(source) ~= "player"
		or tonumber(getElementData(source, "loggedin")) ~= 1
		or not isWorldItemObject(object) then return false end
	if disableCanDropPick then
		outputChatBox("Item picking up is currently disabled. While our scripters are investigating the issue.", source, 255, 0, 0)
		return outputDebugString("[ITEM] pickupItem / disabled ")
	end

	if not isElement(object) then
		return outputDebugString("[ITEM] pickupItem / item is not an object.")
	end

	local x, y, z = getElementPosition(source)
	local ox, oy, oz = getElementPosition(object)
	if getElementDimension(source) ~= getElementDimension(object)
		or getElementInterior(source) ~= getElementInterior(object)
		or getDistanceBetweenPoints3D(x, y, z, ox, oy, oz) >= 10 then
		outputDebugString("Distance between Player and Pickup too large")
		return false
	end

	if getElementData(object, "transfering") then
		return outputDebugString("[ITEM] pickupItem / canceled / item is being transferred.")
	end
	--outputDebugString("[ITEM] pickupItem / Running ")
	exports.anticheat:setEld(object, "transfering", true, 'all')
	--if true then return end

	-- Animation

	local id = tonumber(getElementData(object, "id"))
	if not id or id < 1 or id ~= math.floor(id) then
		outputChatBox("Error: Invalid world item ID. Notify a scripter.", source, 255, 0, 0)
		exports.anticheat:setEld(object, "transfering", nil, "all")
		return false
	end

	local itemID = tonumber(getElementData(object, "itemID"))
	if not itemID or itemID ~= math.floor(itemID) then exports.anticheat:setEld(object, "transfering", nil, "all"); return false end
	if not canPickup(source, object) then
		outputChatBox("You can not pick up this item. Contact an admin via F1.", source, 255, 0, 0)
		exports.anticheat:setEld(object, "transfering", nil, 'all')
		return
	end
	local itemValue = getElementData(object, "itemValue") or 1
	local metadata = getElementData(object, "metadata") or nil

	--ANTI ALT-ALT
	if ((itemID >= 31) and itemID <= 43) or itemBannedByAltAltChecker[itemID] then
		local hoursPlayedTo = getElementData( source, "hoursplayed" )
		if hoursPlayedTo and hoursPlayedTo < 10 and not exports.global:isStaffOnDuty(source) then
			outputChatBox("You require 10 hours of playing time to pick up a "..getItemName( itemID )..".", source, 255, 0, 0)
			exports.anticheat:setEld(object, "transfering", nil, 'all')
			return false
		end
		local creator = getElementData(object, "creator") or 0
		local picker = getElementData(source, "dbid")
		if creator ~= picker then
			local accountCreator = exports.cache:getAccountFromCharacterId(creator)
			if accountCreator and tonumber(accountCreator.id) == tonumber(getElementData(source, "account:id")) then
				outputChatBox("Transferring assets between characters in the same account or multiple accounts own by a player is strictly prohibited! ", source, 255, 0, 0)
				exports.global:sendMessageToAdmins("[ANTI-ALT->ALT]: Detected illegal assets transferring on account name '"..getElementData(source, "account:username").."'.")
				exports.global:sendMessageToAdmins("[ANTI-ALT->ALT]: Suspect is trying to transfer a "..getItemName( itemID ).." between alternatives.")
				exports.logs:dbLog(source, 5, {object}, "TRIED TO ALT-ALT " .. getItemName( itemID ) .. " between alternatives.")
				exports.anticheat:setEld(object, "transfering", nil, 'all')
				return false
			end
		end
	end

	if itemID == 115 or itemID == 116 then
		if isThisGunDuplicated(itemID, itemValue, source) then
			destroyElement(object)
			mysql:query_free("DELETE FROM worlditems WHERE id='" .. id .. "'")
			outputChatBox("The weapon you tried to pick up was duplicated by bug abuser and can not be used anymore. We're sorry to delete it now.", source, 255,0,0)
			return false
		end

		-- now check if it's duty weapon or bought from ammunation and if player is authorized
		local can, why = exports.weapon:canRetrieve(source, itemID, itemValue)
		if not can then
			outputChatBox(why, source, 255,0,0)
			if getElementData(object, 'transfering') then
				exports.anticheat:setEld(object, "transfering", false, 'all')
			end
			return false
		end
	end

	if itemID == 138 then
		if not exports.integration:isPlayerAdmin(source) then
			outputChatBox("Only a full admin can pickup this item.", source, 255, 0, 0)
			exports.anticheat:setEld(object, "transfering", nil, 'all')
			return false
		end
	end

	if itemID == 139 and not exports.integration:isPlayerTrialAdmin(source) then
		outputChatBox("Only admin can pickup this item.", source, 255, 0, 0)
		exports.anticheat:setEld(object, "transfering", nil, 'all')
		return false
	end

	if itemID == 223 or itemID == 103 then
		if not SpecialclearItems(object) then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
	end

	exports.global:applyAnimation(source, "CARRY", "liftup", 600, false, true, true)
	local grantedItem, creditedCash = false, false
	if itemID > 0 then
		if not loadItems(object) then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		local contents = getItems(object)
		if type(contents) ~= "table" then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		while #contents > 0 do
			local moved, moveError = exports["item-system"]:moveItem(object, source, 1)
			if not moved then
				outputChatBox("Some contents could not be transferred. The world container remains available.", source, 255, 0, 0)
				outputDebugString("[item-system] World-container transfer stopped: " .. tostring(moveError), 2)
				exports.anticheat:setEld(object, "transfering", nil, "all")
				triggerClientEvent(source, "finishItemMove", source)
				return false
			end
			if not loadItems(object) then
				exports.anticheat:setEld(object, "transfering", nil, "all")
				return false
			end
			contents = getItems(object)
			if type(contents) ~= "table" then
				exports.anticheat:setEld(object, "transfering", nil, "all")
				return false
			end
		end

		if itemID == 134 then
			local amount = tonumber(itemValue)
			if not amount or amount <= 0 or amount ~= amount or amount == math.huge or amount ~= math.floor(amount)
				or not exports.global:giveMoney(source, amount) then
				exports.anticheat:setEld(object, "transfering", nil, "all")
				return false
			end
			creditedCash = true
		else
			if not giveItem(source, itemID, itemValue, false, false, metadata) then
				outputChatBox("Your inventory cannot receive this item. The world item remains available.", source, 255, 0, 0)
				exports.anticheat:setEld(object, "transfering", nil, "all")
				return false
			end
			grantedItem = true
		end

		if not mysql:query_free("DELETE FROM worlditems WHERE id = " .. id .. " LIMIT 1") then
			if creditedCash then
				if not exports.global:takeMoney(source, tonumber(itemValue)) then
					outputDebugString("[item-system] Failed to reverse cash credit after world-item delete failure #" .. id, 1)
				end
			elseif grantedItem then
				if not takeItem(source, itemID, itemValue) then
					outputDebugString("[item-system] Failed to reverse inventory grant after world-item delete failure #" .. id, 1)
				end
			end
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
	elseif itemID == -100 then
		local armorAmount = tonumber(itemValue)
		if not armorAmount or armorAmount <= 0 or armorAmount ~= armorAmount or armorAmount == math.huge then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		local oldArmor = getPedArmor(source)
		if not mysql:query_free("DELETE FROM worlditems WHERE id = " .. id .. " LIMIT 1") then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		setPedArmor(source, math.min(100, math.max(oldArmor, armorAmount)))
	else
		local weaponID = -itemID
		local ammoAmount = tonumber(itemValue)
		local leftAmount = tonumber(leftammo)
		if weaponID < 1 or weaponID > 46 or not getWeaponNameFromID(weaponID)
			or not ammoAmount or ammoAmount < 1 or ammoAmount ~= math.floor(ammoAmount) then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		local giveAmount = ammoAmount
		local remainingAmount = 0
		if leftAmount and leftAmount > 0 and leftAmount < ammoAmount then
			giveAmount = leftAmount
			remainingAmount = ammoAmount - leftAmount
		end
		local weaponSlot = getSlotFromWeapon(weaponID)
		if not weaponSlot or weaponSlot < 1 then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		local previousWeapon = getPedWeapon(source, weaponSlot)
		local previousTotal = tonumber(getPedTotalAmmo(source, weaponSlot)) or 0
		local previousClip = tonumber(getPedAmmoInClip(source, weaponSlot)) or 0
		if not giveWeapon(source, weaponID, giveAmount, true) then
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
		local querySucceeded
		if remainingAmount > 0 then
			querySucceeded = mysql:query_free("UPDATE worlditems SET itemvalue = " .. remainingAmount .. " WHERE id = " .. id)
			if querySucceeded then
				exports.anticheat:changeProtectedElementDataEx(object, "itemValue", remainingAmount, false)
			end
		else
			querySucceeded = mysql:query_free("DELETE FROM worlditems WHERE id = " .. id .. " LIMIT 1")
		end
		if not querySucceeded then
			local currentWeapon = getPedWeapon(source, weaponSlot)
			local restored = true
			if previousWeapon and previousWeapon ~= 0 then
				if currentWeapon ~= previousWeapon and currentWeapon and currentWeapon ~= 0 then
					restored = takeWeapon(source, currentWeapon) and restored
				end
				if getPedWeapon(source, weaponSlot) ~= previousWeapon then
					restored = giveWeapon(source, previousWeapon, previousTotal, true) and restored
				end
				if getPedWeapon(source, weaponSlot) == previousWeapon then
					restored = setWeaponAmmo(source, previousWeapon, previousTotal, previousClip) and restored
				end
			else
				if currentWeapon and currentWeapon ~= 0 then
					restored = takeWeapon(source, currentWeapon)
				end
			end
			if not restored then
				outputDebugString("[item-system] Failed to restore weapon slot after world-item update failure #" .. id .. " for " .. getPlayerName(source), 1)
				outputChatBox("Weapon rollback failed. Contact staff immediately.", source, 255, 0, 0)
			end
			exports.anticheat:setEld(object, "transfering", nil, "all")
			return false
		end
	end

	exports.logs:dbLog(source, 39, {object}, "~World #" .. getElementID(object) .. " @ (" .. ox .. ", " .. oy .. ", " .. oz .. ") in (int " .. getElementInterior(object) .. ", dim " .. getElementDimension(object) .. ") -> " .. getPlayerName(source) .. " - " .. getItemName(itemID) .. " - " .. tostring(itemValue))
	destroyElement(object)

	if itemID == 134 then
		outputChatBox("You picked up $" .. exports.global:formatMoney(itemValue) .. ".", source, 255, 194, 14)
		triggerEvent("sendAme", source, "bends over and picks up $" .. exports.global:formatMoney(itemValue) .. ".")
	elseif itemID == -100 then
		outputChatBox("You picked up body armor.", source, 255, 194, 14)
	else
		outputChatBox("You picked up a " .. getItemName(itemID, itemValue, metadata) .. ".", source, 255, 194, 14)
		triggerEvent("sendAme", source, "bends over and picks up a " .. getItemName(itemID, itemValue, metadata) .. ".")
	end
	doItemGivenChecks(source, itemID, itemValue)
	triggerClientEvent(source, "item:updateclient", source)

end
addEvent("pickupItem", true)
addEventHandler("pickupItem", getRootElement(), pickupItem)

function removeItemTransferingState()
	for i, object in pairs(exports.pool:getPoolElementsByType("object")) do
		exports.anticheat:setEld(object, "transfering", nil, 'all')
	end
end
addEventHandler("onResourceStop", resourceRoot, removeItemTransferingState)
