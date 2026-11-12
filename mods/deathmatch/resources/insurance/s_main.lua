local mysql = exports.mysql

local datatable = { } -- key: vehicleID
local factionstable = { } -- key: factionID
local pendingInsuranceQuotes = {}
local pendingInsuranceSales = {}

local function getCurrentInsuranceFaction(player)
	if not isElement(player) or getElementType(player) ~= "player"
		or tonumber(getElementData(player, "loggedin")) ~= 1 then return false end
	local factionID = tonumber(exports.factions:getCurrentFactionDuty(player))
	if not factionID or not factionstable[factionID]
		or not exports.factions:isPlayerInFaction(player, factionID) then return false end
	return factionID
end

local function isInsuranceManager(player, factionID)
	return getCurrentInsuranceFaction(player) == tonumber(factionID)
		and exports.factions:hasMemberPermissionTo(player, tonumber(factionID), "manage_finance")
end

function updateClientCache(updateTo, newTalbes)
	triggerClientEvent(updateTo, "insurance:updateClientCache", updateTo, newTalbes)
end

addEventHandler("onResourceStart", resourceRoot,
	function()
		local result = mysql:query( "SELECT `factionID`, `name`, `gen_maxi`, `news`, `subscription` FROM `insurance_factions`" )
		while result do
			local row = mysql:fetch_assoc( result )
			if not row then
				break
			end
			factionstable[tonumber(row.factionID)] = row
		end
		mysql:free_result( result )

		local result = mysql:query( "SELECT * FROM `insurance_data`" )
		while result do
			local row = mysql:fetch_assoc( result )
			if not row then
				break
			end
			datatable[tonumber(row.vehicleid)] = row
		end
		mysql:free_result( result )

		setTimer( sqlSaveDatatable, 18000000, 0) -- every 5 hours

	end)

function getVehicleInsuranceData(vin) --exported function to get insurance data on a vehicle. False if vehicle is not insured. /Exciter
	if tonumber(vin) then
		vin = tonumber(vin)
		if datatable[vin] then
			local data = datatable[vin]
			local insuredByName = factionstable[tonumber(data.insurancefaction)].name or ""
			data["insurancecompanyname"] = insuredByName
			return data
		end
	end
	return false
end

function openGUI(thePlayer)
	local faction = exports.factions:getCurrentFactionDuty(thePlayer)
	--outputDebugString("insurance/s_main: openGUI f="..tostring(faction).." t="..tostring(factionstable))
	--outputDebugString(tostring(factionstable[faction]))
	if faction and factionstable[faction] then
		updateClientCache(thePlayer, {datatable, factionstable})
		triggerClientEvent(thePlayer, "insurance:mainGUI", resourceRoot, factionstable[faction]) -- ya , but this function can bring with it the tables to client too
	end
end
addCommandHandler("insurance", openGUI)

function doSqlStuff(sqlType, factionID, newdata)
	local player = client
	factionID = tonumber(factionID)
	local allowedColumns = { news = true, subscription = true, gen_maxi = true }
	if not player or not isInsuranceManager(player, factionID)
		or not allowedColumns[sqlType] or not factionstable[factionID] then return false end
	if sqlType == "gen_maxi" then
		newdata = tonumber(newdata)
		if not newdata or newdata < 0.0001 or newdata > 0.1 then return false end
	else
		if type(newdata) ~= "string" or #newdata > 5000 then return false end
	end
	if not dbExec(mysql:getConn("mta"), "UPDATE `insurance_factions` SET `"..sqlType.."`=? WHERE `factionID`=?", newdata, factionID) then
		return false
	end
	factionstable[factionID][sqlType] = newdata
	updateClientCache(player, {datatable, factionstable})
	return true
end
addEvent("insurance:sql", true)
addEventHandler("insurance:sql", resourceRoot, doSqlStuff)

function calculatePremium(carshopPrice, maxigen, change)
	if not carshopPrice then return false end
	carshopPrice = tonumber(carshopPrice)

	local basePrice = carshopPrice * tonumber(maxigen)

	if tonumber(change) then
		local advancedPrice = basePrice * change
		return math.ceil(advancedPrice)
	else
		return math.ceil(basePrice)
	end
end

function getVehicleData(id)
	if not id then return false end
	local theVehicle = exports.pool:getElement("vehicle", tonumber(id))
	if not theVehicle then return false end

	if theVehicle then -- if vehicle element is found
		local plate = getElementData(theVehicle, "plate") or "false_plate"
		local owner = getElementData(theVehicle, "owner")
		local ownerName = exports['cache']:getCharacterName(owner, true) or "REF. SUP."
		local brand = getElementData(theVehicle, "brand") or "false_brand"
		local model = getElementData(theVehicle, "maximemodel") or "false_model"
		local year = getElementData(theVehicle, "year") or "false_year"
		local carshopPrice = getElementData(theVehicle, "carshop:cost") or 0

		return tonumber(carshopPrice), brand, model, year, ownerName, plate
	end
