function addUpgrade(player, vehicle, itemSlot, itemID, itemValue)
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not isElement(vehicle) or getElementType(vehicle) ~= "vehicle"
		or getPedOccupiedVehicle(player) ~= vehicle then
		return false
	end

	itemSlot = tonumber(itemSlot)
	itemID = tonumber(itemID)
	local upgradeID = tonumber(itemValue)
	if not itemSlot or itemSlot < 1 or itemSlot ~= math.floor(itemSlot)
		or itemID ~= 114 or not upgradeID or upgradeID < 1000 or upgradeID > 1193
		or upgradeID ~= math.floor(upgradeID) or not getVehicleUpgradeSlotName(upgradeID) then
		return false
	end
	local loaded = loadItems(player)
	if not loaded then
		outputChatBox("Your inventory could not be loaded. Please try again.", player, 255, 0, 0)
		return false
	end
	local inventory = getItems(player)
	local selectedItem = type(inventory) == "table" and inventory[itemSlot] or nil
	if type(selectedItem) ~= "table" or tonumber(selectedItem[1]) ~= itemID
		or tonumber(selectedItem[2]) ~= upgradeID then
		outputChatBox("That upgrade is no longer in the selected slot.", player, 255, 0, 0)
		return false
	end

	local noUpgrades = { Boat = true, Helicopter = true, Plane = true, Train = true, BMX = true }
	if noUpgrades[getVehicleType(vehicle)] then
		outputChatBox("This vehicle type cannot use upgrades.", player, 255, 0, 0)
		return false
	end
	if (tonumber(getElementData(vehicle, "job")) or 0) ~= 0
		or tonumber(getElementData(vehicle, "owner")) == -2 then
		outputChatBox("You can't install upgrades to this vehicle.", player, 255, 0, 0)
		return false
	end

	local compatible = getVehicleCompatibleUpgrades(vehicle)
	local isCompatible = false
	for _, compatibleUpgrade in ipairs(compatible or {}) do
		if tonumber(compatibleUpgrade) == upgradeID then
			isCompatible = true
			break
		end
	end
	if not isCompatible then
		outputChatBox("This upgrade is not compatible with this vehicle.", player, 255, 194, 14)
		return false
	end

	local oldUpgrade
	for _, installedUpgrade in ipairs(getVehicleUpgrades(vehicle)) do
		if installedUpgrade == upgradeID then
			outputChatBox("This upgrade is already installed.", player, 255, 0, 0)
			return false
		end
		if getVehicleUpgradeSlotName(installedUpgrade) == getVehicleUpgradeSlotName(upgradeID) then
			oldUpgrade = installedUpgrade
			break
		end
	end

	if not takeItemFromSlot(player, itemSlot) then
		outputChatBox("Failed to take the upgrade from your inventory.", player, 255, 0, 0)
		return false
	end
	local function restoreNewUpgradeItem()
		if not giveItem(player, itemID, upgradeID) then
			outputDebugString("[item-system] Failed to restore upgrade item " .. upgradeID .. " to " .. getPlayerName(player), 1)
			outputChatBox("Upgrade rollback failed. Contact staff immediately.", player, 255, 0, 0)
			return false
		end
		return true
	end
	local oldRemoved = false
	if oldUpgrade then
		if not removeVehicleUpgrade(vehicle, oldUpgrade) then
			restoreNewUpgradeItem()
			outputChatBox("The previous upgrade could not be removed.", player, 255, 0, 0)
			return false
		end
		oldRemoved = true
	end

	if not addVehicleUpgrade(vehicle, upgradeID) then
		if oldRemoved and not addVehicleUpgrade(vehicle, oldUpgrade) then
			outputDebugString("[item-system] Failed to restore old vehicle upgrade " .. oldUpgrade .. " on rollback.", 1)
			outputChatBox("Vehicle upgrade rollback failed. Contact staff immediately.", player, 255, 0, 0)
		end
		restoreNewUpgradeItem()
		outputChatBox("This upgrade could not be installed.", player, 255, 194, 14)
		return false
	end

	if oldUpgrade and not giveItem(player, itemID, oldUpgrade) then
		removeVehicleUpgrade(vehicle, upgradeID)
		local oldRestored = addVehicleUpgrade(vehicle, oldUpgrade)
		local newRestored = restoreNewUpgradeItem()
		if not oldRestored or not newRestored then
			outputDebugString("[item-system] Failed to rollback replacement of vehicle upgrade on " .. getPlayerName(player), 1)
			outputChatBox("Vehicle upgrade replacement rollback failed. Contact staff immediately.", player, 255, 0, 0)
		end
		return false
	end

	local data = getElementData(player, "v:mods")
	if type(data) ~= "table" then data = {} end
	if type(data[vehicle]) ~= "table" then data[vehicle] = {} end
	if oldUpgrade then data[vehicle][oldUpgrade] = nil end
	data[vehicle][upgradeID] = getRealTime().timestamp
	exports.anticheat:changeProtectedElementDataEx(player, "v:mods", data, true)

	if oldUpgrade then
		exports.logs:dbLog(player, 6, { vehicle }, "MODDING AUTOREMOVEUPGRADE " .. upgradeID .. " " .. getItemDescription(itemID, upgradeID))
	end
	exports.logs:dbLog(player, 6, { vehicle }, "MODDING ADDUPGRADE " .. upgradeID .. " " .. getItemDescription(itemID, upgradeID))
	exports.vehicle:saveVehicleMods(vehicle)
	exports.global:sendLocalMeAction(player, "adds " .. getItemDescription(itemID, upgradeID) .. " to their " .. exports.global:getVehicleName(vehicle) .. ".")
	return true
