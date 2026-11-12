function cancelCityMaintenance()
	local player = client
	if not player or not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or tonumber(getElementData(player, "job")) ~= 4 then
		return false
	end
	return exports.global:takeItem(player, 115, "41:1:Spraycan", 2500)
end
addEvent("cancelCityMaintenance", true)
addEventHandler("cancelCityMaintenance", root, cancelCityMaintenance)