end

function sellInfo(id)
	local player = client
	local factionID = getCurrentInsuranceFaction(player)
	id = tonumber(id)
	if not factionID or not id or id < 1 or id ~= math.floor(id) then return false end
	local price, brand, model, year, owner, plate = getVehicleData(id)
	if brand and model and year and owner then
		triggerClientEvent(player, "insurance:clientrecieve:sell", player, owner, year, brand, model)
		return true
	end
	return false
end
addEvent("insurance:sellinfo", true)
addEventHandler("insurance:sellinfo", root, sellInfo)

function calculateFromClient(id, factionID, charge)
	local player = client
	id = tonumber(id)
	factionID = tonumber(factionID)
	if not player or not id or id < 1 or id ~= math.floor(id)
		or not factionID or getCurrentInsuranceFaction(player) ~= factionID
		or not factionstable[factionID] then return false end
	local price, brand, model, year, name, plate = getVehicleData(id)
	if not price then return false end
	local estimatedpremium = calculatePremium(price, factionstable[factionID]["gen_maxi"])
	local premium
	if charge == "faction" then
		premium = estimatedpremium
	else
		charge = tonumber(charge)
		if not charge or charge < 0.1 or charge > 10 then return false end
		premium = calculatePremium(price, factionstable[factionID]["gen_maxi"], charge)
	end
	pendingInsuranceQuotes[player] = {
		vehicleID = id, factionID = factionID, premium = premium,
		expires = getTickCount() + 120000
	}
	triggerClientEvent(player, "insurance:clientrecieve", player, name, year, brand, model, plate, price, estimatedpremium, premium)
	return true
end
addEvent("insurance:calculate", true)
addEventHandler("insurance:calculate", root, calculateFromClient)

function sellPremium(customerId, price, vehicle, protection)
	local salesman = client
	local customer = customerId
	local quote = salesman and pendingInsuranceQuotes[salesman]
	price = tonumber(price)
	vehicle = tonumber(vehicle)
	local factionID = getCurrentInsuranceFaction(salesman)
	if not factionID or not isElement(customer) or getElementType(customer) ~= "player"
		or tonumber(getElementData(customer, "loggedin")) ~= 1
		or not price or price < 1 or price > 50000 or price ~= math.floor(price)
		or not vehicle or vehicle < 1 or vehicle ~= math.floor(vehicle)
		or type(protection) ~= "string" or #protection < 1 or #protection > 256
		or not quote or quote.vehicleID ~= vehicle or quote.factionID ~= factionID
		or quote.expires < getTickCount() or quote.premium ~= price then
		return false
	end
	local theVehicle = exports.pool:getElement("vehicle", vehicle)
	if not isElement(theVehicle) or tonumber(getElementData(theVehicle, "owner")) ~= tonumber(getElementData(customer, "dbid"))
		or datatable[vehicle] then return false end
	local carshop, brand, model, year, ownerName, plate = getVehicleData(vehicle)
	if not brand or not model or not year then return false end
	pendingInsuranceSales[customer] = {
		salesman = salesman, vehicleID = vehicle, protection = protection,
		premium = price, factionID = factionID, expires = getTickCount() + 120000
	}
	triggerClientEvent(customer, "insurance:confirmgui", root, tostring(price), year.." "..brand.." "..model, salesman, vehicle, protection)
	return true
end
addEvent("insurance:sell", true)
addEventHandler("insurance:sell", root, sellPremium) -- yeah so source can be player

function clientSideOutputChatBox(element, message)
	local player = client
	local sale = player and pendingInsuranceSales[player]
	if not sale or sale.salesman ~= element or sale.expires < getTickCount()
		or type(message) ~= "string" or #message > 200 then return false end
	if isElement(element) then outputChatBox(message, element) end
	pendingInsuranceSales[player] = nil
	return true
end
addEvent("insurance:outputchatbox", true)
addEventHandler("insurance:outputchatbox", resourceRoot, clientSideOutputChatBox)

