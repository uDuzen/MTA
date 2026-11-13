function setElementData(...)
	return anticheat:changeProtectedElementDataEx(...)
end

local loadedWorldItems = 0
local totalWorldItems = 0
local percent
function loadOneWorldItem(row)
	if type(row) == "table" then
		local id = tonumber(row.id)
		local itemID = tonumber(row.itemid)
		local itemValue = tonumber(row.itemvalue) or row.itemvalue
		local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
		local dimension, interior = tonumber(row.dimension), tonumber(row.interior)
		local rx2, ry2, rz2 = tonumber(row.rx) or 0, tonumber(row.ry) or 0, tonumber(row.rz) or 0
		local creator = tonumber(row.creator)
		local createdDate = tostring(row.creationdate or "")
		local protected = tonumber(row.protected)
		local permUse = tonumber(row.perm_use) or 1
		local permMove = tonumber(row.perm_move) or 1
		local permPickup = tonumber(row.perm_pickup) or 1
		local permUseData = type(row.perm_use_data) == "string" and fromJSON(row.perm_use_data) or {}
		local permMoveData = type(row.perm_move_data) == "string" and fromJSON(row.perm_move_data) or {}
		local permPickupData = type(row.perm_pickup_data) == "string" and fromJSON(row.perm_pickup_data) or {}
		local useExactValues = tonumber(row.useExactValues) == 1
		local metadata = type(row.metadata) == "string" and fromJSON(row.metadata) or nil
		if type(permUseData) ~= "table" then permUseData = {} end
		if type(permMoveData) ~= "table" then permMoveData = {} end
		if type(permPickupData) ~= "table" then permPickupData = {} end
		if type(metadata) ~= "table" then metadata = nil end

		local validRow = id and id > 0 and id == math.floor(id)
			and itemID and itemID ~= 0 and itemID == math.floor(itemID)
			and x and y and z and dimension and interior
			and x == x and y == y and z == z
			and math.abs(x) <= 3000 and math.abs(y) <= 3000
			and z >= -100 and z <= 2000
		if validRow then
			local obj
			if itemID < 0 then
				local weaponID = -itemID
				local modelid = 2969
				if weaponID == 100 then
					modelid = 1242
				elseif weaponID == 42 then
					modelid = 2690
				else
					modelid = weaponmodels[weaponID] or 2969
				end
				obj = createItem(id, itemID, itemValue, modelid, x, y, z - 0.1, 75, -10, rz2)
			else
				local modelid = exports["item-system"]:getItemModel(itemID, itemValue, metadata)
				local rx, ry, rz, zoffset = 0, 0, 0, 0
				if not useExactValues then
					rx, ry, rz, zoffset = exports["item-system"]:getItemRotInfo(itemID, itemValue)
				end
				obj = createItem(id, itemID, itemValue, modelid, x, y, z + (tonumber(zoffset) or 0), rx + rx2, ry + ry2, rz + rz2)
			end

			if isElement(obj) then
				exports.pool:allocateElement(obj, id, true)
				setElementDimension(obj, dimension)
				setElementInterior(obj, interior)
				setElementData(obj, "creator", creator)
				setElementData(obj, "createdDate", createdDate)
				if protected and protected ~= 0 then setElementData(obj, "protected", protected) end
				if useExactValues then setElementData(obj, "useExactValues", true) end

				local permissions = {
					use = permUse,
					move = permMove,
					pickup = permPickup,
					useData = permUseData,
					moveData = permMoveData,
					pickupData = permPickupData
				}
				anticheat:changeProtectedElementDataEx(obj, "worlditem.permissions", permissions)
				if metadata then anticheat:changeProtectedElementDataEx(obj, "metadata", metadata) end

				if itemID > 0 then
					local scale = exports["item-system"]:getItemScale(itemID, itemValue, metadata)
					if scale then setObjectScale(obj, scale) end
					local doubleSided = exports["item-system"]:getItemDoubleSided(itemID, itemValue)
					if doubleSided then setElementDoubleSided(obj, doubleSided) end
				end
			else
				outputDebugString("[ITEM WORLD] Failed to create world item #" .. tostring(id) .. " (item " .. tostring(itemID) .. ")", 1)
			end
		else
			outputDebugString("[ITEM WORLD] Skipped invalid world item row: " .. tostring(id), 1)
		end
	end

	loadedWorldItems = loadedWorldItems + 1
	if loadedWorldItems >= totalWorldItems then
		if getRandomPlayer() then
			triggerLatentClientEvent("hud:loading", resourceRoot, "Loading world items", { max = totalWorldItems, cur = totalWorldItems })
		end
		local textureResource = getResourceFromName("item-texture")
		if textureResource and getResourceState(textureResource) == "running" then
			restartResource(textureResource)
		end
	elseif totalWorldItems > 0 and getRandomPlayer()
		and percent ~= math.ceil(loadedWorldItems / totalWorldItems * 100) then
		percent = math.ceil(loadedWorldItems / totalWorldItems * 100)
		triggerLatentClientEvent("hud:loading", resourceRoot, "Loading world items", { max = totalWorldItems, cur = loadedWorldItems })
	end
