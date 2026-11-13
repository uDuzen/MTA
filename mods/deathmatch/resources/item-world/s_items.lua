--[[
* ***********************************************************************************************************************
* Copyright (c) 2015 OwlGaming Community - All Rights Reserved
* All rights reserved. This program and the accompanying materials are private property belongs to OwlGaming Community
* Unauthorized copying of this file, via any medium is strictly prohibited
* Proprietary and confidential
* ***********************************************************************************************************************
]]

items = exports['item-system']
function createItem(id, itemID, itemValue, ...)
	local o = createObject(...)
	if o then
		anticheat:changeProtectedElementDataEx(o, "id", id)
		anticheat:changeProtectedElementDataEx(o, "itemID", itemID)
		anticheat:changeProtectedElementDataEx(o, "itemValue", itemValue, itemValue ~= 1)

		return o
	else
		if dbExec(mysql:getConn('mta'), "DELETE FROM `worlditems` WHERE `id` = ?", id) then
			outputDebugString("Deleted bugged Item ID #"..id)
		else
			outputDebugString("Failed to delete bugged Item ID #"..id)
		end
		return false
	end
end

function updateItemValue(element, newValue)
	if not isElement(element) or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource())
		or (type(newValue) ~= "string" and type(newValue) ~= "number") then return false end
	newValue = tostring(newValue)
	if #newValue > 1024 then return false end
	local id = tonumber(getElementData(element, "id"))
	if not id or id < 1 or id ~= math.floor(id) then return false end
	if dbExec(mysql:getConn("mta"), "UPDATE worlditems SET itemvalue=? WHERE id=?", newValue, id) then
		anticheat:changeProtectedElementDataEx(element, "itemValue", newValue)
		return true
	end
	return false
end

function setData(element, key, value)
	if not isElement(element) or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource())
		or type(key) ~= "string" or #key < 1 or #key > 64 then return false end
	local id = tonumber(getElementData(element, "id"))
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local metadata = {}
	local current = getElementData(element, "metadata")
	if type(current) == "table" then
		for metadataKey, metadataValue in pairs(current) do metadata[metadataKey] = metadataValue end
	end
	metadata[key] = value
	local encoded = toJSON(metadata)
	if type(encoded) ~= "string" or #encoded > 8192 then return false end
	if dbExec(mysql:getConn("mta"), "UPDATE worlditems SET metadata=? WHERE id=?", encoded, id) then
		anticheat:changeProtectedElementDataEx(element, "metadata", metadata)
		return true
	end
	return false
end

function getData(element, key)
	if not isElement(element) or type(key) ~= "string"
		or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource()) then
		return nil
	end
	local metadata = getElementData(element, "metadata")
	if type(metadata) ~= "table" then return nil end
	return metadata[key]
end

function setPermissions(element, permissions)
	if not isElement(element) or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource())
		or type(permissions) ~= "table" then return false end
	local id = tonumber(getElementData(element, "id"))
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local use, move, pickup = tonumber(permissions.use), tonumber(permissions.move), tonumber(permissions.pickup)
	if not use or not move or not pickup
		or use < 0 or use > 8 or move < 0 or move > 8 or pickup < 0 or pickup > 8
		or use ~= math.floor(use) or move ~= math.floor(move) or pickup ~= math.floor(pickup) then return false end
	local useData = type(permissions.useData) == "table" and permissions.useData or {}
	local moveData = type(permissions.moveData) == "table" and permissions.moveData or {}
	local pickupData = type(permissions.pickupData) == "table" and permissions.pickupData or {}
	local useJSON, moveJSON, pickupJSON = toJSON(useData), toJSON(moveData), toJSON(pickupData)
	if type(useJSON) ~= "string" or type(moveJSON) ~= "string" or type(pickupJSON) ~= "string"
		or #useJSON > 8192 or #moveJSON > 8192 or #pickupJSON > 8192 then return false end
	local result = dbExec(mysql:getConn("mta"),
		"UPDATE worlditems SET perm_use=?, perm_move=?, perm_pickup=?, perm_use_data=?, perm_move_data=?, perm_pickup_data=? WHERE id=?",
		use, move, pickup, useJSON, moveJSON, pickupJSON, id)
	if not result then return false end
	anticheat:changeProtectedElementDataEx(element, "worlditem.permissions", {
		use = use, move = move, pickup = pickup,
		useData = useData, moveData = moveData, pickupData = pickupData
	})
	return true
