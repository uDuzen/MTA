addEventHandler( "onVehicleRespawn", getRootElement( ),
	function( )
		if isVehicleTaxiLightOn( source ) then
			setVehicleTaxiLightOn( source, false )
		end
	end
)

addEventHandler( "onVehicleStartExit", getRootElement( ),
	function( player, seat, jacked )
		if isVehicleTaxiLightOn( source ) then
			setVehicleTaxiLightOn( source, false )
		end
	end
)

function toggleTaxiLight(thePlayer, commandName)
	if not thePlayer or not isElement(thePlayer) or getElementType(thePlayer) ~= "player"
		or tonumber(getElementData(thePlayer, "loggedin")) ~= 1 then return false end
	local theVehicle = getPedOccupiedVehicle(thePlayer)
	if not isElement(theVehicle) then return false end
	local model = getElementModel(theVehicle)
	if getVehicleController(theVehicle) == thePlayer and (model == 438 or model == 420) then
		return setVehicleTaxiLightOn(theVehicle, not isVehicleTaxiLightOn(theVehicle))
	end
	return false
end
addCommandHandler("taxilight", toggleTaxiLight, false, false)