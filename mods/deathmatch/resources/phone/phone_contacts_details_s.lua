--MAXIME
function getOwnedContactPhone(player, contactID)
	contactID = tonumber(contactID)
	if not player or not contactID or contactID < 1 or contactID ~= math.floor(contactID) then return false end
	local row = mysql:query_fetch_assoc("SELECT `phone` FROM `phone_contacts` WHERE `id`="..contactID.." LIMIT 1")
	local phone = row and tonumber(row.phone)
	if not phone or not exports.global:hasItem(player, 2, phone) then return false end
	return phone
end

function updateContactDetails(id, name, number, email, address, favo)
	local player = client
	local phone = getOwnedContactPhone(player, id)
	if not phone or type(name) ~= "string" or #name < 1 or #name > 50
		or type(number) ~= "string" and type(number) ~= "number"
		or not tostring(number):match("^%d%d%d%d%d%d?%d?%d?%d?%d?%d?%d?%d?%d?$")
		or (email ~= nil and (type(email) ~= "string" or #email > 100))
		or (address ~= nil and (type(address) ~= "string" or #address > 200))
		or (tonumber(favo) ~= 0 and tonumber(favo) ~= 1) then
		return false
	end
	local success = dbExec(mysql:getConn("mta"),
		"UPDATE `phone_contacts` SET `entryName`=?, `entryNumber`=?, `entryEmail`=?, `entryAddress`=?, `entryFavorited`=? WHERE `id`=? AND `phone`=?",
		name, tostring(number), email or "", address or "", tonumber(favo), tonumber(id), phone)
	triggerClientEvent(player, "phone:contacts:details:update:response", player,
		success and id or false, name, number, email, address, favo)
	return success
end
addEvent("phone:contacts:details:update", true)
addEventHandler("phone:contacts:details:update", root, updateContactDetails)

function deleteContact(id)
	local player = client
	local phone = getOwnedContactPhone(player, id)
	if not phone then return false end
	local success = dbExec(mysql:getConn("mta"),
		"DELETE FROM `phone_contacts` WHERE `id`=? AND `phone`=?", tonumber(id), phone)
	triggerClientEvent(player, "phone:contacts:details:delete:response", player, success and id or false)
	return success
end
addEvent("phone:contacts:details:delete", true)
addEventHandler("phone:contacts:details:delete", root, deleteContact)