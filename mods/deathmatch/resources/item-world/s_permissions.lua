

local function isWorldItemObject(object)
	if not isElement(object) or getElementType(object) ~= "object" then return false end
	local itemWorld = getResourceFromName("item-world")
	local itemWorldRoot = itemWorld and getResourceRootElement(itemWorld)
	return isElement(itemWorldRoot) and getElementParent(getElementParent(object)) == itemWorldRoot
end

local function canManageWorldItem(player, object)
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1
		or not isWorldItemObject(object) then
		return false
	end
	if getElementDimension(player) ~= getElementDimension(object)
		or getElementInterior(player) ~= getElementInterior(object) then
		return false
	end
	local px, py, pz = getElementPosition(player)
	local ox, oy, oz = getElementPosition(object)
	if getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz) > 10 then
		return false
	end
	return exports["item-world"]:canEditItemProperties(player, object) == true
end

local function validatePermissionData(permissionType, data)
	if type(data) ~= "table" then return nil end
	local normalized = {}
	if permissionType == 4 then
		local count = 0
		for _, value in ipairs(data) do
			local factionID = tonumber(value)
			if not factionID or factionID < 1 or factionID ~= math.floor(factionID)
				or not isElement(exports.factions:getFactionFromID(factionID)) then
				return nil
			end
			count = count + 1
			if count > 50 then return nil end
			normalized[#normalized + 1] = factionID
		end
	elseif permissionType == 5 then
		local count = 0
		for _, value in ipairs(data) do
			if type(value) ~= "string" or #value < 3 or #value > 64 or value:find("[%c]") then
				return nil
			end
			count = count + 1
			if count > 50 then return nil end
			normalized[#normalized + 1] = value
		end
	elseif permissionType == 8 then
		local query = data[1]
		if type(query) ~= "string" or #query < 1 or #query > 512 or query:find("[%c]") then
			return nil
		end
		normalized[1] = query
	end
	return normalized
end
function getItemPropertiesData(object)
	local player = client
	if source ~= getResourceRootElement(getThisResource())
		or not canManageWorldItem(player, object) then return false end

	local creatorName
	local creator = tonumber(getElementData(object, "creator")) or 0
	if creator > 0 then creatorName = exports.global:getCharacterNameFromID(creator) end

	local createdDate = getElementData(object, "createdDate")
	if not createdDate then
		local timestamp = getElementData(object, "createdTimestamp")
		if timestamp then createdDate = exports.datetime:formatTimeInterval(timestamp) end
	end

	local protected = getElementData(object, "protected")
	protected = protected ~= nil and protected ~= false and tonumber(protected) ~= 0
	triggerClientEvent(player, "item-world:fillItemPropertiesGUI", getResourceRootElement(), object, creatorName, createdDate, protected)
	return true
end
addEvent("item-world:getItemPropertiesData", true)
addEventHandler("item-world:getItemPropertiesData", getResourceRootElement(), getItemPropertiesData)

function saveItemProperties(object, use, useData, move, moveData, pickup, pickupData, exactValues)
	local player = client
	if source ~= getResourceRootElement(getThisResource())
		or not canManageWorldItem(player, object) then return false end

	use, move, pickup = tonumber(use), tonumber(move), tonumber(pickup)
	if not use or not move or not pickup
		or use < 0 or use > 8 or move < 0 or move > 8 or pickup < 0 or pickup > 8
		or use ~= math.floor(use) or move ~= math.floor(move) or pickup ~= math.floor(pickup)
		or type(exactValues) ~= "boolean" then
		outputChatBox("Invalid item permission settings.", player, 255, 0, 0)
		return false
	end

	local normalizedUseData = validatePermissionData(use, useData)
	local normalizedMoveData = validatePermissionData(move, moveData)
	local normalizedPickupData = validatePermissionData(pickup, pickupData)
	if not normalizedUseData or not normalizedMoveData or not normalizedPickupData then
		outputChatBox("Invalid permission details. Please review the selected factions or characters.", player, 255, 0, 0)
		return false
	end
	local useJSON, moveJSON, pickupJSON = toJSON(normalizedUseData), toJSON(normalizedMoveData), toJSON(normalizedPickupData)
	if type(useJSON) ~= "string" or type(moveJSON) ~= "string" or type(pickupJSON) ~= "string"
		or #useJSON > 8192 or #moveJSON > 8192 or #pickupJSON > 8192 then
		outputChatBox("Permission settings are too large.", player, 255, 0, 0)
		return false
	end

	local id = tonumber(getElementData(object, "id"))
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local result = dbExec(mysql:getConn("mta"),
		"UPDATE worlditems SET perm_use=?, perm_move=?, perm_pickup=?, perm_use_data=?, perm_move_data=?, perm_pickup_data=?, useExactValues=? WHERE id=? LIMIT 1",
		use, move, pickup, useJSON, moveJSON, pickupJSON, exactValues and 1 or 0, id)
	if not result then
		outputChatBox("Failed to save item properties. No settings were changed.", player, 255, 0, 0)
		return false
	end

	local permissions = {
		use = use,
		move = move,
		pickup = pickup,
		useData = normalizedUseData,
		moveData = normalizedMoveData,
		pickupData = normalizedPickupData
	}
	exports.anticheat:changeProtectedElementDataEx(object, "worlditem.permissions", permissions)
	if exactValues then
		exports.anticheat:changeProtectedElementDataEx(object, "useExactValues", true, false)
	else
		removeElementData(object, "useExactValues")
	end

	local itemName = exports["item-system"]:getItemName(
		tonumber(getElementData(object, "itemID")),
		getElementData(object, "itemValue"),
		getElementData(object, "metadata")
	)
	outputChatBox("Saved properties for '" .. tostring(itemName) .. "'.", player, 0, 255, 0)
	return true
end
addEvent("item-world:saveItemProperties", true)
addEventHandler("item-world:saveItemProperties", getResourceRootElement(), saveItemProperties)