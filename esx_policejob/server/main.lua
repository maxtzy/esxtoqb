QBCore = nil

TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)

if Config.MaxInService ~= -1 then
	TriggerEvent('esx_service:activateService', 'police', Config.MaxInService)
end

TriggerEvent('esx_society:registerSociety', 'police', 'Police', 'society_police', 'society_police', 'society_police', {type = 'public'})


RegisterServerEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function(target)
	local xPlayer = QBCore.Functions.GetPlayer(source)

	if xPlayer.PlayerData.job.name == 'police' then
		TriggerClientEvent('esx_policejob:handcuff', target)
	else
		print(('esx_policejob: %s attempted to handcuff a player (not cop)!'):format(xPlayer.PlayerData.citizenid))
	end
end)

RegisterServerEvent('esx_policejob:drag')
AddEventHandler('esx_policejob:drag', function(target)
	TriggerClientEvent('esx_policejob:drag', target, source)
end)

RegisterServerEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function(target)
	TriggerClientEvent('esx_policejob:putInVehicle', target)
end)

RegisterServerEvent('esx_policejob:OutVehicle')
AddEventHandler('esx_policejob:OutVehicle', function(target)
	local xPlayer = QBCore.Functions.GetPlayer(source)

	if xPlayer.job.name == 'police' then
		TriggerClientEvent('esx_policejob:OutVehicle', target)
	else
		print(('esx_policejob: %s attempted to drag out from vehicle (not cop)!'):format(xPlayer.PlayerData.citizenid))
	end
end)

QBCore.Functions.CreateCallback('esx_policejob:getOtherPlayerData', function(source, cb, target)
	if Config.EnableESXIdentity then
		local xPlayer = QBCore.Functions.GetPlayer(target)
		local result = MySQL.Sync.fetchAll('SELECT firstname, lastname, sex, dateofbirth, height FROM users WHERE identifier = @identifier', {
			['@identifier'] = xPlayer.PlayerData.citizenid
		})

		local firstname = result[1].firstname
		local lastname  = result[1].lastname
		local sex       = result[1].sex
		local dob       = result[1].dateofbirth
		local height    = result[1].height

		local data = {
			name      = GetPlayerName(target),
			job       = xPlayer.job,
			inventory = xPlayer.inventory,
			accounts  = xPlayer.accounts,
			weapons   = xPlayer.loadout,
			firstname = firstname,
			lastname  = lastname,
			sex       = sex,
			dob       = dob,
			height    = height
		}

		TriggerEvent('esx_status:getStatus', target, 'drunk', function(status)
			if status ~= nil then
				data.drunk = math.floor(status.percent)
			end
		end)

		if Config.EnableLicenses then
			TriggerEvent('esx_license:getLicenses', target, function(licenses)
				data.licenses = licenses
				cb(data)
			end)
		else
			cb(data)
		end
	else
		local xPlayer = QBCore.Functions.GetPlayer(target)

		local data = {
			name       = GetPlayerName(target),
			job        = xPlayer.job,
			inventory  = xPlayer.inventory,
			accounts   = xPlayer.accounts,
			weapons    = xPlayer.loadout
		}

		TriggerEvent('esx_status:getStatus', target, 'drunk', function(status)
			if status then
				data.drunk = math.floor(status.percent)
			end
		end)

		TriggerEvent('esx_license:getLicenses', target, function(licenses)
			data.licenses = licenses
		end)

		cb(data)
	end
end)

QBCore.Functions.CreateCallback('esx_policejob:getFineList', function(source, cb, category)
	exports.ghmattimysql:execute('SELECT * FROM fine_types WHERE category = @category', {
		['@category'] = category
	}, function(fines)
		cb(fines)
	end)
end)

QBCore.Functions.CreateCallback('esx_policejob:getVehicleInfos', function(source, cb, plate)

	exports.ghmattimysql:execute('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	}, function(result)

		local retrivedInfo = {
			plate = plate
		}

		if result[1] then
			exports.ghmattimysql:execute('SELECT name, firstname, lastname FROM users WHERE identifier = @identifier',  {
				['@identifier'] = result[1].owner
			}, function(result2)

				if Config.EnableESXIdentity then
					retrivedInfo.owner = result2[1].firstname .. ' ' .. result2[1].lastname
				else
					retrivedInfo.owner = result2[1].name
				end

				cb(retrivedInfo)
			end)
		else
			cb(retrivedInfo)
		end
	end)
end)

