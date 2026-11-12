--MAXIME
--[[
state = 1 | caller = outgoing | called = missed
state = 2 | caller = outgoing | called = not exited or out of service or turned off so do not list
state = 3 | caller = outgoing | called = incoming.
]]
addedPhoneHistories = {}
function addPhoneHistory(from, to, state, private)
	from = tonumber(from)
	to = tonumber(to)
	state = tonumber(state)
	private = tonumber(private) == 1 and 1 or 0
	addedPhoneHistories[to] = mysql:query_insert_free("INSERT INTO `phone_history` SET `from`='"..from.."', `to`='"..to.."', `state`='"..state.."', private="..private)
end

function updatePhoneHistoryState(to, state)
	to = tonumber(to)
	state = tonumber(state)
	if mysql:query_free("UPDATE `phone_history` SET `state`='"..state.."' WHERE `to`='"..to.."'   ") then
		addedPhoneHistories[to] = nil
	end
end

function getHistoryData(fromPhone, forceUpdateContactList1, xoffset, yoffset)
	local player = client
	fromPhone = tonumber(fromPhone)
	if not player or not isElement(player) or tonumber(getElementData(player, "loggedin")) ~= 1
		or not fromPhone or fromPhone < 10000 or fromPhone ~= math.floor(fromPhone)
		or not exports.global:hasItem(player, 2, fromPhone) then
		return false
	end
	if forceUpdateContactList1 == true then
		forceUpdateContactList(player, fromPhone)
	end
	xoffset = math.max(-10000, math.min(10000, tonumber(xoffset) or 0))
	yoffset = math.max(-10000, math.min(10000, tonumber(yoffset) or 0))
	local limit = 9
	local results = {}
	local condition = "(`from`='"..fromPhone.."' OR `to`='"..fromPhone.."') AND !(`state`=2 AND `to`='"..fromPhone.."') "
	local result = mysql:query("SELECT *, TO_SECONDS(`date`) AS `datesec` FROM `phone_history` WHERE "..condition.." ORDER BY `date` DESC LIMIT "..limit)
	while result do
		local row = mysql:fetch_assoc(result)
		if not row then break end
		table.insert(results, row)
	end
	if result then mysql:free_result(result) end
	triggerClientEvent(player, "phone:refreshHistory", player, results, xoffset, yoffset, true)
	mysql:query_free("DELETE FROM `phone_history` WHERE DATEDIFF(NOW(),`date`) > 30")
	return true
end
addEvent("phone:getHistoryData", true)
addEventHandler("phone:getHistoryData", root, getHistoryData)