end

function getPermissions(element)
	if not isElement(element)
		or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource()) then
		return false
	end
	local permissions = getElementData(element, "worlditem.permissions")
	if type(permissions) == "table" then return permissions end
	return getPermissionsFromDB(element)
end

function getPermissionsFromDB(element)
	if not isElement(element) or getElementParent(getElementParent(element)) ~= getResourceRootElement(getThisResource()) then
		return false
	end
	local id = tonumber(getElementData(element, "id"))
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local result = mysql:query("SELECT perm_use, perm_move, perm_pickup, perm_use_data, perm_move_data, perm_pickup_data FROM worlditems WHERE id = " .. id .. " LIMIT 1")
	if not result then return false end
	local row = mysql:fetch_assoc(result)
	mysql:free_result(result)
	if not row then return false end
	local permissions = {
		use = tonumber(row.perm_use) or 1,
		move = tonumber(row.perm_move) or 1,
		pickup = tonumber(row.perm_pickup) or 1,
		useData = type(row.perm_use_data) == "string" and fromJSON(row.perm_use_data) or {},
		moveData = type(row.perm_move_data) == "string" and fromJSON(row.perm_move_data) or {},
		pickupData = type(row.perm_pickup_data) == "string" and fromJSON(row.perm_pickup_data) or {}
	}
	if type(permissions.useData) ~= "table" then permissions.useData = {} end
	if type(permissions.moveData) ~= "table" then permissions.moveData = {} end
	if type(permissions.pickupData) ~= "table" then permissions.pickupData = {} end
	anticheat:changeProtectedElementDataEx(element, "worlditem.permissions", permissions)
	return permissions
end

local function sqlDeleteObject( dbid )
	
end

-- delete an object by dbid, return true of deleted something, false otherwise.
function deleteOne(dbid, no_sql)
	local id = tonumber(dbid)
	if not id or id < 1 or id ~= math.floor(id) then return false end
	local matchingObjects = {}
	for _, object in ipairs(getElementsByType("object", resourceRoot)) do
		if tonumber(getElementData(object, "id")) == id then
			matchingObjects[#matchingObjects + 1] = object
		end
	end
	if not no_sql and not dbExec(exports.mysql:getConn("mta"), "DELETE FROM worlditems WHERE id=? LIMIT 1", id) then
		return false
	end
	local deleted = false
	for _, object in ipairs(matchingObjects) do
		if isElement(object) and destroyElement(object) then deleted = true end
	end
	return not no_sql or deleted
end

function deleteAll(id, value, no_sql)
	id = tonumber(id)
	if not id or id < 1 or id ~= math.floor(id) then return 0 end
	local normalizedValue = value ~= nil and tostring(value) or nil
	local matchingObjects = {}
	for _, object in ipairs(getElementsByType("object", resourceRoot)) do
		local objectItemID = tonumber(getElementData(object, "itemID"))
		local objectValue = getElementData(object, "itemValue")
		if objectItemID == id and (normalizedValue == nil or tostring(objectValue) == normalizedValue) then
			matchingObjects[#matchingObjects + 1] = object
		end
	end
	if #matchingObjects == 0 then return 0 end

	if not no_sql then
		local querySucceeded
		if normalizedValue ~= nil then
			querySucceeded = dbExec(exports.mysql:getConn("mta"), "DELETE FROM worlditems WHERE itemid=? AND itemvalue=?", id, normalizedValue)
		else
			querySucceeded = dbExec(exports.mysql:getConn("mta"), "DELETE FROM worlditems WHERE itemid=?", id)
		end
		if not querySucceeded then
			outputDebugString("[item-world] deleteAll database operation failed for item ID " .. id, 1)
			return 0
		end
	end

	local deleted = 0
	for _, object in ipairs(matchingObjects) do
		if isElement(object) and destroyElement(object) then deleted = deleted + 1 end
	end
	return deleted
end