QBCore.Functions.CreateCallback('esx_policejob:getVehicleFromPlate', function(source, cb, plate)
	exports.ghmattimysql:execute('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	}, function(result)
		if result[1] ~= nil then

			exports.ghmattimysql:execute('SELECT name, firstname, lastname FROM users WHERE identifier = @identifier',  {
				['@identifier'] = result[1].owner
			}, function(result2)

				if Config.EnableESXIdentity then
					cb(result2[1].firstname .. ' ' .. result2[1].lastname, true)
				else
					cb(result2[1].name, true)
				end

			end)
		else
			cb(_U('unknown'), false)
		end
	end)
end)




QBCore.Functions.CreateCallback('esx_policejob:buyJobVehicle', function(source, cb, vehicleProps, type)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local price = getPriceFromHash(vehicleProps.model, xPlayer.job.grade_name, type)

	-- vehicle model not found
	if price == 0 then
		print(('esx_policejob: %s attempted to exploit the shop! (invalid vehicle model)'):format(xPlayer.PlayerData.citizenid))
		cb(false)
	else
		if xPlayer.getMoney() >= price then
			xPlayer.removeMoney(price)
			info = {
				plaka = vehicleProps.plate,
				model = vehicleProps.model
			}, 
			exports.ghmattimysql:execute('INSERT INTO owned_vehicles (owner, vehicle, plate, model, type, job, `stored`) VALUES (@owner, @vehicle, @plate, @model, @type, @job, @stored)', {
				['@owner'] = xPlayer.PlayerData.citizenid,
				['@vehicle'] = json.encode(vehicleProps),
				['@plate'] = vehicleProps.plate,
				['@model'] = vehicleProps.model,
				['@type'] = type,
				['@job'] = xPlayer.job.name,
				['@stored'] = true
			}, function (rowsChanged)
				cb(true)
			end)
			xPlayer.addInventoryItem("carkey", 1, false, info)   
		else
			cb(false)
		end
	end
end)

QBCore.Functions.CreateCallback('esx_policejob:storeNearbyVehicle', function(source, cb, nearbyVehicles)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local foundPlate, foundNum

	for k,v in ipairs(nearbyVehicles) do
		local result = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE owner = @owner AND plate = @plate AND job = @job', {
			['@owner'] = xPlayer.PlayerData.citizenid,
			['@plate'] = v.plate,
			['@job'] = xPlayer.job.name
		})

		if result[1] then
			foundPlate, foundNum = result[1].plate, k
			break
		end
	end

	if not foundPlate then
		cb(false)
	else
		MySQL.Async.execute('UPDATE owned_vehicles SET `stored` = true WHERE owner = @owner AND plate = @plate AND job = @job', {
			['@owner'] = xPlayer.PlayerData.citizenid,
			['@plate'] = foundPlate,
			['@job'] = xPlayer.job.name
		}, function (rowsChanged)
			if rowsChanged == 0 then
				print(('esx_policejob: %s has exploited the garage!'):format(xPlayer.PlayerData.citizenid))
				cb(false)
			else
				cb(true, foundNum)
			end
		end)
	end

end)

function getPriceFromHash(hashKey, jobGrade, type)
	if type == 'helicopter' then
		local vehicles = Config.AuthorizedHelicopters[jobGrade]

		for k,v in ipairs(vehicles) do
			if GetHashKey(v.model) == hashKey then
				return v.price
			end
		end
	elseif type == 'car' then
		local vehicles = Config.AuthorizedVehicles[jobGrade]
		local shared = Config.AuthorizedVehicles['Shared']

		for k,v in ipairs(vehicles) do
			if GetHashKey(v.model) == hashKey then
				return v.price
			end
		end

		for k,v in ipairs(shared) do
			if GetHashKey(v.model) == hashKey then
				return v.price
			end
		end
	end

	return 0
end

QBCore.Functions.CreateCallback('esx_policejob:getStockItems', function(source, cb)
	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		cb(inventory.items)
	end)
end)

QBCore.Functions.CreateCallback('esx_policejob:getPlayerInventory', function(source, cb)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local items   = xPlayer.inventory

	cb( { items = items } )
end)

