-- Chaos dispatch blips!

addEventHandler("onElementDataChange", getRootElement(), function(name, oldD)
  if name == "lspd:siren" then
    triggerClientEvent(root, "dispatch:blipSiren", resourceRoot, getElementData(source, "lspd:siren"), source)
  elseif name == "dispatch:joint" then
    triggerClientEvent(root, "dispatch:jointChange", resourceRoot, getElementData(root, "dispatch:joint")) 
  elseif name == "faction" then
  	if getElementType(source) ~= "player" then return end
    triggerClientEvent(root, "dispatch:factionChange", resourceRoot, getElementData(source, "faction"), oldD) 
  end
end)

local function isDispatchMember(player)
	return isElement(player) and getElementType(player) == "player"
		and tonumber(getElementData(player, "loggedin")) == 1
		and (exports.factions:isPlayerInFaction(player, 1)
			or exports.factions:isPlayerInFaction(player, 2)
			or exports.factions:isPlayerInFaction(player, 50)
			or exports.factions:isPlayerInFaction(player, 164))
end

addEvent("dispatch:onDutyChange", true)
addEventHandler("dispatch:onDutyChange", resourceRoot, function(data)
	local player = client
	if not isDispatchMember(player) or type(data) ~= "boolean" then return false end
	triggerClientEvent(root, "dispatch:onDutyChange", resourceRoot, data, player)
end)

addEvent("dispatch:callsignChange", true)
addEventHandler("dispatch:callsignChange", resourceRoot, function(data)
	local player = client
	if not isDispatchMember(player) or type(data) ~= "string" or #data < 1 or #data > 16
		or not data:match("^[A-Z0-9%-]+$") then
		return false
	end
	triggerClientEvent(root, "dispatch:callsignChange", resourceRoot, data, player)
end)