end

local mysql = exports.mysql
local timerDelay = 50
function loadWorldItems()
	local ticks = getTickCount( )
	
	local itemInactivityScannerMode = tonumber(get("inactivityscanner_items"))
	--outputDebugString("itemInactivityScannerMode="..tostring(itemInactivityScannerMode))
	--[[
		MODES:
		0 - off
		1 - delete all items after 30 days
		2 - delete exterior items only after 30 days (avoid deleting interior items)
		Storage items ID 81 (fridge), 103 (fridge), 223 (storage generic) and 231 (shipping container) are excempt from deletion
		Other excempt items: 169 (keyless digital door lock)
		Notes (ID 72) will delete after 3 days.
	]]
	if itemInactivityScannerMode == 1 then
		outputDebugString("Deleting all unprotected inactive world items (mode 1)")
		dbExec(mysql:getConn("mta"), "DELETE FROM worlditems WHERE protected=0 AND itemID NOT IN(81, 103, 169, 223, 231) AND ((DATEDIFF(NOW(), creationdate) > 30) OR (DATEDIFF(NOW(), creationdate) > 3 AND itemID=72))")
	elseif itemInactivityScannerMode == 2 then
		outputDebugString("Deleting unprotected inactive exterior world items (mode 2)")
		dbExec(mysql:getConn("mta"), "DELETE FROM worlditems WHERE protected=0 AND itemID NOT IN(81, 103, 169, 223, 231) AND interior=0 AND ((DATEDIFF(NOW(), creationdate) > 30) OR (DATEDIFF(NOW(), creationdate) > 3 AND itemID=72))")
	end

	dbQuery(function(qh)
		local res, rows, err = dbPoll(qh, 0)
		if type(res) ~= "table" then
			outputDebugString("[ITEM WORLD] Failed to query world items: " .. tostring(err or rows), 1)
			return
		end
		totalWorldItems = #res
		if totalWorldItems == 0 then
			local textureResource = getResourceFromName("item-texture")
			if textureResource and getResourceState(textureResource) == "running" then restartResource(textureResource) end
			return
		end
		for _, row in ipairs(res) do
			setTimer(loadOneWorldItem, timerDelay, 1, row)
			timerDelay = timerDelay + 1
		end
		outputDebugString("[ITEM WORLD] Loading " .. totalWorldItems .. " world items; estimated time " .. tostring(math.ceil((timerDelay / 1000) / 60)) .. " minutes.")
	end, mysql:getConn("mta"), "SELECT * FROM worlditems")
end
addEventHandler("onResourceStart", resourceRoot, loadWorldItems)
