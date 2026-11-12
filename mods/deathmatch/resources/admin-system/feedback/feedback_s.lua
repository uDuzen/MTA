--MAXIME / 2015.1.29
--[[
-- Dumping structure for table mta.feedbacks
CREATE TABLE IF NOT EXISTS `feedbacks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `staff_id` int(11) NOT NULL,
  `from_id` int(11) NOT NULL,
  `rating` int(11) NOT NULL DEFAULT '3',
  `comment` varchar(500) DEFAULT NULL,
  `date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=117903 DEFAULT CHARSET=latin1;
]]

local mysql = exports.mysql
function formSubmit(staffId, rating, comment)
	local player = client
	staffId = tonumber(staffId)
	rating = tonumber(rating)
	local accountID = player and tonumber(getElementData(player, "account:id"))
	if not player or not isElement(player) or tonumber(getElementData(player, "loggedin")) ~= 1
		or not accountID or not staffId or staffId < 1 or staffId ~= math.floor(staffId)
		or not rating or rating < 1 or rating > 5 or rating ~= math.floor(rating)
		or (comment ~= nil and (type(comment) ~= "string" or #comment > 500)) then
		return false
	end
	local qh = dbQuery(exports.mysql:getConn("core"),
		"SELECT id FROM accounts WHERE id = ? AND (admin > 0 OR supporter > 0 OR vct > 0 OR scripter > 0 OR mapper > 0 OR fmt > 0) LIMIT 1",
		staffId)
	local result = dbPoll(qh, 10000)
	if not result or not result[1] then
		outputChatBox("Feedback has failed to submit. Thank you for taking the time to give us your feedback anyway.", player, 255, 0, 0)
		return false
	end
	local success = dbExec(exports.mysql:getConn("mta"),
		"INSERT INTO feedbacks (staff_id, rating, from_id, comment) VALUES (?, ?, ?, ?)",
		staffId, rating, accountID, comment)
	if success then
		outputChatBox("Feedback has successfully submitted. Thank you for taking the time to give us your feedback.", player, 0, 255, 0)
		return true
	end
	outputChatBox("Feedback has failed to submit. Thank you for taking the time to give us your feedback anyway.", player, 255, 0, 0)
	return false
end
addEvent("feedback:formSubmit", true)
addEventHandler("feedback:formSubmit", root, formSubmit)

function openFeedBackDetails(staff)
	local player = client or source
	if not isElement(player) or (type(staff) ~= "string" and type(staff) ~= "number") then return false end
	staff = tostring(staff)
	if #staff < 1 or #staff > 64 then return false end
	local sql = "SELECT id, username FROM accounts WHERE username='"..mysql:escape_string(staff).."'"
	if tonumber(staff) then
		local staffID = tonumber(staff)
		if staffID < 1 or staffID ~= math.floor(staffID) then return false end
		sql = "SELECT id, username FROM accounts WHERE id="..staffID
	end
	local target = mysql:query_fetch_assoc(sql)
	if target and target.id and tonumber(target.id) then
		target.id = tonumber(target.id)
		if target.id ~= tonumber(getElementData(player, "account:id")) and not exports.integration:isPlayerLeadAdmin(player) then
			return outputChatBox("You don't have sufficient permissions to view feedbacks of this staff member.", player, 255,0,0)
		end
		local feedbacks = {}
		local q = mysql:query("SELECT username, rating, comment, DATE_FORMAT(date,'%b %d, %Y %h:%i %p') AS date FROM feedbacks f LEFT JOIN accounts a ON f.from_id=a.id WHERE f.staff_id="..target.id.." ORDER BY f.id DESC")
		while q do
			local row = mysql:fetch_assoc(q)
			if not row then break end
			table.insert(feedbacks, row)
		end
		triggerClientEvent(player, "feedback:openFeedBackDetails", player, {feedbacks, target.username})
		return true
	end
	return false
end
addEvent("feedback:openFeedBackDetails", true)
addEventHandler("feedback:openFeedBackDetails", root, openFeedBackDetails)

function showFeedbacks(player, cmd, ...)
	if (...) then
		if not exports.integration:isPlayerLeadAdmin(player) then
			return outputChatBox("You don't have sufficient permissions to view other staff's feedbacks.", player, 255,0,0)
		end
		triggerEvent("feedback:openFeedBackDetails", player, table.concat({...}," "))
	else
		triggerEvent("feedback:openFeedBackDetails", player, getElementData(player, "account:id"))
	end
end
--addCommandHandler("showfeedbacks", showFeedbacks)