function finalizePurchase(salesman, customer, carid, protection, premium, factionid)
	local buyer = client
	local sale = buyer and pendingInsuranceSales[buyer]
	carid = tonumber(carid)
	premium = tonumber(premium)
	factionid = tonumber(factionid)
	if not buyer or not isElement(buyer) or tonumber(getElementData(buyer, "loggedin")) ~= 1
		or not sale or sale.expires < getTickCount()
		or sale.salesman ~= salesman or sale.vehicleID ~= carid
		or sale.protection ~= protection or sale.premium ~= premium
		or sale.factionID ~= factionid or not isElement(salesman)
		or getCurrentInsuranceFaction(salesman) ~= factionid then
		return false
	end
	local theVehicle = exports.pool:getElement("vehicle", carid)
	local buyerID = tonumber(getElementData(buyer, "dbid"))
	if not isElement(theVehicle) or not buyerID
		or tonumber(getElementData(theVehicle, "owner")) ~= buyerID or datatable[carid] then
		return false
	end
	local realTime = getRealTime()
	local date = string.format("%04d/%02d/%02d", realTime.year + 1900, realTime.month + 1, realTime.monthday)
	local customerName = string.gsub(getPlayerName(buyer), "_", " ")
	local q = mysql:query("INSERT INTO `insurance_data` (`customername`, `vehicleid`, `protection`, `deductible`, `date`, `claims`, `cashout`, `premium`, `insurancefaction`) VALUES ('"
		..mysql:escape_string(customerName).."', "..carid..", '"..mysql:escape_string(protection).."', 0, '"
		..date.."', 0, 0, "..premium..", "..factionid..")")
	if not q then return false end
	local newid = mysql:insert_id()
	mysql:free_result(q)
	if not newid then return false end
	exports.anticheat:setEld(theVehicle, "insurance:fee", premium)
	exports.anticheat:setEld(theVehicle, "insurance:faction", factionid)
	datatable[carid] = {
		policyid = newid, customername = customerName, vehicleid = carid,
		protection = protection, deductible = 0, date = date,
		claims = 0, cashout = 0, premium = premium, insurancefaction = factionid
	}
	pendingInsuranceSales[buyer] = nil
	outputChatBox("You have accepted the insurance plan. It is valid as of now. To cancel, please contact the company.", buyer)
	outputChatBox("The customer has accepted the insurance plan.", salesman)
	updateClientCache(salesman, {datatable, factionstable})
	updateClientCache(buyer, {datatable, factionstable})
	return true
end
addEvent("insurance:finalpurchase", true)
addEventHandler("insurance:finalpurchase", root, finalizePurchase)

function cancelPolicy(vehicleID)
	local player = client
	vehicleID = tonumber(vehicleID)
	if not player or not isElement(player) or tonumber(getElementData(player, "loggedin")) ~= 1
		or not vehicleID or vehicleID < 1 or vehicleID ~= math.floor(vehicleID) then return false end
	local policy = datatable[vehicleID]
	if not policy or tonumber(policy.vehicleid) ~= vehicleID then return false end
	local theVehicle = exports.pool:getElement("vehicle", vehicleID)
	local ownerID = theVehicle and tonumber(getElementData(theVehicle, "owner"))
	local playerID = tonumber(getElementData(player, "dbid"))
	local canCancel = playerID and ownerID == playerID
	if not canCancel then canCancel = isInsuranceManager(player, tonumber(policy.insurancefaction)) end
	if not canCancel then return false end
	local policyID = tonumber(policy.policyid)
	if not policyID or not mysql:query_free("DELETE FROM `insurance_data` WHERE `policyid`="..policyID.." AND `vehicleid`="..vehicleID) then
		return false
	end
	if isElement(theVehicle) then
		exports.anticheat:setEld(theVehicle, "insurance:fee", 0)
		exports.anticheat:setEld(theVehicle, "insurance:faction", 0)
	end
	datatable[vehicleID] = nil
	updateClientCache(player, {datatable, factionstable})
	outputChatBox("Insurance policy #"..policyID.." has been cancelled.", player)
	return true
end
addEvent("insurance:cancel", true)
addEventHandler("insurance:cancel", root, cancelPolicy)

--[[

CREATE TABLE `owl_mta`.`insurance_factions` (
  `factionID` INT NOT NULL,
  `name` VARCHAR(45) NOT NULL,
  `gen_maxi` FLOAT NOT NULL DEFAULT 0.005,
  `news` TEXT NULL,
  `subscription` TEXT NULL,
  `totalincome` FLOAT NULL,
  `totalclaims` FLOAT NULL,
  PRIMARY KEY (`factionID`));

ALTER TABLE `owl_mta`.`vehicles`
ADD COLUMN `insurancefee` INT(10) NOT NULL DEFAULT '0' AFTER `business`,
ADD COLUMN `insurancefaction` INT(10) NOT NULL DEFAULT '0' AFTER `insurancefee`;

CREATE TABLE `owl_mta`.`insurance_data` (
  `policyid` INT NOT NULL AUTO_INCREMENT,
  `customername` VARCHAR(45) NOT NULL,
  `vehicleid` INT NOT NULL,
  `protection` VARCHAR(45) NOT NULL,
  `deductible` INT NOT NULL,
  `date` DATE NOT NULL,
  `claims` FLOAT NOT NULL,
  `cashout` FLOAT NOT NULL,
  `premium` INT NOT NULL,
  PRIMARY KEY (`policyid`));


ALTER TABLE `owl_mta`.`insurance_factions`
DROP COLUMN `totalclaims`,
DROP COLUMN `totalincome`;


  ***** TO DO ******
	payday: display as text

]]
local function formatVehIds(table) --converts vehicle ids table into a text string for bank transaction logs.
	local ids = ""
	for i, vehid in pairs(table) do
	ids = ids..ids..", "
	end
	return string.sub(ids, 1, string.len(ids)-2) -- remove 2 last characters from string ", "
