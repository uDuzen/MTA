local drivers = {}
local blips = {}
local acCheck = { }
local driverProgress = {}
local busModels = { [431] = true, [437] = true }

function updateBusBlips(line)
	local driversonline = 0
	for k, v in ipairs(drivers[line]) do
		driversonline = driversonline + #v
	end

	if driversonline > 0 then
		for k, v in ipairs(drivers[line]) do
			if #(drivers[line][k-1] or {}) + #v > 0 then
				setBlipColor( blips[line][k], 127, 255, 63, 127 )
			else
				setBlipColor( blips[line][k], 255, 255, 63, 127 )
			end
		end
	else
		for k, v in ipairs(blips[line]) do
			setBlipColor( v, 255, 63, 63, 127 )
		end
	end
end

function removeDriver(targetPlayer)
	targetPlayer = targetPlayer or source
	for _, lineDrivers in ipairs(drivers) do
		for _, stopDrivers in ipairs(lineDrivers) do
			for i = #stopDrivers, 1, -1 do
				if stopDrivers[i] == targetPlayer then
					table.remove(stopDrivers, i)
				end
			end
		end
	end
end

function removeDriverOnAllLines()
	removeDriver()
	for line, v in pairs(drivers) do
		updateBusBlips(line)
	end
end
addEventHandler( "onPlayerQuit", getRootElement(), removeDriverOnAllLines )
addEventHandler("onCharacterLogin", getRootElement(), removeDriverOnAllLines )

function doPay(client)
	local hours = tonumber(getElementData(client, "hoursplayed"))
	local rate = 50
	local hoursrate = math.floor(hours*(rate*0.03))

	if hours>=10 then
		rate = rate-hoursrate
		if rate < 10 then
			rate = 10
		end
	end

	exports.global:giveMoney(client, rate)
end

local function getNextBusStop(route, lastStop)
	local nextStop
	for _, point in ipairs(route.points) do
		if point[4] == true and tonumber(point[5]) and tonumber(point[5]) > lastStop then
			if not nextStop or tonumber(point[5]) < nextStop then
				nextStop = tonumber(point[5])
			end
		end
	end
	return nextStop
end

local function isBusNearStop(vehicle, route, stopNumber)
	for _, point in ipairs(route.points) do
		if point[4] == true and tonumber(point[5]) == stopNumber then
			local x, y, z = getElementPosition(vehicle)
			return getDistanceBetweenPoints3D(x, y, z, point[1], point[2], point[3]) <= 75
		end
	end
	return false
end

function payBusDriver(line, stop)
	local player = client
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or tonumber(getElementData(player, "job")) ~= 3 then
		return false
	end

	line, stop = tonumber(line), tonumber(stop)
	if not line or line ~= math.floor(line) or not g_bus_routes[line]
		or not stop or stop ~= math.floor(stop) then
		return false
	end

	local vehicle = getPedOccupiedVehicle(player)
	if not isElement(vehicle) or not busModels[getElementModel(vehicle)]
		or getVehicleController(vehicle) ~= player then
		return false
	end

	if stop == -1 then
		driverProgress[player] = nil
		removeDriver(player)
		for routeID in pairs(drivers) do updateBusBlips(routeID) end
		return true
	end

	if stop == 0 then
		if driverProgress[player] or not isBusNearStop(vehicle, { points = { {1811, -1890, 13, true, 0} } }, 0) then
			return false
		end
		driverProgress[player] = { line = line, lastStop = 0 }
		removeDriver(player)
		if drivers[line] and drivers[line][1] then
			table.insert(drivers[line][1], player)
			updateBusBlips(line)
		end
		return true
	end

	local progress = driverProgress[player]
	local route = g_bus_routes[line]
	if not progress or progress.line ~= line then return false end

	if stop == -2 then
		if getNextBusStop(route, progress.lastStop) then return false end
		driverProgress[player] = nil
		removeDriver(player)
		updateBusBlips(line)
		return true
	end

	local expectedStop = getNextBusStop(route, progress.lastStop)
	if not expectedStop or stop ~= expectedStop or not isBusNearStop(vehicle, route, stop) then
		triggerBusCheatDetection(player, stop)
		return false
	end

	progress.lastStop = stop
	doPay(player)
	removeDriver(player)
	if drivers[line] and drivers[line][stop + 1] then
		table.insert(drivers[line][stop + 1], player)
	end
	updateBusBlips(line)
	return true
end
addEvent("payBusDriver",true)
addEventHandler("payBusDriver", getRootElement(), payBusDriver)

function triggerBusCheatDetection(thePlayer,stop)
	outputDebugString("[payBusDriver]".. getPlayerName(thePlayer) .. " " .. getPlayerIP(thePlayer) .. " used the same stop twice ("..stop..")")
end

function busAdNextStop(line, stop)
	local seat = getPedOccupiedVehicleSeat(source)
	if not seat or seat ~= 0 then
		return
	end

	if(stop<#g_bus_routes[line].stops)then
		exports.hud:sendBottomNotification(source, "Bus Operator", "Current Stop: [".. g_bus_routes[line].stops[stop] .. "]     Next Stop: [".. g_bus_routes[line].stops[stop+1] .. "] ")
	end
end
addEvent("busAdNextStop",true)
addEventHandler("busAdNextStop", getRootElement(), busAdNextStop)

function takeBusFare()
	local passenger = client
	if not passenger or not isElement(passenger) or getElementType(passenger) ~= "player"
		or tonumber(getElementData(passenger, "loggedin")) ~= 1 then return false end
	local vehicle = getPedOccupiedVehicle(passenger)
	local seat = getPedOccupiedVehicleSeat(passenger)
	if not isElement(vehicle) or not busModels[getElementModel(vehicle)]
		or not seat or seat == 0 then return false end
	local driver = getVehicleOccupant(vehicle, 0)
	if not isElement(driver) or getElementType(driver) ~= "player"
		or tonumber(getElementData(driver, "loggedin")) ~= 1 then return false end
	if not exports.global:takeMoney(passenger, 5) then return false end
	if not exports.global:giveMoney(driver, 5) then
		exports.global:giveMoney(passenger, 5)
		return false
	end
	return true
end
addEvent("payBusFare", true)
addEventHandler("payBusFare", getRootElement(), takeBusFare)

function ejectPlayerFromBus()
	local player = client
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	local vehicle = getPedOccupiedVehicle(player)
	local seat = getPedOccupiedVehicleSeat(player)
	if not isElement(vehicle) or not busModels[getElementModel(vehicle)] or not seat or seat == 0 then
		return false
	end
	exports.anticheat:changeProtectedElementDataEx(player, "realinvehicle", 0, false)
	return removePedFromVehicle(player)
end
addEvent("removePlayerFromBus", true)
addEventHandler("removePlayerFromBus", getRootElement(), ejectPlayerFromBus)

-- BUS ROUTES BLIPS
function createBusBlips( )
	for routeID, route in ipairs( g_bus_routes ) do
		blips[routeID] = {}
		drivers[routeID] = {}
		for pointID, point in ipairs( route.points ) do
			if point[4] and #route.points ~= pointID then
				local stop = #blips[routeID]+1
				blips[routeID][stop] = createBlip( point[1], point[2], point[3], 0, 1, 255, 63, 63, 127, -5, 65 )
				drivers[routeID][stop] = {}
			end
		end
	end
end
addEventHandler( "onResourceStart", getResourceRootElement(), createBusBlips )
