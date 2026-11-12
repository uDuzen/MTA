--MAXIME

addEvent("phone:addContact", true)
function addPhoneContact(name, number, phoneBookPhone)
	if client then
		phoneBookPhone = tonumber(phoneBookPhone)
		if not isElement(client) or tonumber(getElementData(client, "loggedin")) ~= 1
			or not phoneBookPhone or phoneBookPhone < 10000 or phoneBookPhone ~= math.floor(phoneBookPhone)
			or type(name) ~= "string" or #name < 1 or #name > 50
			or (type(number) ~= "string" and type(number) ~= "number")
			or not tostring(number):match("^%d%d%d%d%d%d?%d?%d?%d?%d?%d?%d?%d?%d?$") then
			triggerClientEvent(client, "phone:addContactResponse", client, false)
			return false
		end
		if not phoneBookPhone then
			triggerClientEvent(client, "phone:addContactResponse", client, false)
			return
		end
		
		if not exports.global:hasItem(client,2, tonumber(phoneBookPhone)) then
			triggerClientEvent(client, "phone:slidePhoneOut", client)
			return
		end
		
		if name and number then
			if tonumber(number) then
				local insertedId = mysql:query_insert_free("INSERT INTO `phone_contacts` (`phone`, `entryName`, `entryNumber`) VALUES ('" ..  mysql:escape_string(tostring(phoneBookPhone)).."', '".. mysql:escape_string(name) .."', '".. mysql:escape_string(number) .."')") 
				if insertedId then
					triggerClientEvent(client, "phone:addContactResponse", client, insertedId, name, number)
					return
				end
			end
		end

		outputChatBox("Internal Error! Code: RFS45235, please report this on http://bugs.owlgaming.net.", client, 255,0,0)
		triggerClientEvent(client, "phone:addContactResponse", client, false)
	end
end
addEventHandler("phone:addContact", getRootElement(), addPhoneContact)