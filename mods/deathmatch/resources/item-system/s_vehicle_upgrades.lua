function addUpgrade( source, vehicle, itemSlot, itemID, itemValue )
	-- check for existing upgrades
	local old_upgrades = getVehicleUpgrades(vehicle)
	local old_upgrade = nil
	for key, value in ipairs(old_upgrades) do
		if value == itemValue then
			outputChatBox("This Upgrade is already added.", source, 255, 0, 0)
			return
		elseif getVehicleUpgradeSlotName(value) == getVehicleUpgradeSlotName(itemValue) then
			old_upgrade = value
		end
	end
	
	if getElementData(vehicle, "job") ~= 0 or getElementData(vehicle, "owner") == -2 then
		outputChatBox("You can't install upgrades to civilian vehicles!", source, 255, 0, 0)
		return
	end
	
	-- upgrade is not added yet, try it
	if takeItemFromSlot(source, itemSlot) then
		if addVehicleUpgrade(vehicle, itemValue) then
			local data = getElementData( source, "v:mods" ) or {}
			
			if old_upgrade then
				giveItem(source, itemID, old_upgrade)
				exports.logs:dbLog(source, 6, { vehicle }, "MODDING AUTOREMOVEUPGRADE ".. itemValue .. " " .. getItemDescription(itemID, itemValue))
				if data[vehicle] then
					data[vehicle][old_upgrade] = nil
				end
			end
			exports.logs:dbLog(source, 6, { vehicle }, "MODDING ADDUPGRADE ".. itemValue .. " " .. getItemDescription(itemID, itemValue))
			exports.global:sendLocalMeAction(source, "adds " .. getItemDescription(itemID, itemValue) .. " to their " .. exports.global:getVehicleName(vehicle).."("..getVehicleName(vehicle) .. ").")
			exports.vehicle:saveVehicleMods(vehicle)
			
			if not data[vehicle] then
				data[vehicle] = {}
			end
			data[vehicle][itemValue] = getRealTime( ).timestamp
			if isElement(source) then
				exports.anticheat:changeProtectedElementDataEx( source, "v:mods", data, true)
			else
				outputDebugString("AntiCheat Error on line 35", 2)
			end
		else
			outputChatBox("This upgrade is not compatible to this " .. exports.global:getVehicleName(vehicle) .. ".", source, 255, 194, 14)
			giveItem( source, itemID, itemValue )
		end
	else
		outputChatBox("Failed to take item.", source, 255, 194, 14)
	end
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
