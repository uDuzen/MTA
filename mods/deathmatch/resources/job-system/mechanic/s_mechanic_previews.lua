local function validPreviewRequest(vehicle)
	if not vehicle or not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return false end
	if not client then return true end
	local player = client
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	local px, py, pz = getElementPosition(player)
	local vx, vy, vz = getElementPosition(vehicle)
	return getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 10
end

local function validColor(color)
	if type(color) ~= "table" or #color ~= 3 then return false end
	for i = 1, 3 do
		local value = tonumber(color[i])
		if not value or value ~= math.floor(value) or value < 0 or value > 255 then return false end
	end
	return true
end

function headlightPreview( veh, color1, color2, color3 )
	if validPreviewRequest(veh) then
		if not getElementData( veh, "oldheadcolors" ) then
			exports.anticheat:changeProtectedElementDataEx( veh, "oldheadcolors", { getVehicleHeadLightColor( veh ) }, false ) 
		end
		local col = getElementData( veh, "oldheadcolors" )
		color1 = tonumber(color1) or col[1]
		color2 = tonumber(color2) or col[2]
		color3 = tonumber(color3) or col[3]
		if color1 < 0 or color1 > 255 or color1 ~= math.floor(color1)
			or color2 < 0 or color2 > 255 or color2 ~= math.floor(color2)
			or color3 < 0 or color3 > 255 or color3 ~= math.floor(color3) then return false end
		if setVehicleHeadLightColor ( veh, color1, color2, color3) then
			local currentTimer = getElementData(veh, "job:hpreviewtimer")
			if currentTimer and isTimer(currentTimer) then
				killTimer(currentTimer)
			end
			local newTimer = setTimer(headlightEndPreview, 45000, 1, veh)
			exports.anticheat:changeProtectedElementDataEx( veh, "job:hpreviewtimer", newTimer, false )
		end
	end
end
addEvent("headlightPreview", true)
addEventHandler("headlightPreview", getRootElement(), headlightPreview)

function headlightEndPreview( veh )
	if validPreviewRequest(veh) then
		local colors = getElementData( veh, "oldheadcolors" )
		if colors then
			setVehicleHeadLightColor( veh, unpack( colors ) )
			exports.anticheat:changeProtectedElementDataEx( veh, "oldheadcolors" )
		end
	end
end
addEvent("headlightEndPreview", true)
addEventHandler("headlightEndPreview", getRootElement(), headlightEndPreview)

function previewColors( veh, color1, color2, color3, color4 )
	if validPreviewRequest(veh) then
		if not getElementData( veh, "oldcolors" ) then
			exports.anticheat:changeProtectedElementDataEx( veh, "oldcolors", { getVehicleColor( veh, true ) }, false )
		end
		local col = getElementData( veh, "oldcolors" )
		color1 = color1 or { col[1], col[2], col[3] }
		color2 = color2 or { col[4], col[5], col[6] }
		color3 = color3 or { col[7], col[8], col[9] }
		color4 = color4 or { col[10], col[11], col[12] }
		if not validColor(color1) or not validColor(color2) or not validColor(color3) or not validColor(color4) then return false end
		if setVehicleColor( veh, color1[1], color1[2], color1[3], color2[1], color2[2], color2[3],  color3[1], color3[2], color3[3], color4[1], color4[2], color4[3]) then
			local currentTimer = getElementData(veh, "job:previewtimer")
			if currentTimer and isTimer(currentTimer) then
				killTimer(currentTimer)
			end
			local newTimer = setTimer(endColorPreview, 45000, 1, veh)
			exports.anticheat:changeProtectedElementDataEx( veh, "job:previewtimer", newTimer, false )
		end
	end
end
addEvent("colorPreview", true)
addEventHandler("colorPreview", getRootElement(), previewColors)

function endColorPreview( veh )
	if validPreviewRequest(veh) then
		local colors = getElementData( veh, "oldcolors" )
		if colors then
			setVehicleColor( veh, unpack( colors ) )
			exports.anticheat:changeProtectedElementDataEx( veh, "oldcolors" )
		end
	end
end
addEvent("colorEndPreview", true)
addEventHandler("colorEndPreview", getRootElement(), endColorPreview)

function previewPaintjob( veh, paintjob )
	paintjob = tonumber(paintjob)
	if validPreviewRequest(veh) and paintjob and paintjob == math.floor(paintjob) and paintjob >= 0 and paintjob <= 3 then
		if not getElementData( veh, "oldpaintjob" ) then
			exports.anticheat:changeProtectedElementDataEx( veh, "oldpaintjob", getVehiclePaintjob( veh ), false )
		end
		if setVehiclePaintjob( veh, paintjob ) then
			local col1, col2 = getVehicleColor( veh )
			if col1 == 0 or col2 == 0 then
				if not getElementData( veh, "oldcolors" ) then
					exports.anticheat:changeProtectedElementDataEx( veh, "oldcolors", { getVehicleColor( veh ) }, false )
				end
				setVehicleColor( veh, 1, 1, 1, 1 )
			end
			local currentTimer = getElementData(veh, "job:ppreviewtimer")
			if currentTimer and isTimer(currentTimer) then
				killTimer(currentTimer)
			end
			local newTimer = setTimer(endColorPreview, 45000, 1, veh)
			exports.anticheat:changeProtectedElementDataEx( veh, "job:ppreviewtimer", newTimer, false )
		end
	end
end
addEvent("paintjobPreview", true)
addEventHandler("paintjobPreview", getRootElement(), previewPaintjob)

function endPaintjobPreview( veh )
	if validPreviewRequest(veh) then
		local paintjob = getElementData( veh, "oldpaintjob" )
		if paintjob then
			setVehiclePaintjob( veh, paintjob )
			exports.anticheat:changeProtectedElementDataEx( veh, "oldpaintjob" )
		end
		local colors = getElementData( veh, "oldcolors" )
		if colors then
			setVehicleColor( veh, unpack( colors ) )
			exports.anticheat:changeProtectedElementDataEx( veh, "oldcolors" )
		end
	end
end
addEvent("paintjobEndPreview", true)
addEventHandler("paintjobEndPreview", getRootElement(), endPaintjobPreview)