end

function analyzeInsurance(data, playerId) -- edit in payday resource to pass playerId here too
	local totalFee = 0
	local totalFeePerVehicles = {}
	local totalFeePerFactions = {}
	if data then
		for vehid, insurance in pairs(data) do
			for iFaction, fee in pairs(insurance) do
				--Create data based on vehicle id
				if not totalFeePerVehicles[vehid] then totalFeePerVehicles[vehid] = {} end
				if not totalFeePerVehicles[vehid]['ifaction'] then totalFeePerVehicles[vehid]['ifaction'] = iFaction end
				if not totalFeePerVehicles[vehid]['fee'] then totalFeePerVehicles[vehid]['fee'] = 0 end
				totalFeePerVehicles[vehid]['fee'] = totalFeePerVehicles[vehid]['fee'] + fee
				if not datatable[vehid]['cashout'] then
	 				datatable[vehid]['cashout'] = 0
				end
				datatable[vehid]['cashout'] = datatable[vehid]['cashout'] + fee

				--Create data based on insurance faction id
				if not totalFeePerFactions[iFaction] then totalFeePerFactions[iFaction] = {} end
				if not totalFeePerFactions[iFaction]['fee'] then totalFeePerFactions[iFaction]['fee'] = 0 end
				if not totalFeePerFactions[iFaction]['vehs'] then totalFeePerFactions[iFaction]['vehs'] = {} end
				totalFeePerFactions[iFaction]['fee'] = totalFeePerFactions[iFaction]['fee'] + fee
				table.insert(totalFeePerFactions[iFaction]['vehs'], vehid)

				--Create total fee on all vehicles from all insurance faction ids of the player
				totalFee = totalFee + fee
			end
		end
	end

	return totalFee, totalFeePerVehicles, totalFeePerFactions
end

--[[Return values for the above function / MAXIME
1. totalFee : Total insurance fees on all vehicles of the player
2. totalFeePerVehicles : A list of vehicles from a player
- index : vehicle id
- values : A list with 2 elements
 	.ifaction : insurance faction id the vehicle registered to
 	.fee : fee for the vehicle
3. totalFeePerFactions : A list of insurance factions
- index : faction id
- values : A list of 2 elements
	. fee : total fee the faction gets from all vehicles of the player
	. vehs : a list of veh ids that the insurance faction takes fees from
]]

function paynsprayClaims(vehicleid, amount)
	amount = tonumber(amount)
	vehicleid = tonumber(vehicleid)
	if not amount or amount < 0 or amount > 1000000 or amount ~= amount
		or not vehicleid or vehicleid < 1 or vehicleid ~= math.floor(vehicleid) then return false end
	local policy = datatable[vehicleid]
	if not policy then return false end
	local newClaimsTotal = (tonumber(policy.claims) or 0) + amount
	if not dbExec(mysql:getConn("mta"), "UPDATE `insurance_data` SET `claims`=? WHERE `vehicleid`=?", newClaimsTotal, vehicleid) then
		return false
	end
	policy.claims = newClaimsTotal
	for _, player in ipairs(getElementsByType("player")) do
		updateClientCache(player, {datatable, factionstable})
	end
	return true
end
addEvent("insurance:claims", false)
addEventHandler("insurance:claims", root, paynsprayClaims)

function sqlSaveDatatable() -- this is triggered when resource stops and every 5 hours
	outputDebugString("Saving insurance data.")
	for k, v in pairs(datatable) do
		local r = mysql:query_free("UPDATE `insurance_data` SET `claims`="..v['claims']..", `cashout`="..v['cashout'].." WHERE `vehicleid`="..k)
		if not r then
			outputDebugString( "ERROR: [insurance] "..path.." - FAILED TO SAVE SQL DATA")
		end
	end
end
addEventHandler("onResourceStop", resourceRoot, sqlSaveDatatable)
