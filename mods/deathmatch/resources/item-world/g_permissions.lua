mysql = exports.mysql
anticheat = exports.anticheat
items = exports['item-system']
global = exports.global
integration = exports.integration



function canEditItemProperties(thePlayer, object)
	if not isElement(thePlayer) or getElementType(thePlayer) ~= "player"
		or not isElement(object) or getElementType(object) ~= "object" then
		return false
	end

	local playerID = tonumber(getElementData(thePlayer, "dbid"))
	local creatorID = tonumber(getElementData(object, "creator"))
	if playerID and creatorID and playerID == creatorID then
		return true
	end

	local dimension = tonumber(getElementDimension(object)) or 0
	local hasPropertyKey = false
	if dimension > 20000 then
		hasPropertyKey = exports.global:hasItem(thePlayer, 3, dimension - 20000)
	elseif dimension > 0 then
		hasPropertyKey = exports.global:hasItem(thePlayer, 4, dimension)
			or exports.global:hasItem(thePlayer, 5, dimension)
	end
	if hasPropertyKey then return true end

	if exports.integration:isPlayerTrialAdmin(thePlayer)
		and exports.global:isAdminOnDuty(thePlayer) then
		return true
	end
	if exports.integration:isPlayerScripter(thePlayer)
		and exports.global:isStaffOnDuty(thePlayer) then
		return true
	end
	return false
end
permissionTypes = {
	--name, id, hasData
	{"No-one", 0, false},
	{"Everyone", 1, false},
	{"Interior key holders", 2, false},
	{"Admin only", 3, false},
	{"Factions", 4, true},
	{"Characters", 5, true},
	{"Interior owner", 6, false},
	{"Item placer", 7, false},
	{"Exciter Query String", 8, true},
}
function getPermissionTypeIDFromName(name)
	for k,v in ipairs(permissionTypes) do
		if name == v[1] then
			return v[2]
		end
	end
	return false
end

function can(player, action, element)
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or type(action) ~= "string" or not isElement(element)
		or getElementType(element) ~= "object" then
		return false
	end

	local itemWorld = getResourceFromName("item-world")
	local itemWorldRoot = itemWorld and getResourceRootElement(itemWorld)
	if not isElement(itemWorldRoot) or getElementParent(getElementParent(element)) ~= itemWorldRoot then
		return false
	end

	local permissions = getPermissions(element)
	if type(permissions) ~= "table" then return false end
	local permissionType, permissionData
	if action == "use" then
		permissionType, permissionData = tonumber(permissions.use), permissions.useData
	elseif action == "move" then
		permissionType, permissionData = tonumber(permissions.move), permissions.moveData
	elseif action == "pickup" then
		permissionType, permissionData = tonumber(permissions.pickup), permissions.pickupData
	else
		return false
	end
	if not permissionType or permissionType ~= math.floor(permissionType)
		or permissionType < 0 or permissionType > 8 then
		return false
	end

	if permissionType == 0 then
		return false
	elseif permissionType == 1 then
		return true
	elseif permissionType == 2 then
		local dimension = tonumber(getElementDimension(element)) or 0
		if dimension > 20000 then
			return global:hasItem(player, 3, dimension - 20000) == true
		elseif dimension > 0 then
			return global:hasItem(player, 4, dimension) == true
				or global:hasItem(player, 5, dimension) == true
			end
	elseif permissionType == 3 then
		return integration:isPlayerAdmin(player) and global:isAdminOnDuty(player) or false
	elseif permissionType == 4 then
		if type(permissionData) ~= "table" then return false end
		for _, factionID in ipairs(permissionData) do
			factionID = tonumber(factionID)
			if factionID and factionID > 0 and factionID == math.floor(factionID)
				and exports.factions:isPlayerInFaction(player, factionID) then
				return true
			end
		end
	elseif permissionType == 5 then
		if type(permissionData) ~= "table" then return false end
		local playerName = exports.global:getPlayerName(player)
		if type(playerName) ~= "string" then return false end
		for _, allowedName in ipairs(permissionData) do
			if type(allowedName) == "string" and allowedName == playerName then return true end
		end
	elseif permissionType == 6 then
		local dimension = tonumber(getElementDimension(element))
		if not dimension then return false end
		local interiorElement = getElementByID("int" .. tostring(dimension))
		if not isElement(interiorElement) then return false end
		local interiorData = getElementData(interiorElement, "status")
		if type(interiorData) ~= "table" then return false end
		local ownerID = tonumber(interiorData.owner)
		local characterID = tonumber(getElementData(player, "dbid"))
		return ownerID and ownerID > 0 and characterID == ownerID or false
	elseif permissionType == 7 then
		local creatorID = tonumber(getElementData(element, "creator"))
		local characterID = tonumber(getElementData(player, "dbid"))
		return creatorID and characterID and creatorID == characterID or false
	elseif permissionType == 8 then
		if type(permissionData) ~= "table" or type(permissionData[1]) ~= "string"
			or #permissionData[1] < 1 or #permissionData[1] > 512 then
			return false
		end
		return exports.global:exciterQueryString(player, permissionData[1]) == true
	end
	return false
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function isNumeric(a)
	if tonumber(a) ~= nil then return true else return false end
end