local routePositions = {
	{2430.5205, 1262.4316, 9.4436}, {2429.6953, 1460.9482, 9.4207},
	{2419.9258, 1664.2324, 9.5662}, {2118.0400, 1776.3379, 9.4190},
	{2149.9102, 2119.5742, 9.4188}, {1939.5078, 2116.1602, 9.4112},
	{2190.0830, 1356.0254, 9.4204}, {1862.5186, 1274.9775, 9.4186},
	{1735.6338, 1306.5049, 9.4884}, {1662.6455, 1715.7354, 9.4244},
	{1570.5186, 1863.1221, 9.4235}, {1151.1455, 1815.6816, 10.4091},
	{921.3906, 1855.4375, 9.4202}, {1009.5293, 2138.1387, 9.4193},
	{1028.4434, 2390.4072, 9.4172}
}
local activeSweeperJobs = {}
local function validPlayer(player)
	return player and isElement(player) and getElementType(player) == "player"
		and tonumber(getElementData(player, "loggedin")) == 1
end
local function nearPoint(element, point, distance)
	if not isElement(element) then return false end
	local x, y, z = getElementPosition(element)
	return getDistanceBetweenPoints3D(x, y, z, point[1], point[2], point[3]) <= distance
end
local function isSweeper(player)
	local vehicle = getPedOccupiedVehicle(player)
	return isElement(vehicle) and getElementModel(vehicle) == 574 and getVehicleController(vehicle) == player, vehicle
end

addEvent("sweeper:start", true)
addEventHandler("sweeper:start", root, function(routeIndex)
	local player = client
	local valid = validPlayer(player)
	local vehicle
	if valid then valid, vehicle = isSweeper(player) end
	routeIndex = tonumber(routeIndex)
	if not valid or not routeIndex or routeIndex ~= math.floor(routeIndex)
		or not routePositions[routeIndex] or not nearPoint(player, {1480.6318, 2372.4980, 10.8203}, 35) then
		return false
	end
	activeSweeperJobs[player] = { vehicle = vehicle, route = routeIndex, completed = 0, started = getTickCount() }
	return true
end)

addEvent("sweeper:setRoute", true)
addEventHandler("sweeper:setRoute", root, function(routeIndex)
	local player = client
	local job = activeSweeperJobs[player]
	local valid = validPlayer(player)
	local vehicle
	if valid then valid, vehicle = isSweeper(player) end
	routeIndex = tonumber(routeIndex)
	if not job or not valid or vehicle ~= job.vehicle or not routeIndex
		or routeIndex ~= math.floor(routeIndex) or not routePositions[routeIndex] then return false end
	job.route = routeIndex
	return true
end)

addEvent("sweeper:completeRoute", true)
addEventHandler("sweeper:completeRoute", root, function()
	local player = client
	local job = activeSweeperJobs[player]
	local valid = validPlayer(player)
	local vehicle
	if valid then valid, vehicle = isSweeper(player) end
	if not job or not valid or vehicle ~= job.vehicle or not job.route
		or not nearPoint(vehicle, routePositions[job.route], 8) then return false end
	job.completed = job.completed + 1
	job.route = nil
	return true
end)

addEvent("sweeper:finish", true)
addEventHandler("sweeper:finish", root, function()
	local player = client
	local job = activeSweeperJobs[player]
	local valid = validPlayer(player)
	local vehicle
	if valid then valid, vehicle = isSweeper(player) end
	if not job or not valid or vehicle ~= job.vehicle or job.completed < 1
		or not nearPoint(vehicle, {2836, 975, 9.75}, 10) then return false end
	local wage = math.min(job.completed, 15) * 50
	activeSweeperJobs[player] = nil
	exports.global:giveMoney(player, wage)
	outputChatBox("You earned $" .. wage .. " on your trucking runs.", player, 255, 194, 15)
	respawnVehicle(vehicle)
	setVehicleLocked(vehicle, false)
	return true
end)

addEventHandler("onPlayerQuit", root, function()
	activeSweeperJobs[source] = nil
end)
