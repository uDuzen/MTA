armoredCars = { [427]=true, [528]=true, [432]=true, [601]=true, [428]=true } -- Enforcer, FBI Truck, Rhino, SWAT Tank, Securicar

local btrdiscountratio = 1.2

local function validMechanicVehicle(player, vehicle)
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not vehicle or not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
		return false
	end
	local px, py, pz = getElementPosition(player)
	local vx, vy, vz = getElementPosition(vehicle)
	return getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 10
end

local function getMechanicDiscount(player)
	local factionData = getElementData(player, "faction")
	return type(factionData) == "table" and factionData[4] and btrdiscountratio or 1
end

local function validRGB(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
	return value == math.floor(value) and value >= 0 and value <= 255
end

-- Full Service
function serviceVehicle(veh)
	local player = client
	if not validMechanicVehicle(player, veh) then return false end
		if getElementHealth(veh) <= 950 then
			outputChatBox("This vehicle does not need a quick service.", player, 255, 194, 14)
			return false
		end
		local mechcost = 110
		if getMechanicDiscount(player) > 1 then
			mechcost = mechcost / getMechanicDiscount(player)
		end
		if not (exports.global:hasMoney(player, mechcost) or exports.integration:isPlayerTrialAdmin(player, true)) then
			outputChatBox("You can't afford the parts to service this vehicle.", player, 255, 0, 0)
		else
			if not exports.integration:isPlayerTrialAdmin(player, true) then 
				exports.global:takeMoney(player, mechcost)
			end

			local health = getElementHealth(veh)
			if health <= 950 then
				return
			else
				health = 1000
			end

			fixVehicle(veh)
			setElementHealth(veh, health)
			if not getElementData(veh, "Impounded") or getElementData(veh, "Impounded") == 0 then
				exports.anticheat:changeProtectedElementDataEx(veh, "enginebroke", 0, false)
				if armoredCars[ getElementModel( veh ) ] then
					setVehicleDamageProof(veh, true)
				else
					setVehicleDamageProof(veh, false)
				end
			end
			exports.global:sendLocalMeAction(player, "services the vehicle, patching it up a bit.")
			exports.logs:dbLog(player, 31, {  veh }, "REPAIR QUICK-SERVICE")
		end
end
addEvent("serviceVehicle", true)
addEventHandler("serviceVehicle", getRootElement(), serviceVehicle)

function changeTyre( veh, wheelNumber )
	local player = client
	wheelNumber = tonumber(wheelNumber)
	if not validMechanicVehicle(player, veh) or not wheelNumber or wheelNumber ~= math.floor(wheelNumber) or wheelNumber < 1 or wheelNumber > 4 then return false end
		local mechcost = 10
		if getMechanicDiscount(player) > 1 then
			mechcost = mechcost / getMechanicDiscount(player)
		end
		if not exports.global:hasMoney(player, mechcost) then
			outputChatBox("You can't afford the parts to change this vehicle's tyres.", player, 255, 0, 0)
		else
			local wheel1, wheel2, wheel3, wheel4 = getVehicleWheelStates( veh )
			if not wheel1 then return false end
			exports.global:takeMoney(player, mechcost)

			if (wheelNumber==1) then -- front left
				outputDebugString("Tyre 1 changed.")
				setVehicleWheelStates ( veh, 0, wheel2, wheel3, wheel4 )
			elseif (wheelNumber==2) then -- back left
				outputDebugString("Tyre 2 changed.")
				setVehicleWheelStates ( veh, wheel1, wheel2, 0, wheel4 )
			elseif (wheelNumber==3) then -- front right
				outputDebugString("Tyre 3 changed.")
				setVehicleWheelStates ( veh, wheel1, 0, wheel2, wheel4 )
			elseif (wheelNumber==4) then -- back right
				outputDebugString("Tyre 4 changed.")
				setVehicleWheelStates ( veh, wheel1, wheel2, wheel3, 0 )
			end

			exports.logs:dbLog(player, 31, {  veh }, "REPAIR TIRESWAP")
			exports.global:sendLocalMeAction(player, "replaces the vehicle's tyre.")
		end
end
addEvent("tyreChange", true)
addEventHandler("tyreChange", getRootElement(), changeTyre)

function changePaintjob( veh, paintjob )
	local player = client
	paintjob = tonumber(paintjob)
	if not validMechanicVehicle(player, veh) or not paintjob or paintjob ~= math.floor(paintjob) or paintjob < 0 or paintjob > 3 then return false end
		local mechcost = 7500
		if (getElementData(player,"faction")[4]) then
			mechcost = mechcost / btrdiscountratio
		end
		if not exports.global:takeMoney(player, mechcost) then
			outputChatBox("You can't afford to repaint this vehicle.", player, 255, 0, 0)
		else
			triggerEvent( "paintjobEndPreview", player, veh )
			if setVehiclePaintjob( veh, paintjob ) then
				local col1, col2 = getVehicleColor( veh )
				if col1 == 0 or col2 == 0 then
					setVehicleColor( veh, 1, 1, 1, 1 )
				end
				exports.global:sendLocalMeAction(player, "repaints the vehicle.")
				exports.logs:dbLog(player, 6, {  veh }, "MODDING PAINTJOB ".. paintjob)
				exports.vehicle:saveVehicleMods(veh)
			else
				outputChatBox("This car already has this paintjob.", player, 255, 0, 0)
			end
		end
end
addEvent("paintjobChange", true)
addEventHandler("paintjobChange", getRootElement(), changePaintjob)

function editVehicleHeadlights( veh, color1, color2, color3 )
	local player = client
	color1, color2, color3 = tonumber(color1), tonumber(color2), tonumber(color3)
	if not validMechanicVehicle(player, veh) or not validRGB(color1) or not validRGB(color2) or not validRGB(color3) then return false end
		local mechcost = 1250
		if (getElementData(player,"faction")[4]) then
			mechcost = mechcost / btrdiscountratio
		end
		if not (exports.global:hasMoney(player, mechcost) or exports.integration:isPlayerTrialAdmin(player, true)) then
			outputChatBox("You can't afford to mod this vehicle.", player, 255, 0, 0)
		else
			triggerEvent( "headlightEndPreview", player, veh )
			if setVehicleHeadLightColor ( veh, color1, color2, color3) then
				if not exports.integration:isPlayerTrialAdmin(player, true) then 
					exports.global:takeMoney(player, mechcost)
				end
				exports.global:sendLocalMeAction(player, "replaces the vehicles headlights.")
				exports.anticheat:changeProtectedElementDataEx(veh, "headlightcolors", {color1, color2, color3}, true)
				exports.vehicle:saveVehicleMods(veh)
				exports.logs:dbLog(player, 6, {  veh }, "MODDING HEADLIGHT ".. color1 .. " "..color2.." "..color3)
			else
				outputChatBox("This car already has this headlights.", player, 255, 0, 0)
			end
		end
end
addEvent("editVehicleHeadlights", true)
addEventHandler("editVehicleHeadlights", getRootElement(), editVehicleHeadlights)

 --

function changeVehicleUpgrade( veh, upgrade )
	local player = client
	upgrade = tonumber(upgrade)
	if not validMechanicVehicle(player, veh) or not upgrade or upgrade ~= math.floor(upgrade) or upgrade < 1000 or upgrade > 1193 then return false end
		local item = false
		local u = upgrades[upgrade - 999]
		if not u then
			outputDebugString( getPlayerName( player ) .. " tried to add invalid upgrade #" .. upgrade )
			return
		end
		local name = u[1]
		local mechcost = u[2]
		if (getElementData(player,"faction")[4]) then
			mechcost = mechcost / btrdiscountratio
		end
		if exports.global:hasItem( player, 114, upgrade ) then
			mechcost = 0
			item = true
		end

		if not item and not exports.global:hasMoney( player, mechcost ) then
			outputChatBox("You can't afford to add " .. name .. " to this vehicle.", player, 255, 0, 0)
		else
			for i = 0, 16 do
				if upgrade == getVehicleUpgradeOnSlot( veh, i ) then
					outputChatBox("This car already has this upgrade.", player, 255, 0, 0)
					return
				end
			end
			if addVehicleUpgrade( veh, upgrade ) then
				if item then
					exports.global:takeItem(player, 114, upgrade)
				else
					exports.global:takeMoney(player, mechcost)
				end
				exports.global:sendLocalMeAction(player, "added " .. name .. " to the vehicle.")
				exports.vehicle:saveVehicleMods(veh)
				exports.logs:dbLog(player, 6, {  veh }, "MODDING ADDUPGRADE "..name)
			else
				outputChatBox("Failed to apply the car upgrade.", player, 255, 0, 0)
			end
		end
end
addEvent("changeVehicleUpgrade", true)
addEventHandler("changeVehicleUpgrade", getRootElement(), changeVehicleUpgrade)

function changeVehicleColour(veh, col1, col2, col3, col4)
	local player = client
	if not validMechanicVehicle(player, veh) then return false end
		local mechcost = 100
		if (getElementData(player,"faction")[4]) then
			mechcost = mechcost / btrdiscountratio
		end
		if not (exports.global:hasMoney(player, mechcost) or exports.integration:isPlayerTrialAdmin(player, true)) then
			outputChatBox("You can't afford to repaint this vehicle.", player, 255, 0, 0)
		else
			col = { getVehicleColor( veh, true ) }

			local color1 = col1 or { col[1], col[2], col[3] }
			local color2 = col2 or { col[4], col[5], col[6] }
			local color3 = col3 or { col[7], col[8], col[9] }
			local color4 = col4 or { col[10], col[11], col[12] }
			for _, color in ipairs({ color1, color2, color3, color4 }) do
				if type(color) ~= "table" or #color ~= 3
					or not validRGB(tonumber(color[1])) or not validRGB(tonumber(color[2])) or not validRGB(tonumber(color[3])) then
					return false
				end
			end

			--outputChatBox("1. "..toJSON(color1), player)
			--outputChatBox("2. "..toJSON(color2), player)
			--outputChatBox("3. "..toJSON(color3), player)
			--outputChatBox("4. "..toJSON(color4), player)

			if setVehicleColor( veh, color1[1], color1[2], color1[3], color2[1], color2[2], color2[3],  color3[1], color3[2], color3[3], color4[1], color4[2], color4[3]) then
				if not exports.integration:isPlayerTrialAdmin(player, true) then 
					exports.global:takeMoney(player, mechcost) 
				end
				exports.global:sendLocalMeAction(player, "repaints the vehicle.")
				exports.vehicle:saveVehicleMods(veh)
				exports.logs:dbLog(player, 6, {  veh }, "MODDING REPAINT "..toJSON(col))
			end
		end
end
addEvent("repaintVehicle", true)
addEventHandler("repaintVehicle", getRootElement(), changeVehicleColour)
