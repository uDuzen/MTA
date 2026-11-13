mysql = exports.mysql

--[[
x loadItems(obj) -- loads all items (caching)
x sendItems(obj, to) -- sends the items to the player
x clearItems(obj) -- clears all items from the player

x giveItem(obj, itemID, itemValue, itemIndex, isThisFromSplittingOrAdminCmd, metadata) -- gives an item
x takeItem(obj, itemID, itemValue = nil) -- takes the item, or if nil/false, the first one with the same item ID
x takeItemFromSlot(obj, slot, nosqlupdate) -- ...
x updateItemValue(obj, slot, itemValue) -- updates the object's item value

x moveItem(from, to, slot) -- moves an item from any inventory to another (was on from's specified slot before, true if successful, internally only updates the owner in the DB and modifies the arrays

x hasItem(obj, itemID, itemValue = nil ) -- returns true if the player has that item -- returns bool hasItem, int slot, int/string itemValue, int index, table/nil metadata
x hasSpaceForItem(obj, itemID, itemValue, metadata) -- returns true if you can put more stuff in
x countItems(obj, itemID, itemValue) -- counts how often a player has that item

x getItems(obj) -- returns an array of all items in { slot = { itemID, itemValue, index, protected, metadata } } table
x getCarriedWeight(obj) -- returns the current weight an element carries
x getMaxWeight(obj) -- returns the maximum weight the element is capable holding of

x deleteAll(itemID, itemValue) -- deletes all instances of that item
]]--

local drugList = {[30]=" gram(s)", [31]=" gram(s)", [32]=" gram(s)", [33]=" gram(s)", [34]=" gram(s)", [35]=" ml(s)", [36]=" tablet(s)", [37]=" gram(s)", [38]=" gram(s)", [39]=" gram(s)", [40]=" ml(s)", [41]=" tab(s)", [42]=" shroom(s)", [43]=" tablet(s)"}

local saveditems = {}
local subscribers = {}

-- util function for sendItems
local function itemconv( arr )
	if not arr then
		--outputDebugString("ITEM-SYSTEM / ITEM MANAGEMENT / itemconv / NO TABLE FOUND")
		return false
	end
	local brr = { }
	for k, v in ipairs( arr ) do
		brr[k] = {v[1], tostring(v[2]), tostring(v[3]), tonumber(v[4]), v[5]}
	end
	return toJSON(brr)
end

-- send items to a player
local function sendItems( element, to, noload )
	if not noload then
		loadItems( element )
	end
	triggerClientEvent( to, "recieveItems", element, itemconv( saveditems[ element ] ) )
end

-- notify all subscribers on inventory change
local function notify( element, noload )
	if subscribers[ element ] then
		for subscriber in pairs( subscribers[ element ] ) do
			sendItems( element, subscriber, noload )
		end
	end
end

function updateProtection(item, faction, slot, element)
	local success, error = loadItems( element )
	if success then
		if saveditems[element][slot] then
			saveditems[element][slot][4] = faction
			notify( element )
		end
	end
end

-- Free Items Table as necessary
local function destroyInventory( element )
	saveditems[element] = nil
	notify( element )


	-- clear subscriptions
	for key, value in pairs( subscribers ) do
		if value[ element ] then
			value[ element ] = nil
		end
	end

	subscribers[element] = nil
end

addEventHandler( "onElementDestroy", getRootElement(), function() destroyInventory(source) end )
addEventHandler( "onPlayerQuit", getRootElement(), function() destroyInventory(source) end )
addEventHandler( "savePlayer", getRootElement(),
	function( reason )
		if reason == "Change Character" then
			destroyInventory(source)
		end
	end
)

-- subscribe from inventory changes
local function subscribeChanges( element )
	if not isElement(source) or getElementType(source) ~= "player"
		or not isElement(element) then return false end
	subscribers[element] = subscribers[element] or {}
	sendItems(element, source)
	subscribers[element][source] = true
	return true
end

addEvent( "subscribeToInventoryChanges", false )
addEventHandler( "subscribeToInventoryChanges", getRootElement(), subscribeChanges )

-- Send items without subscription
local function sendCurrentInventory( element )
	if not isElement(source) or getElementType(source) ~= "player"
		or not isElement(element) then return false end
	sendItems(element, source)
	return true
end

addEvent( "sendCurrentInventory", false )
addEventHandler( "sendCurrentInventory", getRootElement(), sendCurrentInventory )

-- remove from inventory changes list
local function unsubscribeChanges( element )
	if not isElement(source) or getElementType(source) ~= "player" then return false end
	if subscribers[element] then
		subscribers[element][source] = nil
	end
	triggerClientEvent(source, "recieveItems", element)
	return true
end

addEvent( "unsubscribeFromInventoryChanges", false )
addEventHandler( "unsubscribeFromInventoryChanges", getRootElement(), unsubscribeChanges )

-- returns the 'owner' column content
local function getID(element)
	if getElementType(element) == "player" then -- Player
		return getElementData(element, "dbid")
	elseif getElementType(element) == "vehicle" then -- Vehicle
		return getElementData(element, "dbid")
	elseif getElementParent(getElementParent(element)) == getResourceRootElement(getResourceFromName("item-world")) then -- World Item
		return getElementData(element, "id")
	elseif getElementType(element) == "object" then -- Safe
		return getElementDimension(element)
	elseif getElementType(element) == "ped" then -- Ped
		return getElementData(element, "dbid")
	elseif getElementType(element) == "interior" then
		return getElementData(element, "dbid") -- Interior
	else
		return 0
	end
end

function getElementID(element)
	return getID(element)
end

-- returns the 'type' column content
local function getType(element)
	if getElementType(element) == "player" then -- Player
		return 1
	elseif getElementType(element) == "vehicle" then -- Vehicle
		return 2
	elseif getElementParent(getElementParent(element)) == getResourceRootElement(getResourceFromName("item-world")) then -- World Item
		return 3
	elseif getElementType(element) == "object" then -- Safe
		return 4
	elseif getElementType(element) == "ped" then -- Ped
		return 5
	elseif getElementType(element) == "interior" then -- Interior
		return 6
	else
		return 255
	end
end

-- loads all items for that element
function loadItems( element, force )
	if not isElement( element ) then
		return false, "No element"
	elseif getType(element) == 255 or not tonumber(getID(element))
		or tonumber(getID(element)) ~= tonumber(getID(element))
		or tonumber(getID(element)) == math.huge or tonumber(getID(element)) ~= math.floor(tonumber(getID(element))) then
		return false, "Invalid Element ID"
	elseif force or not saveditems[ element ] then
		saveditems[ element ] = {}
		--notify( element )
		local elementID = tonumber(getID(element))
		local elementType = getType(element)
		local result = mysql:query( "SELECT * FROM items WHERE type = " .. elementType .. " AND owner = " .. elementID .. " ORDER BY `index` ASC" )
		if result then
			local count = 0
			repeat
				local row = mysql:fetch_assoc(result)
				if row then
					count = count + 1
					saveditems[element][count] = {
						tonumber( row.itemID ),
						tonumber( row.itemValue ) or row.itemValue,
						tonumber( row.index ),
						tonumber( row.protected ),
						row.metadata ~= mysql_null() and fromJSON(row.metadata) or nil
					}
				end
			until not row
			mysql:free_result(result)

			if not subscribers[ element ] then
				subscribers[ element ] = {}
				if getElementType( element ) == "player" then
					subscribers[ element ][ element ] = true
				end
			end
			notify( element, true )
			if (getElementType(element) == 'player') then
				triggerEvent("updateLocalGuns", element)
			end
			return true
		else
			notify( element, true )
			return false, "MySQL-Error"
		end
	else
		return true
	end
end

-- load items for all logged in players on resource start
function itemResourceStarted( )
	if getID( source ) then
		loadItems( source )
	end
end
addEvent( "itemResourceStarted", false )
addEventHandler( "itemResourceStarted", getRootElement( ), itemResourceStarted )

-- clear all items for an element
function clearItems( element, onlyifnosqlones )
	if saveditems[element] then
		if onlyifnosqlones and #saveditems[element] > 0 then
			return false
		else
			while #saveditems[ element ] > 0 do
				takeItemFromSlot( element, 1 )
			end

			saveditems[ element ] = nil
			notify( element, true )
		end
	end
	return true
end

-- A special clear items for storage items
function SpecialclearItems( element, onlyifnosqlones )
	if saveditems[element] then
		if onlyifnosqlones and #saveditems[element] > 0 then
			return false
		else
			while #saveditems[ element ] > 0 do
				takeItemFromSlot( element, 1 )
			end

			saveditems[ element ] = nil
			notify( element, true )

			destroyInventory(element)
			if (getElementType(element) == 'player') then
				triggerEvent("updateLocalGuns", element)
			end
		end
	end
	return true
end

-- gives an item to an element
function giveItem( element, itemID, itemValue, itemIndex, isThisFromSplittingOrAdminCmd, metadata )
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 or itemID ~= math.floor(itemID)
		or itemID > 1000 or itemValue == nil
		or (type(itemValue) ~= "string" and type(itemValue) ~= "number") then
		return false, "Invalid item ID or value"
	end
	itemValue = tostring(itemValue)
	if #itemValue > 1024 then return false, "Item value is too long" end
	if itemIndex then
		itemIndex = tonumber(itemIndex)
		if not itemIndex or itemIndex < 1 or itemIndex ~= math.floor(itemIndex) then
			return false, "Invalid item index"
		end
	else
		itemIndex = nil
	end
	local success, error = loadItems(element)
	if success then
		if not metadata then
			if(detailedDebug and sourceResource) then
				local theSource = getResourceName(sourceResource)
				outputDebugString("giveItem: metadata missing (source: "..tostring(theSource)..")", 2)
			end
			metadata = {}
		elseif type(metadata) ~= "table" then
			if detailedDebug then
				local theSource
				if(sourceResource) then
					theSource = getResourceName(sourceResource)
				else
					theSource = "unknown"
				end
				outputDebugString("giveItem: metadata:"..tostring(metadata).." (source: "..tostring(theSource)..")", 2)
			end
			metadata = {}
		end
		local metadataJSON = toJSON(metadata)
		if type(metadataJSON) ~= "string" or #metadataJSON > 8192 then
			return false, "Invalid or oversized item metadata"
		end

		if not hasSpaceForItem(element, itemID, itemValue, metadata) then
			return false, "Inventory is Full."
		end

		if isThisFromSplittingOrAdminCmd then
			if drugList[itemID] then
				if not tonumber(itemValue) or tonumber(itemValue) < 1 then
					return false, "Drug value must be numberic and meant to be in grams."
				else
					itemValue = tostring(itemValue)..drugList[itemID]
				end
			end
		end

		if not itemIndex then
			local result = mysql:query_free("INSERT INTO items (type, owner, itemID, itemValue, metadata) VALUES (" .. getType( element ) .. "," .. getID( element ) .. "," .. itemID .. ",'" .. mysql:escape_string(itemValue) .. "', " .. ("'" .. mysql:escape_string(metadataJSON) .. "'") .. ")")
			if result then
				itemIndex = mysql:insert_id( )
				if itemID == 178 then
					local bInfo = split(tostring(itemValue), ':')
					local bID = bInfo[3]
					if not bID then
						mysql:free_result(mysql:query("INSERT INTO books SET title='".. mysql:escape_string(itemValue) .."', author='Unknown', book='The begining of something great...'"))
						bookIndex = mysql:insert_id( )
						itemValue = itemValue .. ":" .. "Unknown" .. ":" .. tostring(bookIndex)
						mysql:query_free("UPDATE items SET `itemValue`='".. mysql:escape_string(itemValue) .. "' WHERE `index`=".. tonumber(itemIndex) .."")
					end
				end
			else
				return false, "MySQL Error"
			end
		end

		saveditems[element][ #saveditems[element] + 1 ] = { itemID, itemValue, itemIndex, 0, metadata }
		notify( element, true )
		if (getElementType(element) == 'player') then
			if (tonumber(itemID) == 115 or tonumber(itemID) == 116) and (getElementType(element) == 'player') then
				triggerEvent("updateLocalGuns", element)
			end

			doItemGivenChecks(element, tonumber(itemID))
		end
		return true
	else
		outputDebugString("loadItems error: " .. error)
		return false, "loadItems error: " .. error
	end
end

-- takes an item from the element
function takeItem(element, itemID, itemValue)
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then
		return false, "Invalid item ID"
	end
	local success, error = loadItems(element)
	if success then
		local success, slot = hasItem(element, itemID, itemValue)
		if success then
			local removed, removeError = takeItemFromSlot(element, slot)
			if not removed then
				return false, removeError or "Item could not be removed from the database"
			end
			return true
		else
			return false, "Element doesn't have this item"
		end
	else
		return false, "loadItems error: " .. error
	end
end

-- permanently removes an item from an element
function takeItemFromSlot(element, slot, nosqlupdate, no_update_guns)
	slot = tonumber(slot)
	if not slot or slot < 1 or slot ~= math.floor(slot) then return false, "Invalid item slot" end
	local success, error = loadItems(element)
	if success then
		if saveditems[element][slot] then
			local itemID = saveditems[element][slot][1]
			local itemValue = saveditems[element][slot][2]
			local index = saveditems[element][slot][3]
			local success = true
			if not nosqlupdate then
				local result = mysql:query_free( "DELETE FROM items WHERE `index` = " .. index .. " LIMIT 1" )
				--[[if itemID == 178 then
					local query = mysql:query_free( "DELETE FROM books WHERE id = " .. index .. " LIMIT 1")
				end]]
				if not result then
					success = false
				end
			end

			if success then
				-- shift following items from id to id-1 items
				table.remove( saveditems[element], slot )
				notify( element )
				if not no_update_guns and (tonumber(itemID) == 115 or tonumber(itemID) == 116) and (getElementType(element) == 'player')  then
					triggerEvent("updateLocalGuns", element)
				end
				return true
			end
			return false, "Slot does not exist."
		end
	else
		return false, "loadItems error: " .. error
	end
end

-- updates the item value
function updateItemValue(element, slot, itemValue)
	if itemValue == nil or (type(itemValue) ~= "string" and type(itemValue) ~= "number")
		or type(slot) ~= "number" or slot < 1 or slot ~= math.floor(slot) then
		return false, "Invalid item value or slot"
	end
	itemValue = tonumber(itemValue) or tostring(itemValue)
	if #tostring(itemValue) > 1024 then return false, "Item value is too long" end
	local success, error = loadItems(element)
	if success then
		if saveditems[element][slot] then
			if itemValue then
				local itemIndex = saveditems[element][slot][3]
				local updated = dbExec(exports.mysql:getConn('mta'), "UPDATE items SET itemValue=? WHERE `index`=? ", itemValue, itemIndex)
				if not updated then
					return false, "Item value could not be saved"
				end
				saveditems[element][slot][2] = itemValue
				notify(element)
				return true
			else
				return false, "Invalid ItemValue"
			end
		else
			return false, "Slot does not exist."
		end
	else
		return false, "loadItems error: " .. error
	end
end

-- updates the item value
function updateMetadata(element, slot, key, value)
	if not client then return false end
	element = client
	if type(slot) ~= "number" or slot < 1 or slot ~= math.floor(slot)
		or type(key) ~= "string" or #key < 1 or #key > 64 then
		return false
	end
	if getElementType(element) ~= "player" then
		-- this is mostly because we pass the player element to permission checks
		outputDebugString("Can currently not update metadata for non-players.", 2)
		return
	end

	local success, error = loadItems( element )
	if success then
		local item = saveditems[element][slot]
		if item and canOpenMetadataEditor(element, item) then
			local metadata = {}
			if type(item[5]) == "table" then
				for metadataKey, metadataValue in pairs(item[5]) do
					metadata[metadataKey] = metadataValue
				end
			end
			if type(metadata.edited) == "table" then
				local editedCopy = {}
				for editedKey, editedValue in pairs(metadata.edited) do
					editedCopy[editedKey] = editedValue
				end
				metadata.edited = editedCopy
			else
				metadata.edited = {}
			end

			local def = getEditableMetadataInfo(element, item[1], key)
			if not def then
				return false, "no metadata " .. tostring(key)
			elseif def.type == "string" and type(value) ~= "string" then
				return false, "metadata type mismatch #1"
			elseif def.type == "integer" and (type(value) ~= "number" or value ~= value
				or value == math.huge or value == -math.huge or value ~= math.floor(value)) then
				return false, "metadata type mismatch #2"
			elseif def.type == "string" and #value > 1024 then
				return false, "metadata value is too long"
			elseif def.type == "table" and type(value) ~= "table" then
				return false, "metadata type mismatch #3"
			elseif def.type ~= "string" and def.type ~= "integer" and def.type ~= "table" then
				return false, "unsupported metadata"
			end

			-- make sure we at least have a table of some sorts to save the item
			if type(metadata) ~= "table" then
				metadata = { [key] = value }
			else
				metadata[key] = value
			end
			
			metadata.edited[key] = true

			local any = false
			for _, _ in pairs(metadata) do
				any = true
				break
			end

			if not any then
				metadata = nil
			end

			local itemIndex = item[3]
			local updated
			if metadata == nil then
				updated = dbExec( exports.mysql:getConn('mta'), "UPDATE items SET metadata=NULL WHERE `index`=? ", itemIndex )
			else
				local encodedMetadata = toJSON(metadata)
				if not encodedMetadata or #encodedMetadata > 8192 then
					return false, "metadata is invalid or too large"
				end
				updated = dbExec( exports.mysql:getConn('mta'), "UPDATE items SET metadata=? WHERE `index`=? ", encodedMetadata, itemIndex )
			end
			if not updated then return false, "metadata could not be saved" end
			saveditems[element][slot][5] = metadata
			notify( element )
			return true
		else
			return false, "Slot does not exist."
		end
	else
		return false, "loadItems error: " .. error
	end
end
addEvent("items:metadata:update", true)
addEventHandler("items:metadata:update", root, updateMetadata)

-- moves an item from any element to another element
function moveItem2(from, to, slot)
	moveItem(from, to, slot)
end

function moveItem(from, to, slot)
	if not isElement(from) or not isElement(to) or from == to
		or type(slot) ~= "number" or slot < 1 or slot ~= math.floor(slot) then
		return false, "Invalid inventory transfer"
	end
	local loaded, loadError = loadItems(from)
	if not loaded then return false, "loadItems(from) error: " .. tostring(loadError) end
	loaded, loadError = loadItems(to)
	if not loaded then return false, "loadItems(to) error: " .. tostring(loadError) end

	local item = saveditems[from] and saveditems[from][slot]
	if not item then return false, "Slot does not exist." end
	local itemID, itemValue, itemIndex, protected, metadata = item[1], item[2], item[3], item[4], item[5]
	if not itemIndex then return false, "Invalid item index" end
	if itemID == 48 or itemID == 126 or itemID == 60 or itemID == 103 or itemID == 163 then
		return false, "This Item cannot be moved"
	end
	if not hasSpaceForItem(to, itemID, itemValue, metadata) then
		return false, "Target does not have Space for Item."
	end

	-- Detect duplicated weapons before changing the database owner.
	if itemID == 115 or itemID == 116 then
		local target = getElementType(to) == "player" and to or from
		if isThisGunDuplicated(itemID, itemValue, target) then
			takeItemFromSlot(from, slot, false)
			outputChatBox("This weapon was duplicated by bug abuser and can not be used anymore. We're sorry to delete it now.", target, 255, 0, 0)
			return false, "Weapon ID#" .. tostring(itemIndex) .. " duplicate detected and deleted."
		end
	end

	-- Anti-alt-alt restrictions must run before the database owner is changed.
	if ((itemID >= 31 and itemID <= 43) or itemBannedByAltAltChecker[itemID]) then
		local fromATM = getElementType(from) == "object" and getElementModel(from) == 2942
		local toATM = getElementType(to) == "object" and getElementModel(to) == 2942
		if itemID == 150 and (fromATM or toATM) then
			-- ATM card transfers are allowed through the ATM interface.
		else
			local hoursPlayedFrom = tonumber(getElementData(from, "hoursplayed")) or 99
			local hoursPlayedTo = tonumber(getElementData(to, "hoursplayed")) or 99
			if not exports.global:isStaffOnDuty(to) and not exports.global:isStaffOnDuty(from) then
				if hoursPlayedFrom < 10 then
					outputChatBox("You require 10 hours of playing time to move a " .. getItemName(itemID) .. " to a " .. getName(to) .. ".", from, 255, 0, 0)
					return false, "Item move cancelled, < 10 hours"
				end
				if hoursPlayedTo < 10 then
					local ownsKeyVehicle = false
					if itemID == 3 then
						local keyVehicle = exports.pool:getElement("vehicle", itemValue)
						ownsKeyVehicle = isElement(keyVehicle)
							and tonumber(getElementData(keyVehicle, "owner")) == tonumber(getElementData(from, "dbid"))
					end
					if not ownsKeyVehicle then
						outputChatBox("You require 10 hours of playing time to receive a " .. getItemName(itemID) .. " from a " .. getName(from) .. ".", to, 255, 0, 0)
						return false, "Item move cancelled, < 10 hours"
					end
				end
			end
		end
	end

	-- Cash items are converted to account cash, so delete the inventory row
	-- only after the recipient has successfully received the money.
	if itemID == 134 then
		if getElementType(from) == "player" then
			return false, "Player cash balance items must be transferred through the cash transfer flow"
		end
		local amount = tonumber(itemValue)
		if not amount or amount ~= amount or amount == math.huge or amount <= 0 then
			return false, "Invalid cash item value"
		end
		if not exports.global:giveMoney(to, amount) then
			return false, "Could not give cash to the recipient"
		end
		if not takeItemFromSlot(from, slot, false) then
			if not exports.global:takeMoney(to, amount) then
				outputDebugString("[item-system] Cash transfer rollback failed for item " .. tostring(itemIndex), 1)
			end
			return false, "Could not remove the cash item from the sender"
		end
		return true
	end

	local fromType, fromID = getType(from), tonumber(getID(from))
	local toType, toID = getType(to), tonumber(getID(to))
	if fromType == 255 or toType == 255 or not fromID or not toID then
		return false, "Invalid inventory owner"
	end
	local query = mysql:query_free("UPDATE items SET type = " .. toType .. ", owner = " .. toID
		.. " WHERE `index` = " .. tonumber(itemIndex) .. " AND type = " .. fromType .. " AND owner = " .. fromID)
	if not query then return false, "MySQL-Query failed." end

	table.remove(saveditems[from], slot)
	saveditems[to][#saveditems[to] + 1] = { itemID, itemValue, itemIndex, protected, metadata }
	notify(from, true)
	notify(to, true)
	if itemID == 115 or itemID == 116 then
		if getElementType(from) == "player" then triggerEvent("updateLocalGuns", from) end
		if getElementType(to) == "player" then triggerEvent("updateLocalGuns", to) end
	end
	return true
end
-- checks if the element has that specific item
-- returns bool hasItem, int slot, int/string itemValue, int index, table/nil metadata
function hasItem(element, itemID, itemValue)
	local success, error = loadItems( element )
	if success then
		for key, value in pairs(saveditems[element]) do
			if value[1] == itemID and ( not itemValue or itemValue == value[2] ) then
				return true, key, value[2], value[3], value[5]
			end
		end
		return false
	else
		return false, "loadItems error: " .. error
	end
end

-- checks if the element has space for adding a new item
function hasSpaceForItem(element, itemID, itemValue, metadata)
	local success, error = loadItems( element )
	if success then
		local carriedWeight = getCarriedWeight(element) or false
		local itemWeight = getItemWeight(itemID, itemValue or 1, metadata) or false
		local maxWeight = getMaxWeight(element) or false
		if itemWeight > 20 and getElementType(element) == 'player' and exports.integration:isPlayerTrialAdmin(element, true) then
			return true
		end
		if carriedWeight and itemWeight and maxWeight then
			return carriedWeight + itemWeight <= maxWeight
		else
			return false, "Can't get carriedWeight or itemWeight or maxWeight"
		end
	else
		return false, "loadItems error: " .. error
	end
end

-- count all instances of that object
function countItems( element, itemID, itemValue )
	local success, error = loadItems( element )
	if success then
		local count = 0
		for key, value in pairs(saveditems[element]) do
			if value[1] == itemID and ( not itemValue or itemValue == value[2] ) then
				count = count + 1
			end
		end
		return count
	else
		return 0, "loadItems error: " .. error
	end
end

-- returns a list of all items of that element
function getItems(element)
	local success = loadItems(element)
	if success then
		return saveditems[element]
	end
	return false
end


-- returns the current weight an element carries
function getCarriedWeight(element, itemId)
	local success, error = loadItems( element )
	if success then
		local weight = 0
		for key, value in ipairs(saveditems[element]) do
			if not itemId or itemId == value[1] then
				weight = weight + getItemWeight(value[1], value[2], value[5])
			end
		end
		return weight
	else
		return 1000000, "loadItems error: " .. error -- Obviously too large to pick anything further up :o Yet if it fails that might even be good since we assume "if not loaded, can't happen"
	end
end

function getMaxWeight(element)
	if getElementType( element ) == "player" then
		return getPlayerMaxCarryWeight( element )
	elseif getElementType( element ) == "vehicle" then
		-- civ
		if getID( element ) < 0 then
			return -1
		else
			-- RS haul trucks exceptions
			if getElementData(element, 'job') == 1 then
				return tonumber(exports["job-system-trucker"]:getTruckCapacity(element)) or 1000
			elseif getElementModel( element ) == 530 then --forklift
				return 1
			elseif getVehicleType( element ) == "BMX" then
				return 1
			elseif getVehicleType( element ) == "Bike" then
				return 10
			elseif isVan( element ) then
				return 80
			elseif isTruck( element ) then
				return 120
			elseif isSUV( element ) then
				return 75
			elseif isTrailer( element ) then
				return 350
			end
		end
		-- sedan and others
		return 20
	--ATM machine
	elseif (getElementType( element ) == "object") and (getElementModel(element) == 2942) then
		return 0.1
	elseif (getElementParent(getElementParent(element)) == getResourceRootElement(getResourceFromName("item-world"))) then -- World Item
		local itemID = tonumber(getElementData(element, "itemID")) or 0
		--video system
		if itemID == 166 then
			return 0.1
		end
		return getElementModel(element) == 2147 and 50 or getElementModel(element) == 3761 and 100 or getElementData(element, "itemID") == 223 and tonumber(split(getElementData(element, "itemValue"), ":")[3]) or 10
	elseif getElementType( element ) == "interior" then
		return 500
	else
		return 20
	end
end



-- delete all instances of an item from all inventories and maps of all dimensions, return number of deleted items/objects.
function deleteAll( itemID, itemValue )
	local count = 0
	if itemID then
		itemID = tonumber(itemID) or itemID
		itemValue = tonumber(itemValue) or itemValue

		-- make sure it's erased from the db
		dbExec( exports.mysql:getConn('mta'), "DELETE FROM items WHERE itemID=? "..( itemValue and "AND itemValue=? " or "" ), itemID, itemValue or nil )

		-- delete from all storages
		if saveditems then
			for value in pairs( saveditems ) do
				if isElement( value ) then
					while hasItem( value, itemID, itemValue ) do
						if takeItem( value, itemID, itemValue ) then
							count = count + 1
						end
					end
				end
			end
		end

		-- remove world items
		if exports.global:isResourceRunning( 'item-world' ) then
			count = count + exports['item-world']:deleteAll( itemID, itemValue )
		end
	end
	return count
end

-- DELETE ALL ITEMS WITHIN AN INT - MAXIME
function deleteAllItemsWithinInt( intID , dayOld, CLEANUPINT )
	if not dayOld then dayOld = 0 end
	-- make sure it's erased from the db
	if intID then
		local row = {}
		local query2 = false
		local success = false
		if CLEANUPINT ~= "CLEANUPINT" then
			query2 = mysql:query("SELECT `id` FROM `worlditems` WHERE `dimension` = '" .. mysql:escape_string( tostring( intID ) ) .. "' AND DATEDIFF(NOW(), creationdate) >= '"..mysql:escape_string( tostring( dayOld ) ) .."' AND `itemID` != 81 AND `itemID` != 103 AND protected = 0" )
			if mysql:query_free("DELETE FROM `worlditems` WHERE `dimension` = '" .. mysql:escape_string( tostring( intID ) ) .. "' AND DATEDIFF(NOW(), creationdate) >= '"..mysql:escape_string( tostring( dayOld ) ) .."' AND `itemID` != 81 AND `itemID` != 103 AND protected = 0" ) then
				success = true
			end
		else
			query2 = mysql:query("SELECT `id` FROM `worlditems` WHERE `dimension` = '" .. mysql:escape_string( tostring( intID ) ) .. "'" )
			if mysql:query_free("DELETE FROM `worlditems` WHERE `dimension` = '" .. mysql:escape_string( tostring( intID ) ) .. "'" ) then
				success = true
			end
		end

		if query2 then
			while true do
				local row = mysql:fetch_assoc(query2)
				if not row then break end
				for key, value in ipairs(getElementsByType("object", getResourceRootElement(getResourceFromName("item-world")))) do
					if isElement( value ) then
						if tonumber(getElementData( value, "id" )) == tonumber(row["id"]) then
							destroyElement( value )
						end
					end
				end
			end
			mysql:free_result(query2)
		end

		if success then
			return true
		else
			return false
		end
	else
		return false
	end
end

-- CONVERSION

function convertGenerics(world)
	-- define the variables based on which items we're converting, either world or inventory
	local idValue = (world and "id" or "index")
	local valueRow = (world and "itemvalue" or "itemValue")
	local affectedResource = (world and "item-world" or "item-system")
	local queryStr = (world and "SELECT * FROM worlditems WHERE itemid = 80" or "SELECT * FROM items WHERE itemID = 80")
	local updateStr = (world and "UPDATE worlditems SET itemvalue = 1, metadata = ? WHERE id = ?" or "UPDATE items SET itemValue = 1, metadata = ? WHERE items.index = ?")
	
	outputDebugString("[ITEM-MANAGEMENT] Converting all generic items in the " .. affectedResource .. " ...")
	
	local counter = 0
	dbQuery(function(qh)
		local res, rows, err = dbPoll(qh,0)
		if rows > 0 then
			for _, row in pairs(res) do
				if row then
					local itemValue, metadata = exports.global:explode(":", row[valueRow]), {}
					if itemValue[1] then
						metadata['item_name'] = itemValue[1]
						counter = counter + 1
					end
					if itemValue[2] then
						metadata['model'] = itemValue[2]
					end
					if itemValue[3] then
						metadata['scale'] = itemValue[3]
					end
					if itemValue[4] and itemValue[5] then
						metadata['url'] = "http://" .. itemValue[4]
						metadata['texture'] = itemValue[5]
					end
					dbExec(mysql:getConn('mta'), updateStr, toJSON(metadata), row[idValue])
				end
			end
			
			outputDebugString("[ITEM-MANAGEMENT] " .. counter .. " items have been converted, restarting " .. affectedResource .. " ...")
			restartResource(getResourceFromName(affectedResource))
			
			-- output a message once the affected resource has been started
			local function outputItemWorldStart(resource)
				if resource == getResourceFromName(affectedResource) then
					outputDebugString("[ITEM-MANAGEMENT] Successfully restarted " .. affectedResource .. ", loading all items ...")
					removeEventHandler("onResourceStart", getRootElement(), outputItemWorldStart)
				end
			end
			addEventHandler("onResourceStart", getRootElement(), outputItemWorldStart)
		end
	end, mysql:getConn('mta'), queryStr)
end

function commandConvertGenerics(player, cmd)
	if exports.integration:isPlayerScripter(player) then
		local seconds = 30
		outputChatBox(" WARNING: Large script execution will take place in " .. seconds .. " seconds, it will cause major delays for a few minutes.", root, 255, 0, 0)
		setTimer(convertGenerics, seconds*1000, 1, (cmd == "convertworld"))
	end
end
addCommandHandler("convertworld", commandConvertGenerics)
addCommandHandler("convertitem", commandConvertGenerics)