--[[AddEventHandler('playerDropped', function()
    -- Save the source in case we lose it (which happens a lot)
    local _source         = source
    local xPlayer         = QBCore.Functions.GetPlayer(_source)

    -- Did the player ever join?
    if _source ~= nil then
      

        -- Is it worth telling all clients to refresh?
        if xPlayer ~= nil and xPlayer.job ~= nil and xPlayer.job.name == 'police' then
            local currentGPS    = xPlayer.Functions.GetItemByName('gps').count
            Citizen.Wait(5000)
            if currentGPS > 0 then
                TriggerClientEvent('esx_policejob:updateBlip', -1)
            end
        end
    end
end)]]

--[[RegisterServerEvent('esx_policejob:spawned')
AddEventHandler('esx_policejob:spawned', function()
    local _source             = source
    local xPlayer             = QBCore.Functions.GetPlayer(_source)

    if xPlayer ~= nil and xPlayer.job ~= nil and xPlayer.job.name == 'police' then
        local currentGPS         = xPlayer.Functions.GetItemByName('gps').count
        Citizen.Wait(5000)
        if currentGPS > 0 then
            TriggerClientEvent('esx_policejob:updateBlip', -1)
        end
    end
end)]]

--[[RegisterServerEvent('esx_policejob:forceBlip')
AddEventHandler('esx_policejob:forceBlip', function()
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    local currentGPS     = xPlayer.Functions.GetItemByName('gps').count

    if currentGPS > 0 then
        TriggerClientEvent('esx_policejob:updateBlip', -1)
    end
end)]]

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		Citizen.Wait(5000)
		TriggerClientEvent('esx_policejob:updateBlip', -1)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('esx_phone:removeNumber', 'police')
	end
end)

RegisterServerEvent('esx_policejob:message')
AddEventHandler('esx_policejob:message', function(target, msg)
	TriggerClientEvent('esx:showNotification', target, msg)
end)

QBCore.Functions.CreateCallback('esx_policejob:getItem', function(source, cb, item)
	local xPlayer = QBCore.Functions.GetPlayer(source)
	local items = xPlayer.Functions.GetItemByName(item)
	if items == nil then
		cb(0)
	else
		cb(items.count)
	end
end)

--[[AddEventHandler('esx:onAddInventoryItem', function(source, item, count)
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    if xPlayer ~= nil and xPlayer.job ~= nil and xPlayer.job.name == 'police' then
        if item.name == 'gps' and item.count > 0 then
            TriggerClientEvent('esx_policejob:updateBlip', source)
        end
    end
end)

AddEventHandler('esx:onRemoveInventoryItem', function(source, item, count)
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    if xPlayer ~= nil and xPlayer.job ~= nil and xPlayer.job.name == 'police' then
        if item.name == 'gps' and item.count < 1 then
            TriggerClientEvent('esx_policejob:removeBlip', source) -- bu event cliente sonradan ekleniyor
        end
    end
end)]]

RegisterServerEvent('esx_policejob:requestarrest')
AddEventHandler('esx_policejob:requestarrest', function(targetid, playerheading, playerCoords,  playerlocation)
    _source = source
    TriggerClientEvent('esx_policejob:getarrested', targetid, playerheading, playerCoords, playerlocation)
    TriggerClientEvent('esx_policejob:doarrested', _source)
end)

RegisterServerEvent('esx_policejob:requestrelease')
AddEventHandler('esx_policejob:requestrelease', function(targetid, playerheading, playerCoords,  playerlocation)
    _source = source
    TriggerClientEvent('esx_policejob:getuncuffed', targetid, playerheading, playerCoords, playerlocation)
    TriggerClientEvent('esx_policejob:douncuffing', _source)
end)

function getorfirstname (sourcePlayer, identifier, cb)
    local sourcePlayer = sourcePlayer
    local identifier = identifier
    local firstname = getFirstname(identifier)
    local lastname = getLastname(identifier)
end

