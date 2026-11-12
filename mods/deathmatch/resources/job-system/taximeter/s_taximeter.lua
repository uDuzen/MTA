--Server-side script: Taximeter
--Created by Exciter, anumaz, 04.05.2014
--Last updated 05.05.2014 by Exciter
--Released as open source. This header should remain intact. Otherwise no use restrictions.

local root = getRootElement()
local taximeterPositions = {}

addEventHandler("onVehicleEnter", root,
		function (player, seat)
				if taxiModels[getElementModel(source)] then
						local theVehicle = source
					
						local fare = getElementData(theVehicle, "taximeter.fare")
						local distance = getElementData(theVehicle, "taximeter.distance")
						local running = getElementData(theVehicle, "taximeter.running") or false
						
						if not fare then
							setElementData(theVehicle, "taximeter.fare", defaultfare)
							fare = defaultfare
						end
						if not distance then
							setElementData(theVehicle, "taximeter.distance", 0)
							distance = 0
						end
						
						local x,y,z = getElementPosition(theVehicle)
						local pos = {x,y,z}
						local light = isVehicleTaxiLightOn(theVehicle)
						
						triggerClientEvent(player, "taximeter:initialize", theVehicle, seat, distance, running, pos, fare, light)
				end
		end
)
--[[
addEventHandler("onResourceStart", getResourceRootElement(getThisResource()),
		function (startedRes)
				local players = getElementsByType("player")
				for k,player in ipairs(players) do
					if isPedInVehicle(player) then
						local theVehicle = getPedOccupiedVehicle(player)
						if taxiModels[getElementModel(theVehicle)] then
								local fare = getElementData(theVehicle, "taximeter.fare")
								local distance = getElementData(theVehicle, "taximeter.distance")
								local running = getElementData(theVehicle, "taximeter.running") or false
								
								if not fare then
									setElementData(theVehicle, "taximeter.fare", defaultfare)
									fare = defaultfare
								end
								if not distance then
									setElementData(theVehicle, "taximeter.distance", 0)
									distance = 0
								end
								
								local x,y,z = getElementPosition(theVehicle)
								local pos = {x,y,z}
								local light = isVehicleTaxiLightOn(theVehicle)
								
								triggerClientEvent(player, "taximeter:initialize", theVehicle, seat, distance, running, pos, fare, light)
						end
					end
				end
		end
)
--]]

addEvent("taximeter:clientStarted", true)
addEventHandler("taximeter:clientStarted", root,
		function ()
			local player = client
			if not player or not isElement(player) or getElementType(player) ~= "player"
				or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
			if isPedInVehicle(player) then
				local theVehicle = getPedOccupiedVehicle(player)
				if taxiModels[getElementModel(theVehicle)] then
						local fare = getElementData(theVehicle, "taximeter.fare")
						local distance = getElementData(theVehicle, "taximeter.distance")
						local running = getElementData(theVehicle, "taximeter.running") or false
						
						if not fare then
							setElementData(theVehicle, "taximeter.fare", defaultfare)
							fare = defaultfare
						end
						if not distance then
							setElementData(theVehicle, "taximeter.distance", 0)
							distance = 0
						end
						
						local x,y,z = getElementPosition(theVehicle)
						local pos = {x,y,z}
						local seat = getPedOccupiedVehicleSeat(player)
						local light = isVehicleTaxiLightOn(theVehicle)
						triggerClientEvent(player, "taximeter:initialize", theVehicle, seat, distance, running, pos, fare, light)
				end
			end
		end
)

function sendTaximeterSync(distance, running, pos, ignoreCheck)
	local theVehicle = source
	local driver = client
	if not driver or not isElement(driver) or not isElement(theVehicle)
		or getElementType(theVehicle) ~= "vehicle"
		or not taxiModels[getElementModel(theVehicle)]
		or getVehicleController(theVehicle) ~= driver
		or type(running) ~= "boolean" then
		return false
	end

	local x, y, z = getElementPosition(theVehicle)
	local currentPos = { x, y, z }
	local previousPos = taximeterPositions[theVehicle]
	local serverDistance = tonumber(getElementData(theVehicle, "taximeter.distance")) or 0
	local wasRunning = getElementData(theVehicle, "taximeter.running") == true
	if wasRunning and previousPos then
		serverDistance = serverDistance + getDistanceBetweenPoints3D(
			previousPos[1], previousPos[2], previousPos[3], x, y, z
		)
	end
	taximeterPositions[theVehicle] = currentPos
	setElementData(theVehicle, "taximeter.distance", serverDistance)
	setElementData(theVehicle, "taximeter.running", running)

	for _, player in pairs(getVehicleOccupants(theVehicle)) do
		if player ~= driver then
			triggerClientEvent(player, "taximeter:sync", theVehicle, serverDistance, running, currentPos)
		end
	end
	return true
end
addEvent("taximeter:sendSync", true)
addEventHandler("taximeter:sendSync", root, sendTaximeterSync)

function updateFare(newFare)
	local theVehicle = source
	local driver = client
	newFare = tonumber(newFare)
	if not driver or not isElement(driver) or not isElement(theVehicle)
		or getElementType(theVehicle) ~= "vehicle"
		or not taxiModels[getElementModel(theVehicle)]
		or getVehicleController(theVehicle) ~= driver
		or not newFare or newFare ~= newFare or newFare == math.huge or newFare == -math.huge
		or newFare < minFare or newFare > maxFare then
		return false
	end
	newFare = math.floor(newFare * 100 + 0.5) / 100
	setElementData(theVehicle, "taximeter.fare", newFare)
	for _, player in pairs(getVehicleOccupants(theVehicle)) do
		if player ~= driver then
			triggerClientEvent(player, "taximeter:sendFare", theVehicle, newFare)
		end
	end
	return true
end
addEvent("taximeter:setFare", true)
addEventHandler("taximeter:setFare", root, updateFare)

function resetMeter()
	local driver = client
	if not driver or not isElement(driver) then return false end
	local theVehicle = getPedOccupiedVehicle(driver)
	if not isElement(theVehicle) or not taxiModels[getElementModel(theVehicle)]
		or getVehicleController(theVehicle) ~= driver then return false end
	local x, y, z = getElementPosition(theVehicle)
	taximeterPositions[theVehicle] = { x, y, z }
	setElementData(theVehicle, "taximeter.distance", 0)
	for _, player in pairs(getVehicleOccupants(theVehicle)) do
		if player ~= driver then
			triggerClientEvent(player, "taximeter:resetMeter", theVehicle)
		end
	end
	return true
end
addEvent("taximeter:resetMeter", true)
addEventHandler("taximeter:resetMeter", root, resetMeter)

function toggleTaxiLight(state)
	local driver = client
	if not driver or not isElement(driver) or type(state) ~= "boolean" then return false end
	local theVehicle = getPedOccupiedVehicle(driver)
	if not isElement(theVehicle) or not taxiModels[getElementModel(theVehicle)]
		or getVehicleController(theVehicle) ~= driver then return false end
	return setVehicleTaxiLightOn(theVehicle, state)
end
addEvent("taximeter:setLight", true)
addEventHandler("taximeter:setLight", root, toggleTaxiLight)

addEventHandler("onElementDestroy", root, function()
	if getElementType(source) == "vehicle" then
		taximeterPositions[source] = nil
	end
end)