end
--
function moveUpgradeFromElement(upgrade)
	local player = client
	local vehicle = source
	local function finishMove()
		if isElement(player) then triggerClientEvent(player, "finishItemMove", player) end
	end
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
		finishMove()
		return false
	end

	upgrade = tonumber(upgrade)
	if not upgrade or upgrade < 1000 or upgrade > 1193 or upgrade ~= math.floor(upgrade)
		or not getVehicleUpgradeSlotName(upgrade) then
		finishMove()
		return false
	end
	local px, py, pz = getElementPosition(player)
	local vx, vy, vz = getElementPosition(vehicle)
	if getElementDimension(player) ~= getElementDimension(vehicle)
		or getElementInterior(player) ~= getElementInterior(vehicle)
		or getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) > 5 then
		finishMove()
		return false
	end
	if isVehicleLocked(vehicle) and getPedOccupiedVehicle(player) ~= vehicle then
		finishMove()
		return false
	end

	local upgrades = getVehicleUpgrades(vehicle)
	local installed = false
	for _, installedUpgrade in ipairs(upgrades) do
		if installedUpgrade == upgrade then
			installed = true
			break
		end
	end
	if not installed then
		outputChatBox("Vehicle upgrade does not exist.", player, 255, 0, 0)
		finishMove()
		return false
	end

	local data = getElementData(player, "v:mods")
	local tracked = type(data) == "table" and type(data[vehicle]) == "table"
		and data[vehicle][upgrade] ~= nil
	local admin = exports.integration:isPlayerTrialAdmin(player)
	if not tracked and not admin then
		finishMove()
		return false
	end
	if not hasSpaceForItem(player, 114, upgrade) then
		outputChatBox("Your inventory is full.", player, 255, 0, 0)
		finishMove()
		return false
	end

	if not removeVehicleUpgrade(vehicle, upgrade) then
		outputChatBox("Vehicle upgrade could not be removed.", player, 255, 0, 0)
		finishMove()
		return false
	end
	if not giveItem(player, 114, upgrade) then
		addVehicleUpgrade(vehicle, upgrade)
		outputChatBox("The upgrade could not be added to your inventory. The vehicle upgrade was restored.", player, 255, 0, 0)
		finishMove()
		return false
	end

	if tracked then
		data[vehicle][upgrade] = nil
		if next(data[vehicle]) == nil then data[vehicle] = nil end
		exports.anticheat:changeProtectedElementDataEx(player, "v:mods", data, true)
	end
	exports.logs:dbLog(player, 6, { player, vehicle }, "REMOVEUPGRADE " .. upgrade .. " " .. getVehicleUpgradeSlotName(upgrade) .. " | Admin override = " .. tostring(admin))
	x_output_wrapper(vehicle, player, 114, upgrade)
	exports.vehicle:saveVehicleMods(vehicle)
	triggerClientEvent(player, "forceElementMoveUpdate", player)
	finishMove()
	return true
end
addEvent( "item:vehicle:removeUpgrade", true )
addEventHandler( "item:vehicle:removeUpgrade", getRootElement(), moveUpgradeFromElement )

setTimer(
	function( ) -- cleanup
		for _, player in ipairs( getElementsByType( "player" ) ) do
			local data = getElementData( player, "v:mods" )
			if data then
				local anyAtAll = false
				local changed = false
				for vehicle, mods in pairs( data ) do
					local anyForVehicle = false
					
					for km, vm in pairs( mods ) do
						if getRealTime( ).timestamp - vm < 5 * 60000 then
							-- added more than five minutes ago
							data[vehicle][km] = nil
							changed = true
						else
							anyForVehicle = true
							anyAtAll = true
						end
					end
					
					if not anyForVehicle then
						data[vehicle] = nil
						changed = true
					end
				end
				
				if not anyAtAll then
					if isElement(player) then
						exports.anticheat:changeProtectedElementDataEx( player, "v:mods", data, true)
					else
						outputDebugString("AntiCheat Error on line 123", 2)
					end
				elseif changed then
					if isElement(player) then
						exports.anticheat:changeProtectedElementDataEx( player, "v:mods", data, true)
					else
						outputDebugString("AntiCheat Error on line 130", 2)
					end
				end
			end
		end
	end,
	5 * 60000,
	0
)