function getFirstname(identifier)
    local result = MySQL.Sync.fetchAll("SELECT users.firstname FROM users WHERE users.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    if result[1] ~= nil then
        return result[1].firstname
    end
    return nil
end

function getLastname(identifier)
    local result = MySQL.Sync.fetchAll("SELECT users.lastname FROM users WHERE users.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    if result[1] ~= nil then
        return result[1].lastname
    end
    return nil
end
--[[
QBCore.Functions.CreateCallback('GetCharacterNameServer', function(source, cb, target) -- sikleks
	--local xTarget = QBCore.Functions.GetPlayer(target)
	local xPlayer = QBCore.Functions.GetPlayer(target)

    local result = MySQL.Sync.fetchAll("SELECT firstname, lastname FROM users WHERE identifier = @identifier", {
        ['@identifier'] = xPlayer.PlayerData.citizenid
    })

    local firstname = result[1].firstname
    local lastname  = result[1].lastname

    cb(''.. firstname .. ' ' .. lastname ..'')
end)--]]

-----------------------------------------------------SPYDAY--------------------------------------------------------
--[[
local GPSList = {}

RegisterServerEvent('exelds:addGPSList')
AddEventHandler('exelds:addGPSList', function(rozetNum)
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    exports.ghmattimysql:execute("SELECT firstname, lastname FROM users WHERE identifier = @identifier", { ["@identifier"] = xPlayer.PlayerData.citizenid }, function(result)
    local name = string.format("%s %s", result[1].firstname, result[1].lastname)
    table.insert(GPSList, {_source, name, xPlayer.job.name, rozetNum})
    TriggerClientEvent('exelds:refreshGPS', -1)
    end)
end)

RegisterServerEvent('exelds:removeGPSList')
AddEventHandler('exelds:removeGPSList', function()
    local _source = source
    for i = 1, #GPSList do
        if GPSList[i] and GPSList[i][1] == _source then
            table.remove(GPSList, i)
        end
    end
    TriggerClientEvent('exelds:refreshGPS', -1)
end)

QBCore.Functions.CreateCallback('exelds:getGPSList', function(source, cb)
    cb(GPSList)
end)


AddEventHandler('playerDropped', function()
    local _source         = source
    local xPlayer         = QBCore.Functions.GetPlayer(_source)
    if _source ~= nil then  
        if xPlayer ~= nil and xPlayer.job ~= nil and (xPlayer.job.name == 'police' or xPlayer.job.name == 'offpolice' or xPlayer.job.name == 'ambulance' or xPlayer.job.name == 'offambulance') then
            for i = 1, #GPSList do
                if GPSList[i] and GPSList[i][1] == _source then
                    table.remove(GPSList, i)
                end
            end
        end
    end
end)


QBCore.Functions.CreateCallback('esx_policejob:getItemAmount', function(source, cb, item)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local items = xPlayer.Functions.GetItemByName(item)
        if items == nil then
            cb(0)
        else
            cb(items.count)
        end
end)

AddEventHandler('esx:onRemoveInventoryItem', function(source, item, count)
    local _source = source
    local xPlayer = QBCore.Functions.GetPlayer(_source)
    if xPlayer ~= nil and xPlayer.job ~= nil and (xPlayer.job.name == 'police' or xPlayer.job.name == 'offpolice' or xPlayer.job.name == 'ambulance' or xPlayer.job.name == 'offambulance') then
        if item.name == 'gps' and item.count < 1 then
            TriggerClientEvent('exelds:GPSStop', source) 
        end
    end
end)

ESX.RegisterUsableItem('gps', function(source)
    TriggerClientEvent('exelds:gpsAcKapat', source)
end)
]]
-----------------------------------------------------SPYDAY--------------------------------------------------------


------------------------- YİNDİR - YBİNDİR

RegisterServerEvent('hasan:yaralibindir')
AddEventHandler('hasan:yaralibindir', function(target)
    TriggerClientEvent('hasan:ybindir', target)
end)

RegisterServerEvent('hasan:yaralindir')
AddEventHandler('hasan:yaralindir', function(target)
    local xPlayer = QBCore.Functions.GetPlayer(source)
        TriggerClientEvent('hasan:yaralıindir', target)
end)

QBCore.Functions.CreateCallback('policejob:isplayerdead', function(source, cb, target)
    local player = QBCore.Functions.GetPlayer(target)
    exports.ghmattimysql:execute('SELECT is_dead FROM users WHERE identifier = @identifier', {
        ['@identifier'] = player.identifier
    }, function(result)
        local isDead = result[1].is_dead
        cb(isDead)
    end)
end)