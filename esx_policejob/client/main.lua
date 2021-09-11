local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
  }
  
local PlayerData, CurrentActionData, handcuffTimer, dragStatus, blipsCops, currentTask, spawnedVehicles = {}, {}, {}, {}, {}, {}, {}
local HasAlreadyEnteredMarker, isDead, isHandcuffed, hasAlreadyJoined, playerInService, isInShopMenu = false, false, false, false, false, false
local LastStation, LastPart, LastPartNum, LastEntity, CurrentAction, CurrentActionMsg
dragStatus.isDragged = false
QBCore = nil

local PlayerData              = {}
local HasAlreadyEnteredMarker = false
local LastStation             = nil
local LastPart                = nil
local LastPartNum             = nil
local LastEntity              = nil
local CurrentAction           = nil
local CurrentActionMsg        = ''
local CurrentActionData       = {}
local IsHandcuffed            = false
local HandcuffTimer           = {}
local DragStatus              = {}
local spawnedVehicles         = {}
DragStatus.IsDragged          = false
local hasAlreadyJoined        = false
local blipsCops               = {}
local isDead                  = false
local CurrentTask             = {}
local playerInService         = false

QBCore = nil

Citizen.CreateThread(function() 
	while true do
		Citizen.Wait(1)
		if QBCore == nil then
			TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end) 
			Citizen.Wait(200)
		end
	end

	while QBCore.Functions.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end

	PlayerData = QBCore.Functions.GetPlayerData()
end)

function OpenVehicleSpawnerMenu(type, station, part, partNum)
	local playerCoords = GetEntityCoords(PlayerPedId())
	PlayerData = QBCore.Functions.GetPlayerData()
	local elements = {
		{label = "Garajım", action = 'garage'},
		{label = "Aracı Garaja Koy", action = 'store_garage'},
		{label = "Araç Satın Al", action = 'buy_vehicle'}
	}

	QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle', {
		title    = "Garaj",
		align    = 'top-left',
		elements = elements
	}, function(data, menu)
		if data.current.action == 'buy_vehicle' then
			local shopElements, shopCoords = {}

			if type == 'car' then
				shopCoords = Config.PoliceStations[station].Vehicles[partNum].InsideShop
				local authorizedVehicles = Config.AuthorizedVehicles[PlayerData.job.grade_name]

				if #Config.AuthorizedVehicles.Shared > 0 then
					for k,vehicle in ipairs(Config.AuthorizedVehicles.Shared) do
						table.insert(shopElements, {
							label = vehicle.label..' $'..vehicle.price,
							name  = vehicle.label,
							model = vehicle.model,
							price = vehicle.price,
							type  = 'car'
						})
					end
				end

				if #authorizedVehicles > 0 then
					for k,vehicle in ipairs(authorizedVehicles) do
						table.insert(shopElements, {
							label = vehicle.label..' $'..vehicle.price,
							name  = vehicle.label,
							model = vehicle.model,
							price = vehicle.price,
							type  = 'car'
						})
					end
				else
					if #Config.AuthorizedVehicles.Shared == 0 then
						return
					end
				end
			elseif type == 'helicopter' then
				shopCoords = Config.PoliceStations[station].Helicopters[partNum].InsideShop
				local authorizedHelicopters = Config.AuthorizedHelicopters[PlayerData.job.grade_name]

				if #authorizedHelicopters > 0 then
					for k,vehicle in ipairs(authorizedHelicopters) do
						table.insert(shopElements, {
							label = vehicle.label..' $'..vehicle.price,
							name  = vehicle.label,
							model = vehicle.model,
							price = vehicle.price,
							livery = vehicle.livery or nil,
							type  = 'helicopter'
						})
					end
				else
					QBCore.Functions.Notify("Buraya giriş izniniz yok!", "error")
					return
				end
			end

			OpenShopMenu(shopElements, playerCoords, shopCoords)
		elseif data.current.action == 'garage' then
			local garage = {}

			QBCore.Functions.TriggerCallback('esx_vehicleshop:retrieveJobVehicles', function(jobVehicles)
				if #jobVehicles > 0 then
					for k,v in ipairs(jobVehicles) do
						local props = json.decode(v.vehicle)
						local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
						local label = vehicleName..' Plaka: '..props.plate

						if v.stored then
							label = label .. ' Garajda'
						else
							label = label .. ' Garajda Değil'
						end

						table.insert(garage, {
							label = label,
							stored = v.stored,
							model = props.model,
							vehicleProps = props
						})
					end

					QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_garage', {
						title    = "Garajım",
						align    = 'top-left',
						elements = garage
					}, function(data2, menu2)
						if data2.current.stored then
							local foundSpawn, spawnPoint = GetAvailableVehicleSpawnPoint(station, part, partNum)

							if foundSpawn then
								menu2.close()

								QBCore.Functions.SpawnVehicle(data2.current.model, spawnPoint.coords, spawnPoint.heading, function(vehicle)
									QBCore.Functions.SetVehicleProperties(vehicle, data2.current.vehicleProps)

									TriggerServerEvent('esx_vehicleshop:setJobVehicleState', data2.current.vehicleProps.plate, false)
									QBCore.Functions.Notify("Araç başarıyla garajınıza koyuldu!", "success")
								end)
							end
						else
							QBCore.Functions.Notify("Garaja Erişilemiyor!", "error")
						end
					end, function(data2, menu2)
						menu2.close()
					end)
				else
					QBCore.Functions.Notify("Garaj Boş!", "error")
				end
			end, type)
		elseif data.current.action == 'store_garage' then
			StoreNearbyVehicle(playerCoords)
		end
	end, function(data, menu)
		menu.close()
	end)
end

function StoreNearbyVehicle(playerCoords)
	local vehicles, vehiclePlates = QBCore.Functions.GetVehiclesInArea(playerCoords, 30.0), {}

	if #vehicles > 0 then
		for k,v in ipairs(vehicles) do

			-- Make sure the vehicle we're saving is empty, or else it wont be deleted
			if GetVehicleNumberOfPassengers(v) == 0 and IsVehicleSeatFree(v, -1) then
				table.insert(vehiclePlates, {
					vehicle = v,
					plate = QBCore.Functions.MathTrim(GetVehicleNumberPlateText(v))
				})
			end
		end
	else
		QBCore.Functions.Notify("Yakında araç yok!", "error")
		return
	end

	QBCore.Functions.TriggerCallback('esx_policejob:storeNearbyVehicle', function(storeSuccess, foundNum)
		if storeSuccess then
			local vehicleId = vehiclePlates[foundNum]
			local attempts = 0
			QBCore.Functions.DeleteVehicle(vehicleId.vehicle)
			IsBusy = true

			Citizen.CreateThread(function()
				Citizen.Wait(0)
				BeginTextCommandBusyString('STRING')
				AddTextComponentSubstringPlayerName("Garaj Yükleniyor")
				EndTextCommandBusyString(4)

				while IsBusy do
					Citizen.Wait(100)
				end

				RemoveLoadingPrompt()
			end)

			-- Workaround for vehicle not deleting when other players are near it.
			while DoesEntityExist(vehicleId.vehicle) do
				Citizen.Wait(500)
				attempts = attempts + 1

				-- Give up
				if attempts > 30 then
					break
				end

				vehicles = QBCore.Functions.GetVehiclesInArea(playerCoords, 30.0)
				if #vehicles > 0 then
					for k,v in ipairs(vehicles) do
						if QBCore.Functions.MathTrim (GetVehicleNumberPlateText(v)) == vehicleId.plate then
							QBCore.Functions.DeleteVehicle(v)
							break
						end
					end
				end
			end
			IsBusy = false
		else
			QBCore.Functions.Notify("Araç sana ait değil!", "error")
		end
	end, vehiclePlates)
end

function GetAvailableVehicleSpawnPoint(station, part, partNum)
	local spawnPoints = Config.PoliceStations[station][part][partNum].SpawnPoints
	local found, foundSpawnPoint = false, nil

	for i=1, #spawnPoints, 1 do
		if QBCore.Functions.IsSpawnPointClear(spawnPoints[i].coords, spawnPoints[i].radius) then
			found, foundSpawnPoint = true, spawnPoints[i]
			break
		end
	end

	if found then
		return true, foundSpawnPoint
	else
		QBCore.Functions.Notify("Çıkarma Noktalarında Araçlar var!", "error")
		return false
	end
end

function OpenShopMenu(elements, restoreCoords, shopCoords)
	local playerPed = PlayerPedId()
	isInShopMenu = true

	QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_shop', {
		title    = "LSPD Araç Galerisi",
		align    = 'top-left',
		elements = elements
	}, function(data, menu)
		QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_shop_confirm', {
			title    = data.current.name..' Fiyat: $'..data.current.price,
			align    = 'top-left',
			elements = {
				{label = "Hayır", value = 'no'},
				{label = "Evet", value = 'yes'}
		}}, function(data2, menu2)
			if data2.current.value == 'yes' then
				local newPlate = exports['ld-vehicleshop']:GeneratePlate()
				local vehicle  = GetVehiclePedIsIn(playerPed, false)
				local props    = QBCore.Functions.SpawnVehicle(vehicle)
				props.plate    = newPlate

				QBCore.Functions.TriggerCallback('esx_policejob:buyJobVehicle', function (bought)
					if bought then
						QBCore.Functions.Notify("Başarıyla bir LSPD Aracı Satın aldınız! Anahtarlar size teslim edildi!", "success")

						isInShopMenu = false
						QBCore.UI.Menu.CloseAll()
						DeleteSpawnedVehicles()
						FreezeEntityPosition(playerPed, false)
						SetEntityVisible(playerPed, true)

						QBCore.Functions.Teleport(playerPed, restoreCoords)
					else
						QBCore.Functions.Notify("Aracı satın alabilecek kadar yeterli paranız yok!", "error")
						menu2.close()
					end
				end, props, data.current.type)
			else
				menu2.close()
			end
		end, function(data2, menu2)
			menu2.close()
		end)
	end, function(data, menu)
		isInShopMenu = false
		QBCore.UI.Menu.CloseAll()

		DeleteSpawnedVehicles()
		FreezeEntityPosition(playerPed, false)
		SetEntityVisible(playerPed, true)

		QBCore.Functions.Teleport(playerPed, restoreCoords)
	end, function(data, menu)
		DeleteSpawnedVehicles()
		WaitForVehicleToLoad(data.current.model)

		QBCore.Functions.SpawnVehicle(data.current.model, shopCoords, 0.0, function(vehicle)
			table.insert(spawnedVehicles, vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
			FreezeEntityPosition(vehicle, true)
			SetModelAsNoLongerNeeded(data.current.model)

			if data.current.livery then
				SetVehicleModKit(vehicle, 0)
				SetVehicleLivery(vehicle, data.current.livery)
			end
		end)
	end)

	WaitForVehicleToLoad(elements[1].model)
	QBCore.Functions.SpawnVehicle(elements[1].model, shopCoords, 0.0, function(vehicle)
		table.insert(spawnedVehicles, vehicle)
		TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		FreezeEntityPosition(vehicle, true)
		SetModelAsNoLongerNeeded(elements[1].model)

		if elements[1].livery then
			SetVehicleModKit(vehicle, 0)
			SetVehicleLivery(vehicle, elements[1].livery)
		end
	end)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if isInShopMenu then
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
		else
			Citizen.Wait(500)
		end
	end
end)

function DeleteSpawnedVehicles()
	while #spawnedVehicles > 0 do
		local vehicle = spawnedVehicles[1]
		QBCore.Functions.DeleteVehicle(vehicle)
		table.remove(spawnedVehicles, 1)
	end
end

function WaitForVehicleToLoad(modelHash)
	modelHash = (type(modelHash) == 'number' and modelHash or GetHashKey(modelHash))

	if not HasModelLoaded(modelHash) then
		RequestModel(modelHash)

		BeginTextCommandBusyString('STRING')
		AddTextComponentSubstringPlayerName(_U('vehicleshop_awaiting_model'))
		EndTextCommandBusyString(4)

		while not HasModelLoaded(modelHash) do
			Citizen.Wait(0)
			DisableAllControlActions(0)
		end

		RemoveLoadingPrompt()
	end
end

function OpenPoliceActionsMenu()
	QBCore.UI.Menu.CloseAll()

	QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'police_actions', {
		title    = 'LSPD',
		align    = 'top-left',
		 elements = {
			{label = "Vatandaş İşlemleri", value = 'citizen_interaction'},
			{label = "Araç Plaka Sorgulama", value = 'vehicle_interaction'},
			{label = "Obje Spawner", value = 'object_spawner'}
		--	{label = 'Köpek Menüsü', value = 'kopekcagir'}
	}}, function(data, menu)
		if data.current.value == 'citizen_interaction' then
			local elements = {
				{label = "Kimlik Bilgisi Gör", value = 'identity_card'},
				{label = "Üstünü Ara", value = 'body_search'},
				{label = "Kelepçele", value = 'handcuff'},
				{label = "Kelepçeyi Çöz", value = 'uncuff'},
				{label = "Taşı", value = 'drag'},
				{label = "Araca Koy", value = 'put_in_vehicle'},
				{label = "Araçtan Dışarı Çıkar", value = 'out_the_vehicle'},
				{label = "Ceza", value = 'fine'},
				{label = "Ödenmemiş Faturalar", value = 'unpaid_bills'},
				{label = "Hapis Menüsü", value = 'jail'},
				{label = "Barut Testi", value = 'gsr'},
				{label = "Kamu Hizmeti",	value = 'communityservice'}
			}

			if Config.EnableLicenses then
				table.insert(elements, { label = "Lisansları Kontrol Et", value = 'license' })
			end

			QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'citizen_interaction', {
				title    = "Sivil Menüsü",
				align    = 'top-left',
				elements = elements
			}, function(data2, menu2)
				local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
				if closestPlayer ~= -1 and closestDistance <= 3.0 then
					local action = data2.current.value

					if action == 'identity_card' then
						OpenIdentityCardMenu(closestPlayer)
					elseif action == 'body_search' then
						--TriggerServerEvent('esx_policejob:message', GetPlayerServerId(closestPlayer), _U('being_searched'))
						--exports['mythic_notify']:DoHudText('inform', 'Polis üstünü arıyor', 2500)
						OpenBodySearchMenu(closestPlayer)
						--TriggerEvent("esx_inventoryhud:openPlayerInventory", GetPlayerServerId(target), GetPlayerName(target))
					elseif action == 'handcuff' then
						local target, distance = QBCore.Functions.GetClosestPlayer()
						playerheading = GetEntityHeading(GetPlayerPed(-1))
						playerlocation = GetEntityForwardVector(PlayerPedId())
						playerCoords = GetEntityCoords(GetPlayerPed(-1))
						local target_id = GetPlayerServerId(target)
						if distance <= 2.0 then
							TriggerServerEvent('esx_policejob:requestarrest', target_id, playerheading, playerCoords, playerlocation)
						else
							QBCore.Functions.Notify("Kelepçelemek için çok uzaktasın!", "error")
						end
					elseif action == 'uncuff' then
						local target, distance = QBCore.Functions.GetClosestPlayer()
						playerheading = GetEntityHeading(GetPlayerPed(-1))
						playerlocation = GetEntityForwardVector(PlayerPedId())
						playerCoords = GetEntityCoords(GetPlayerPed(-1))
						local target_id = GetPlayerServerId(target)
						if distance <= 2.0 then
							TriggerServerEvent('esx_policejob:requestrelease', target_id, playerheading, playerCoords, playerlocation)
						else
							QBCore.Functions.Notify("Kelepçeyi çözmek için çok uzaktasın!", "error")
						end
					elseif action == 'drag' then
						TriggerServerEvent('esx_policejob:drag', GetPlayerServerId(closestPlayer))
					elseif action == 'put_in_vehicle' then
						TriggerServerEvent('esx_policejob:putInVehicle', GetPlayerServerId(closestPlayer))
					elseif action == 'out_the_vehicle' then
						TriggerServerEvent('esx_policejob:OutVehicle', GetPlayerServerId(closestPlayer))
					elseif action == 'fine' then
						OpenFineMenu(closestPlayer)
					elseif action == 'license' then
						ShowPlayerLicense(closestPlayer)
					elseif action == 'unpaid_bills' then
						OpenUnpaidBillsMenu(closestPlayer)
					elseif action == 'jail' then
					    TriggerEvent("esx-qalle-jail:openJailMenu", src)
					elseif action == 'gsr' then
						TriggerServerEvent('GSR:Status2', GetPlayerServerId(closestPlayer))
					elseif action == 'communityservice' then
						SendToCommunityService(GetPlayerServerId(closestPlayer))
					end
				else
					QBCore.Functions.Notify("Yakında Oyuncu Yok!", "error")
				end
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif data.current.value == 'vehicle_interaction' then
			local elements  = {}
			local playerPed = PlayerPedId()
			local vehicle = QBCore.FunctionsQBCore.Functions.GetVehicleInDirection()

			if DoesEntityExist(vehicle) then
				table.insert(elements, {label = "Araç Bilgisi", value = 'vehicle_infos'})
				table.insert(elements, {label = "Aracın Kilidini Aç", value = 'hijack_vehicle'})
				table.insert(elements, {label = "Aracı Çek", value = 'impound'})
			end

			table.insert(elements, {label = _U('search_database'), value = 'search_database'})

			QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_interaction', {
				title    = "Araç Menüsü",
				align    = 'top-left',
				elements = elements
			}, function(data2, menu2)
				local coords  = GetEntityCoords(playerPed)
				vehicle = QBCore.FunctionsQBCore.Functions.GetVehicleInDirection()
				action  = data2.current.value

				if action == 'search_database' then
					LookupVehicle()
				elseif DoesEntityExist(vehicle) then
					if action == 'vehicle_infos' then
						local vehicleData = QBCore.Functions.GetVehicleProperties(vehicle)
						OpenVehicleInfosMenu(vehicleData)
					elseif action == 'hijack_vehicle' then
						if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
							TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_WELDING', 0, true)
							Citizen.Wait(20000)
							ClearPedTasksImmediately(playerPed)

							SetVehicleDoorsLocked(vehicle, 1)
							SetVehicleDoorsLockedForAllPlayers(vehicle, false)
							QBCore.Functions.Notify("Araç Kilidi Başarıyla Açıldı!", "success")
						end
					elseif action == 'impound' then
						-- is the script busy?
						if currentTask.busy then
							return
						end

						QBCore.Functions.ShowHelpNotification("Aracı Çekmeyi İptal Et - ~r~E")
						TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)

						currentTask.busy = true
						currentTask.task = QBCore.Functions.SetTimeout(10000, function()
							ClearPedTasks(playerPed)
							ImpoundVehicle(vehicle)
							Citizen.Wait(100) -- sleep the entire script to let stuff sink back to reality
						end)

						-- keep track of that vehicle!
						Citizen.CreateThread(function()
							while currentTask.busy do
								Citizen.Wait(1000)

								vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
								if not DoesEntityExist(vehicle) and currentTask.busy then
									QBCore.Functions.Notify("Araç Çekme İşlemi İptal Edildi", "error")
									QBCore.Functions.ClearTimeout(currentTask.task)
									ClearPedTasks(playerPed)
									currentTask.busy = false
									break
								end
							end
						end)
					end
				else
					QBCore.Functions.Notify("Yakında Araç Yok!", "error")
				end

			end, function(data2, menu2)
				menu2.close()
			end)
		elseif data.current.value == 'object_spawner' then
			QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'citizen_interaction', {
				title    = ('OBJE MENÜSÜ'),
				align    = 'top-left',
				elements = {
					{label = "Koni", model = 'prop_roadcone02a'},
					{label = "Bariyer", model = 'prop_barrier_work05'},
					{label = "Tuzak", model = 'p_ld_stinger_s'},
					{label = "Kutular", model = 'prop_boxpile_07d'}
			}}, function(data2, menu2)
				local playerPed = PlayerPedId()
				local coords    = GetEntityCoords(playerPed)
				local forward   = GetEntityForwardVector(playerPed)
				local x, y, z   = table.unpack(coords + forward * 1.0)

				if data2.current.model == 'prop_roadcone02a' then
					z = z - 2.0
				end

				QBCore.Functions.SpawnObject(data2.current.model, {x = x, y = y, z = z}, function(obj)
					SetEntityHeading(obj, GetEntityHeading(playerPed))
					PlaceObjectOnGroundProperly(obj)
				end)
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif data.current.value == 'kopekcagir' then
				local elements = {
				  {label = 'Köpeği çağır', value = 'k9spawn'},
				  {label = 'Köpeği takip ettirme', value = 'k9follow'},
				  {label = 'Köpeği durdur', value = 'k9stay'},
				  {label = 'Köpeğe aracı arat', value = 'k9sehveh'},
				  {label = 'Köpeğe oyuncuyu arat', value = 'k9sehcit'},
				  {label = 'Köpeği araca koy', value = 'k9enterveh'},
				  {label = 'Köpeği araçtan çıkar', value = 'k9exitveh'},
				  {label = 'Köpeği sil', value = 'k9delete'}
				}
		  
				QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'k9_interaction', {
				  title    = 'Köpek Menüsü',
				  align    = 'right',
				  elements = elements
				}, function(data99, menu99)
					local action = data99.current.value
		  
					if action == 'k9spawn' then
					 	ExecuteCommand('k9 spawn husky')
					elseif action == 'k9follow' then
	                	ExecuteCommand('k9 follow')
					elseif action == 'k9stay' then
						ExecuteCommand('k9 stay')
				 	elseif action == 'k9sehveh' then
						ExecuteCommand('k9 search vehicle')
				 	elseif action == 'k9sehcit' then
						ExecuteCommand('k9 search player')
					elseif action == 'k9enterveh' then
						ExecuteCommand('k9 enter')
					elseif action == 'k9exitveh' then
						ExecuteCommand('k9 exit')
					elseif action == 'k9delete' then
						ExecuteCommand('k9 delete')
					end
				end, function(data99, menu99)
				  menu99.close()
				end)
		end
	end, function(data, menu)
		menu.close()
	end)
end


function SendToCommunityService(player)
	QBCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'Kamu Hizmeti', {
		title = "Community Service Menu",
	}, function (data2, menu)
		local community_services_count = tonumber(data2.value)
		
		if community_services_count == nil then
			QBCore.Functions.Notify("Geçersiz Miktar", "error")
		else
			TriggerServerEvent("esx_communityservice:sendToCommunityService", player, community_services_count)
			menu.close()
		end
	end, function (data2, menu)
		menu.close()
	end)
end

function OpenBodySearchMenu(player)
	--TriggerEvent("esx_inventoryhud:openPlayerInventory", GetPlayerServerId(player), GetPlayerName(player))
		TriggerEvent("disc_inventoryhud:search", source)
		QBCore.UI.Menu.CloseAll()
end

function OpenFineMenu(player)
	QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'fine', {
		title    = "Ceza Listesi",
		align    = 'top-left',
		elements = {
			{label = "Trafik Suçları", value = 0},
			{label = _"Küçük Suçlar",   value = 1},
			{label = "Büyük Suçlar", value = 2},
			{label = "Daha Büyük Suçlar",   value = 3}
	}}, function(data, menu)
		OpenFineCategoryMenu(player, data.current.value)
	end, function(data, menu)
		menu.close()
	end)
end

function OpenFineCategoryMenu(player, category)
	QBCore.Functions.TriggerCallback('esx_policejob:getFineList', function(fines)
		local elements = {}

		for k,fine in ipairs(fines) do
			table.insert(elements, {
				label     = fine.label..' $'..fine.amount,
				value     = fine.id,
				amount    = fine.amount,
				fineLabel = fine.label
			})
		end

		QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'fine_category', {
			title    = _U('fine'),
			align    = 'top-left',
			elements = elements
		}, function(data, menu)
			menu.close()

				TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), 'society_police', "Ceza Tutarı: ", data.current.fineLabel..' $'..data.current.amount)

				QBCore.Functions.SetTimeout(300, function()
				OpenFineCategoryMenu(player, category)
			end)
		end, function(data, menu)
			menu.close()
		end)
	end, category)
end

function LookupVehicle()
	QBCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'lookup_vehicle',
	{
		title = "Veritabanında Arat",
	}, function(data, menu)
		local length = string.len(data.value)
		if data.value == nil or length < 2 or length > 13 then
			exports['mythic_notify']:DoHudText('inform', 'Geçersiz kayıt numarası', 2500, { ['background-color'] = '#e03232', ['color'] = '#ffffff' })
		else
			QBCore.Functions.TriggerCallback('esx_policejob:getVehicleFromPlate', function(owner, found)
				if found then
					exports['mythic_notify']:DoHudText('inform', 'Araç '.. owner.. 'adlı kişiye ait', 2500, { ['background-color'] = '#e03232', ['color'] = '#ffffff' })
				else
					exports['mythic_notify']:DoHudText('inform', 'Bu numara bir araca kayıtlı değil', 2500, { ['background-color'] = '#e03232', ['color'] = '#ffffff' })
				end
			end, data.value)
			menu.close()
		end
	end, function(data, menu)
		menu.close()
	end)
end

function ShowPlayerLicense(player)
	local elements, targetName = {}

	QBCore.Functions.TriggerCallback('esx_policejob:getOtherPlayerData', function(data)
		if data.licenses then
			for i=1, #data.licenses, 1 do
				if data.licenses[i].label and data.licenses[i].type then
					table.insert(elements, {
						label = data.licenses[i].label,
						type = data.licenses[i].type
					})
				end
			end
		end

		if Config.EnableESXIdentity then
			targetName = data.firstname .. ' ' .. data.lastname
		else
			targetName = data.name
		end

		QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'manage_license', {
			title    = ('LİSANS MENÜSÜ'),
			align    = 'top-left',
			elements = elements,
		}, function(data, menu)
			QBCore.Functions.Notify("Lisans İptal Edildi!", "error")
			TriggerServerEvent('esx_policejob:message', GetPlayerServerId(player), _U('license_revoked', data.current.label))

			TriggerServerEvent('esx_license:removeLicense', GetPlayerServerId(player), data.current.type)

			QBCore.Functions.SetTimeout(300, function()
				ShowPlayerLicense(player)
			end)
		end, function(data, menu)
			menu.close()
		end)

	end, GetPlayerServerId(player))
end

function OpenUnpaidBillsMenu(player)
	local elements = {}

	QBCore.Functions.TriggerCallback('esx_billing:getTargetBills', function(bills)
		for k,bill in ipairs(bills) do
			table.insert(elements, {
				label = bill.label..' $'..bill.amount,
				billId = bill.id
			})
		end

		QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'billing', {
			title    = "Ödenmemiş Faturalar",
			align    = 'top-left',
			elements = elements
		}, nil, function(data, menu)
			menu.close()
		end)
	end, GetPlayerServerId(player))
end

function OpenVehicleInfosMenu(vehicleData)
	QBCore.Functions.TriggerCallback('esx_policejob:getVehicleInfos', function(retrivedInfo)
		local elements = {{label = _U('plate', retrivedInfo.plate)}}

		if retrivedInfo.owner == nil then
			table.insert(elements, {label = _U('owner_unknown')})
		else
			table.insert(elements, {label = _U('owner', retrivedInfo.owner)})
		end

		QBCore.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_infos', {
			title    = _U('vehicle_info'),
			align    = 'top-left',
			elements = elements
		}, nil, function(data, menu)
			menu.close()
		end)
	end, vehicleData.plate)
end

RegisterNetEvent('QBCore:Client:OnJobUptade')
AddEventHandler('QBCore:Client:OnJobUptade', function(job)
	PlayerData.job = job

	Citizen.Wait(5000)
end)

AddEventHandler('esx_policejob:hasEnteredMarker', function(station, part, partNum)
	if part == 'Cloakroom' then
		CurrentAction     = 'menu_cloakroom'
		CurrentActionMsg  = _U('open_cloackroom')
		CurrentActionData = {}
	elseif part == 'Armory' then
		CurrentAction     = 'menu_armory'
		CurrentActionMsg  = _U('open_armory')
		CurrentActionData = {station = station}
	elseif part == 'Vehicles' then
		CurrentAction     = 'menu_vehicle_spawner'
		CurrentActionMsg  = _U('garage_prompt')
		CurrentActionData = {station = station, part = part, partNum = partNum}
	elseif part == 'Helicopters' then
		CurrentAction     = 'Helicopters'
		CurrentActionMsg  = _U('helicopter_prompt')
		CurrentActionData = {station = station, part = part, partNum = partNum}
	elseif part == 'BossActions' then
		CurrentAction     = 'menu_boss_actions'
		CurrentActionMsg  = _U('open_bossmenu')
		CurrentActionData = {}
	end
end)

AddEventHandler('esx_policejob:hasExitedMarker', function(station, part, partNum)
	if not isInShopMenu then
		QBCore.UI.Menu.CloseAll()
	end

	CurrentAction = nil
end)

AddEventHandler('esx_policejob:hasEnteredEntityZone', function(entity)
	local playerPed = PlayerPedId()

	if PlayerData.job and PlayerData.job.name == 'police' and IsPedOnFoot(playerPed) then
		CurrentAction     = 'remove_entity'
		CurrentActionMsg  = _U('remove_prop')
		CurrentActionData = {entity = entity}
	end

	if GetEntityModel(entity) == GetHashKey('p_ld_stinger_s') then
		local playerPed = PlayerPedId()
		local coords    = GetEntityCoords(playerPed)

		if IsPedInAnyVehicle(playerPed, false) then
			local vehicle = GetVehiclePedIsIn(playerPed)

			for i=0, 7, 1 do
				SetVehicleTyreBurst(vehicle, i, true, 1000)
			end
		end
	end
end)

AddEventHandler('esx_policejob:hasExitedEntityZone', function(entity)
	if CurrentAction == 'remove_entity' then
		CurrentAction = nil
	end
end)

RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function()
	local playerPed = PlayerPedId()

	Citizen.CreateThread(function()
		Citizen.Wait(0)
		if IsHandcuffed then


			if Config.EnableHandcuffTimer then

				if HandcuffTimer.Active then
					QBCore.Functions.ClearTimeout(HandcuffTimer.Task)
				end

				StartHandcuffTimer()
			end

		else

			if Config.EnableHandcuffTimer and HandcuffTimer.Active then
				QBCore.Functions.ClearTimeout(HandcuffTimer.Task)
			end

			
		end
	end)

end)

RegisterNetEvent('esx_policejob:unrestrain')
AddEventHandler('esx_policejob:unrestrain', function()
	if IsHandcuffed then
		local playerPed = PlayerPedId()
		IsHandcuffed = false

		ClearPedSecondaryTask(playerPed)
		SetEnableHandcuffs(playerPed, false)
		DisablePlayerFiring(playerPed, false)
		SetPedCanPlayGestureAnims(playerPed, true)
		FreezeEntityPosition(playerPed, false)
		DisplayRadar(true)

		-- end timer
		if Config.EnableHandcuffTimer and HandcuffTimer.Active then
			QBCore.Functions.ClearTimeout(HandcuffTimer.Task)
		end
	end
end)

RegisterNetEvent('esx_policejob:drag')
AddEventHandler('esx_policejob:drag', function(copID)
	if not IsHandcuffed then
		return
	end

	DragStatus.IsDragged = not DragStatus.IsDragged
	DragStatus.CopId     = tonumber(copID)
end)

Citizen.CreateThread(function()
	local playerPed
	local targetPed

	while true do
		Citizen.Wait(1)

		if IsHandcuffed then
			playerPed = PlayerPedId()

			if DragStatus.IsDragged then
				targetPed = GetPlayerPed(GetPlayerFromServerId(DragStatus.CopId))

				-- undrag if target is in an vehicle
				if not IsPedSittingInAnyVehicle(targetPed) then
					AttachEntityToEntity(playerPed, targetPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
				else
					DragStatus.IsDragged = false
					DetachEntity(playerPed, true, false)
				end

			else
				DetachEntity(playerPed, true, false)
			end
		else
			Citizen.Wait(500)
		end
	end
end)

RegisterNetEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function()
	local playerPed = PlayerPedId()
	local coords    = GetEntityCoords(playerPed)

	if not IsHandcuffed then
		return
	end

	if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then
		local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)

		if DoesEntityExist(vehicle) then
			local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
			local freeSeat = nil

			for i=maxSeats - 1, 0, -1 do
				if IsVehicleSeatFree(vehicle, i) then
					freeSeat = i
					break
				end
			end

			if freeSeat ~= nil then
				TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
				DragStatus.IsDragged = false
			end
		end
	end
end)

RegisterNetEvent('esx_policejob:OutVehicle')
AddEventHandler('esx_policejob:OutVehicle', function()
	local playerPed = PlayerPedId()

	if not IsPedSittingInAnyVehicle(playerPed) then
		return
	end

	local vehicle = GetVehiclePedIsIn(playerPed, false)
	TaskLeaveVehicle(playerPed, vehicle, 16)
end)

RegisterNetEvent('esx_policejob:getarrested')
AddEventHandler('esx_policejob:getarrested', function(playerheading, playercoords, playerlocation)
	playerPed = GetPlayerPed(-1)
	SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true) -- unarm player
	local x, y, z   = table.unpack(playercoords + playerlocation * 1.0)
	SetEntityCoords(GetPlayerPed(-1), x, y, z)
	SetEntityHeading(GetPlayerPed(-1), playerheading)
	Citizen.Wait(250)
	loadanimdict('mp_arrest_paired')
	TaskPlayAnim(GetPlayerPed(-1), 'mp_arrest_paired', 'crook_p2_back_right', 8.0, -8, 3750 , 2, 0, 0, 0, 0)
	Citizen.Wait(3760)
	IsHandcuffed = true
	TriggerEvent('esx_policejob:handcuff')
	loadanimdict('mp_arresting')
	TaskPlayAnim(GetPlayerPed(-1), 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0.0, false, false, false)
	TriggerEvent('esx_status:add', 'stress', 25000)
	exports['mythic_notify']:SendUniqueAlert('id', 'error', 'Stresin arttı')
end)

RegisterNetEvent('esx_policejob:doarrested')
AddEventHandler('esx_policejob:doarrested', function()
	Citizen.Wait(250)
	loadanimdict('mp_arrest_paired')
	TaskPlayAnim(GetPlayerPed(-1), 'mp_arrest_paired', 'cop_p2_back_right', 8.0, -8,3750, 2, 0, 0, 0, 0)
	Citizen.Wait(3000)

end) 

RegisterNetEvent('esx_policejob:douncuffing')
AddEventHandler('esx_policejob:douncuffing', function()
	Citizen.Wait(250)
	loadanimdict('mp_arresting')
	TaskPlayAnim(GetPlayerPed(-1), 'mp_arresting', 'a_uncuff', 8.0, -8,-1, 2, 0, 0, 0, 0)
	Citizen.Wait(5500)
	ClearPedTasks(GetPlayerPed(-1))
end)

RegisterNetEvent('esx_policejob:getuncuffed')
AddEventHandler('esx_policejob:getuncuffed', function(playerheading, playercoords, playerlocation)
	local x, y, z   = table.unpack(playercoords + playerlocation * 1.0)
	SetEntityCoords(GetPlayerPed(-1), x, y, z)
	SetEntityHeading(GetPlayerPed(-1), playerheading)
	Citizen.Wait(250)
	loadanimdict('mp_arresting')
	TaskPlayAnim(GetPlayerPed(-1), 'mp_arresting', 'b_uncuff', 8.0, -8,-1, 2, 0, 0, 0, 0)
	Citizen.Wait(5500)
	IsHandcuffed = false
	TriggerEvent('esx_policejob:handcuff')
	ClearPedTasks(GetPlayerPed(-1))
	TriggerEvent('esx_status:remove', 'stress', 20000)
	exports['mythic_notify']:SendUniqueAlert('id', 'error', 'Stresin azaldı')
end)

exports('Handcuffed', function()
    return IsHandcuffed
end)

-- Handcuff
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()

		if IsHandcuffed then
			DisableControlAction(0, 24, true) -- Attack
			DisableControlAction(0, 257, true) -- Attack 2
			DisableControlAction(0, 25, true) -- Aim
			DisableControlAction(0, 263, true) -- Melee Attack 1

			DisableControlAction(0, Keys['R'], true) -- Reload
			DisableControlAction(0, Keys['TAB'], true) -- Select Weapon
			DisableControlAction(0, Keys['F1'], true) -- Disable phone
			DisableControlAction(0, Keys['F2'], true) -- Inventory
			DisableControlAction(0, Keys['F3'], true) -- Animations
			DisableControlAction(0, Keys['F6'], true) -- Job
			DisableControlAction(0, 75, true) -- ARAÇTAN ÇIKMA
			DisableControlAction(0, 157, true) -- disc
			DisableControlAction(0, 303, true) -- disc
			DisableControlAction(0, 158, true) -- disc
			DisableControlAction(0, 160, true) -- disc
			DisableControlAction(0, 164, true) -- disc
			DisableControlAction(0, 165, true) -- disc

			DisableControlAction(0, Keys['X'], true) -- Disable clearing animation
			DisableControlAction(2, Keys['P'], true) -- Disable pause screen

			DisableControlAction(0, 59, true) -- Disable steering in vehicle
			DisableControlAction(0, 71, true) -- Disable driving forward in vehicle
			DisableControlAction(0, 72, true) -- Disable reversing in vehicle

			DisableControlAction(0, 47, true)  -- Disable weapon
			DisableControlAction(0, 264, true) -- Disable melee
			DisableControlAction(0, 257, true) -- Disable melee
			DisableControlAction(0, 140, true) -- Disable melee
			DisableControlAction(0, 141, true) -- Disable melee
			DisableControlAction(0, 142, true) -- Disable melee
			DisableControlAction(0, 143, true) -- Disable melee
			
			if IsEntityPlayingAnim(playerPed, 'mp_arresting', 'idle', 3) ~= 1 then
				QBCore.Functions.RequestAnimDict('mp_arresting', function()
					TaskPlayAnim(playerPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
				end)
			end
		else
			Citizen.Wait(500)
		end
	end
end)

-- Create blips
Citizen.CreateThread(function()

	for k,v in pairs(Config.PoliceStations) do
		local blip = AddBlipForCoord(v.Blip.Coords)

		SetBlipSprite (blip, v.Blip.Sprite)
		SetBlipDisplay(blip, v.Blip.Display)
		SetBlipScale  (blip, v.Blip.Scale)
		SetBlipColour (blip, v.Blip.Colour)
		SetBlipAsShortRange(blip, true)

		BeginTextCommandSetBlipName('STRING')
		AddTextComponentString("LSPD")
		EndTextCommandSetBlipName(blip)
	end

end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if PlayerData.job and PlayerData.job.name == 'police' then

			local playerPed = PlayerPedId()
			local coords    = GetEntityCoords(playerPed)
			local isInMarker, hasExited, letSleep = false, false, true
			local currentStation, currentPart, currentPartNum

			for k,v in pairs(Config.PoliceStations) do

				for i=1, #v.Cloakrooms, 1 do
					local distance = GetDistanceBetweenCoords(coords, v.Cloakrooms[i], true)

					if distance < Config.DrawDistance then
						DrawMarker(20, v.Cloakrooms[i], 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 0.6, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
						letSleep = false
					end

					if distance < Config.MarkerSize.x then
						isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Cloakroom', i
					end
				end

				for i=1, #v.Armories, 1 do
					local distance = GetDistanceBetweenCoords(coords, v.Armories[i], true)

					if distance < Config.DrawDistance then
						DrawMarker(2, v.Armories[i], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.3, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
						letSleep = false
					end

					if distance < Config.MarkerSize.x then
						isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Armory', i
					end
				end

				for i=1, #v.Vehicles, 1 do
					local distance = GetDistanceBetweenCoords(coords, v.Vehicles[i].Spawner, true)

					if distance < Config.DrawDistance then
						DrawMarker(36, v.Vehicles[i].Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
						letSleep = false
					end

					if distance < Config.MarkerSize.x then
						isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Vehicles', i
					end
				end

				for i=1, #v.Helicopters, 1 do
					local distance =  GetDistanceBetweenCoords(coords, v.Helicopters[i].Spawner, true)

					if distance < Config.DrawDistance then
						DrawMarker(34, v.Helicopters[i].Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
						letSleep = false
					end

					if distance < Config.MarkerSize.x then
						isInMarker, currentStation, currentPart, currentPartNum = true, k, 'Helicopters', i
					end
				end

				if Config.EnablePlayerManagement and PlayerData.job.grade_name == 'boss' then
					for i=1, #v.BossActions, 1 do
						local distance = GetDistanceBetweenCoords(coords, v.BossActions[i], true)

						if distance < Config.DrawDistance then
							DrawMarker(22, v.BossActions[i], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, true, false, false, false)
							letSleep = false
						end

						if distance < Config.MarkerSize.x then
							isInMarker, currentStation, currentPart, currentPartNum = true, k, 'BossActions', i
						end
					end
				end
			end

			if isInMarker and not HasAlreadyEnteredMarker or (isInMarker and (LastStation ~= currentStation or LastPart ~= currentPart or LastPartNum ~= currentPartNum)) then
				if
					(LastStation and LastPart and LastPartNum) and
					(LastStation ~= currentStation or LastPart ~= currentPart or LastPartNum ~= currentPartNum)
				then
					TriggerEvent('esx_policejob:hasExitedMarker', LastStation, LastPart, LastPartNum)
					hasExited = true
				end

				HasAlreadyEnteredMarker = true
				LastStation             = currentStation
				LastPart                = currentPart
				LastPartNum             = currentPartNum

				TriggerEvent('esx_policejob:hasEnteredMarker', currentStation, currentPart, currentPartNum)
			end

			if not hasExited and not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_policejob:hasExitedMarker', LastStation, LastPart, LastPartNum)
			end

			if letSleep then
				Citizen.Wait(500)
			end

		else
			Citizen.Wait(500)
		end
	end
end)

-- Enter / Exit entity zone events
Citizen.CreateThread(function()
	local trackedEntities = {
		'prop_roadcone02a',
		'prop_barrier_work05',
		'p_ld_stinger_s',
		'prop_boxpile_07d',
		'hei_prop_cash_crate_half_full'
	}

	while true do
		Citizen.Wait(500)

		local playerPed = PlayerPedId()
		local coords    = GetEntityCoords(playerPed)

		local closestDistance = -1
		local closestEntity   = nil

		for i=1, #trackedEntities, 1 do
			local object = GetClosestObjectOfType(coords, 3.0, GetHashKey(trackedEntities[i]), false, false, false)

			if DoesEntityExist(object) then
				local objCoords = GetEntityCoords(object)
				local distance  = GetDistanceBetweenCoords(coords, objCoords, true)

				if closestDistance == -1 or closestDistance > distance then
					closestDistance = distance
					closestEntity   = object
				end
			end
		end

		if closestDistance ~= -1 and closestDistance <= 3.0 then
			if LastEntity ~= closestEntity then
				TriggerEvent('esx_policejob:hasEnteredEntityZone', closestEntity)
				LastEntity = closestEntity
			end
		else
			if LastEntity then
				TriggerEvent('esx_policejob:hasExitedEntityZone', LastEntity)
				LastEntity = nil
			end
		end
	end
end)

-- Key Controls
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if CurrentAction then
			QBCore.Functions.ShowHelpNotification(CurrentActionMsg)

			if IsControlJustReleased(0, 38) and PlayerData.job and PlayerData.job.name == 'police' then

				if CurrentAction == 'menu_cloakroom' then
					OpenCloakroomMenu()
				--	TriggerEvent("eup:menu4")
				elseif CurrentAction == 'menu_armory' then
					if Config.MaxInService == -1 then
						OpenArmoryMenu(CurrentActionData.station)
					elseif playerInService then
						OpenArmoryMenu(CurrentActionData.station)
					else
						QBCore.Functions.Notify("Serviste Değilsiniz!", "error")
					end
				elseif CurrentAction == 'menu_vehicle_spawner' then
					if Config.MaxInService == -1 then
						OpenVehicleSpawnerMenu('car', CurrentActionData.station, CurrentActionData.part, CurrentActionData.partNum)
					elseif playerInService then
						OpenVehicleSpawnerMenu('car', CurrentActionData.station, CurrentActionData.part, CurrentActionData.partNum)
					else
						QBCore.Functions.Notify("Serviste Değilsiniz!", "error")
					end
				elseif CurrentAction == 'Helicopters' then
					if Config.MaxInService == -1 then
						OpenVehicleSpawnerMenu('helicopter', CurrentActionData.station, CurrentActionData.part, CurrentActionData.partNum)
					elseif playerInService then
						OpenVehicleSpawnerMenu('helicopter', CurrentActionData.station, CurrentActionData.part, CurrentActionData.partNum)
					else
						QBCore.Functions.Notify("Serviste Değilsiniz!", "error")
					end
				elseif CurrentAction == 'delete_vehicle' then
					QBCore.Functions.DeleteVehicle(CurrentActionData.vehicle)
				elseif CurrentAction == 'menu_boss_actions' then
					QBCore.UI.Menu.CloseAll()
					TriggerEvent('esx_society:openBossMenu', 'police', function(data, menu)
						menu.close()

						CurrentAction     = 'menu_boss_actions'
						CurrentActionMsg  = "Patron Menüsünü Aç - ~r~E"
						CurrentActionData = {}
					end, { wash = false }) -- disable washing money
				elseif CurrentAction == 'remove_entity' then
					DeleteEntity(CurrentActionData.entity)
				end

				CurrentAction = nil
			end
		end -- CurrentAction end


		if IsControlJustReleased(0, 167) and not isDead and PlayerData.job and PlayerData.job.name == 'police' and not QBCore.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'police_actions') then
			if Config.MaxInService == -1 then
				OpenPoliceActionsMenu()
			elseif playerInService then
				OpenPoliceActionsMenu()
			else
				QBCore.Functions.Notify("Serviste Değilsiniz!", "error")
			end
		end

		if IsControlJustReleased(0, 38) and currentTask.busy then
			QBCore.Functions.Notify("Araca El Koymayı İptal Ettin!", "error")
			QBCore.Functions.ClearTimeout(currentTask.task)
			ClearPedTasks(PlayerPedId())

			currentTask.busy = false
		end
	end
end)

RegisterCommand("policemenu", function()
	if QBCore.Functions.GetPlayerData().job.name == "police" then
	OpenPoliceActionsMenu()
	end
end)

RegisterKeyMapping('policemenu', 'Polis Menüsü', 'keyboard', 'f6')


-- Create blip for colleagues
function createBlip(id, firstname, lastname)
				
	local playerName = GetPlayerName(id)

    local ped = GetPlayerPed(id)

    local blip = GetBlipFromEntity(ped)

	if not DoesBlipExist(blip) then -- Add blip and create head display on player
		
			blip = AddBlipForEntity(ped)

			SetBlipSprite(blip, 1)

			SetBlipColour(blip, 57)

			ShowHeadingIndicatorOnBlip(blip, true) -- Player Blip indicator

			SetBlipRotation(blip, math.ceil(GetEntityHeading(ped))) -- update rotation

			SetBlipScale(blip, 0.85) -- set scale

			SetBlipAsShortRange(blip, true)

			BeginTextCommandSetBlipName('STRING')

			AddTextComponentString('[~b~LSPD~w~] '.. firstname .. " " .. lastname)

			EndTextCommandSetBlipName(blip)



			table.insert(blipsCops, blip) -- add blip to array so we can remove it later

    end

end

function createBlip2(id, firstname, lastname)

	local playerName = GetPlayerName(id)

    local ped = GetPlayerPed(id)

    local blip = GetBlipFromEntity(ped)



    if not DoesBlipExist(blip) then

        blip = AddBlipForEntity(ped)

        SetBlipSprite(blip, 1)

        SetBlipColour(blip, 1)

        ShowHeadingIndicatorOnBlip(blip, true)

        SetBlipRotation(blip, math.ceil(GetEntityHeading(ped)))

        SetBlipScale(blip, 0.85)

        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')

        AddTextComponentString('[~r~EMS~s~] '.. firstname .. " " .. lastname)

        EndTextCommandSetBlipName(blip)

  

        table.insert(blipsCops, blip)

    end

end
--[[RegisterNetEvent('esx_policejob:updateBlip')
AddEventHandler('esx_policejob:updateBlip', function() --cylex

    -- Refresh all blips

    -- Clean the blip table
    blipsCops = {}

    -- Is the player a cop? In that case show all the blips for other cops
    if PlayerData.job and PlayerData.job.name == 'police' then
        QBCore.Functions.TriggerCallback('esx_society:getOnlinePlayers', function(players)
            for i=1, #players, 1 do
                if players[i].job.name == 'police' and players[i].gps > 0 then
                    local id = GetPlayerFromServerId(players[i].source)
                    if NetworkIsPlayerActive(id) and GetPlayerPed(id) ~= PlayerPedId() then
                        createBlip(id, players[i].firstname, players[i].lastname)
                    end
                end
                if players[i].job.name == 'ambulance' then
                    local id = GetPlayerFromServerId(players[i].source)
                    if NetworkIsPlayerActive(id) and GetPlayerPed(id) ~= PlayerPedId() then
                        createBlip2(id, players[i].firstname, players[i].lastname)
                    end
                end
            end
		end)
	elseif PlayerData.job and PlayerData.job.name == 'ambulance' then
			QBCore.Functions.TriggerCallback('esx_society:getOnlinePlayers', function(players)
				for i=1, #players, 1 do
					if players[i].job.name == 'ambulance' then
						local id = GetPlayerFromServerId(players[i].source)
						if NetworkIsPlayerActive(id) and GetPlayerPed(id) ~= PlayerPedId() then
							createBlip2(id, players[i].firstname, players[i].lastname)
						end
					end
				end
			end)
    end

end)]]

RegisterNetEvent('esx_policejob:removeBlip')
AddEventHandler('esx_policejob:removeBlip', function()

    -- Refresh all blips
    for k, existingBlip in pairs(blipsCops) do
        RemoveBlip(existingBlip)
    end

    -- Clean the blip table
    blipsCops = {}
end)

AddEventHandler('playerSpawned', function(spawn)
	isDead = false
	TriggerEvent('esx_policejob:unrestrain')

	if not hasAlreadyJoined then
		TriggerServerEvent('esx_policejob:spawned')
	end
	hasAlreadyJoined = true
end)

AddEventHandler('esx:onPlayerDeath', function(data)
	isDead = true
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('esx_policejob:unrestrain')
		TriggerEvent('esx_phone:removeSpecialContact', 'police')

		if Config.MaxInService ~= -1 then
			TriggerServerEvent('esx_service:disableService', 'police')
		end

		if Config.EnableHandcuffTimer and handcuffTimer.active then
			QBCore.Functions.ClearTimeout(handcuffTimer.task)
		end
	end
end)

-- handcuff timer, unrestrain the player after an certain amount of time
function StartHandcuffTimer()
	if Config.EnableHandcuffTimer and handcuffTimer.active then
		QBCore.Functions.ClearTimeout(handcuffTimer.task)
	end

	handcuffTimer.active = true

	handcuffTimer.task = QBCore.Functions.SetTimeout(Config.HandcuffTimer, function()
		QBCore.Functions.Notify("Kelepçeleriniz Gevşedi!", "error")
		TriggerEvent('esx_policejob:unrestrain')
		handcuffTimer.active = false
	end)
end

-- TODO
--   - return to garage if owned
--   - message owner that his vehicle has been impounded
function ImpoundVehicle(vehicle)
	--local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
	QBCore.Functions.DeleteVehicle(vehicle)
	QBCore.Functions.Notify("Araç Başarıyla Çekildi!", "success")
	currentTask.busy = false
end

function loadanimdict(dictname)
	if not HasAnimDictLoaded(dictname) then
		RequestAnimDict(dictname) 
		while not HasAnimDictLoaded(dictname) do 
			Citizen.Wait(1)
		end
	end
end


RegisterNetEvent("esx_policejob:kelepce")
AddEventHandler("esx_policejob:kelepce", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
        local target, distance = QBCore.Functions.GetClosestPlayer()
			playerheading = GetEntityHeading(GetPlayerPed(-1))
			playerlocation = GetEntityForwardVector(PlayerPedId())
			playerCoords = GetEntityCoords(GetPlayerPed(-1))
		local target_id = GetPlayerServerId(target)
			if distance <= 2.0 then
				
				TriggerServerEvent('esx_policejob:requestarrest', target_id, playerheading, playerCoords, playerlocation)

			else
				QBCore.Functions.Notify("Kelepçelemek için çok uzaktasın!", "error")
			end
    end
end)

RegisterNetEvent("esx_policejob:aracabindir")
AddEventHandler("esx_policejob:aracabindir", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerServerEvent('esx_policejob:putInVehicle', GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:openkimlik")
AddEventHandler("esx_policejob:openkimlik", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		OpenIdentityCardMenu(closestPlayer)
		end
end)

RegisterNetEvent("esx_policejob:ustarama")
AddEventHandler("esx_policejob:ustarama", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		OpenBodySearchMenu(closestPlayer)
		end
end)

RegisterNetEvent("esx_policejob:kelepcecoz")
AddEventHandler("esx_policejob:kelepcecoz", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
								local target, distance = QBCore.Functions.GetClosestPlayer()
						playerheading = GetEntityHeading(GetPlayerPed(-1))
						playerlocation = GetEntityForwardVector(PlayerPedId())
						playerCoords = GetEntityCoords(GetPlayerPed(-1))
						local target_id = GetPlayerServerId(target)
						if distance <= 2.0 then
							TriggerServerEvent('esx_policejob:requestrelease', target_id, playerheading, playerCoords, playerlocation)
						else
							QBCore.Functions.Notify("Kelepçeyi çözmek için çok uzaktasın!", "error")
						end
		end
end)

RegisterNetEvent("esx_policejob:drags")
AddEventHandler("esx_policejob:drags", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerServerEvent('esx_policejob:drag', GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:outcar")
AddEventHandler("esx_policejob:outcar", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerServerEvent('esx_policejob:OutVehicle', GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:outcar")
AddEventHandler("esx_policejob:outcar", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerServerEvent('esx_policejob:OutVehicle', GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:faturakes")
AddEventHandler("esx_policejob:faturakes", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		OpenFineMenu(closestPlayer)
		end
end)

RegisterNetEvent("esx_policejob:faturakontrol")
AddEventHandler("esx_policejob:faturakontrol", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		OpenUnpaidBillsMenu(closestPlayer)
		end
end)

RegisterNetEvent("esx_policejob:gsr")
AddEventHandler("esx_policejob:gsr", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerServerEvent('GSR:Status2', GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:kamu")
AddEventHandler("esx_policejob:kamu", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		SendToCommunityService(GetPlayerServerId(closestPlayer))
		end
end)

RegisterNetEvent("esx_policejob:lisans")
AddEventHandler("esx_policejob:lisans", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
		QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		ShowPlayerLicense(closestPlayer)
		end
end)

RegisterNetEvent("esx_policejob:readvehicle")
AddEventHandler("esx_policejob:readvehicle", function()
	local vehicle = QBCore.Functions.GetVehicleInDirection()
	local vehicleData = QBCore.Functions.GetVehicleProperties(vehicle)
	OpenVehicleInfosMenu(vehicleData)
end)

RegisterNetEvent("esx_policejob:lockpick")
AddEventHandler("esx_policejob:lockpick", function()
						local vehicle = QBCore.Functions.GetVehicleInDirection()
						local playerPed = PlayerPedId()
						local coords  = GetEntityCoords(playerPed)
						if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
							TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_WELDING', 0, true)
							Citizen.Wait(20000)
							ClearPedTasksImmediately(playerPed)
							SetVehicleDoorsLocked(vehicle, 1)
							SetVehicleDoorsLockedForAllPlayers(vehicle, false)
							QBCore.Functions.Notify("Araç Kilidi Açıldı!", "error")
						end
end)

RegisterNetEvent("esx_policejob:impoundveh")
AddEventHandler("esx_policejob:impoundveh", function()
					local CurrentTask             = {}
					local vehicle = QBCore.Functions.GetVehicleInDirection()
					local playerPed = PlayerPedId()
					local coords  = GetEntityCoords(playerPed)
						-- is the script busy?
						if currentTask.busy then
							return
						end

						QBCore.Functions.ShowHelpNotification(_U('impound_prompt'))
						TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)

						currentTask.busy = true
						currentTask.task = QBCore.Functions.SetTimeout(10000, function()
							ClearPedTasks(playerPed)
							ImpoundVehicle(vehicle)
							Citizen.Wait(100) -- sleep the entire script to let stuff sink back to reality
						end)

						-- keep track of that vehicle!
						Citizen.CreateThread(function()
							while currentTask.busy do
								Citizen.Wait(1000)

								vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
								if not DoesEntityExist(vehicle) and currentTask.busy then
									QBCore.Functions.Notify("Araç Çekme İşlemi İptal Edildi", "error")
									QBCore.Functions.ClearTimeout(currentTask.task)
									ClearPedTasks(playerPed)
									currentTask.busy = false
									break
								end
							end
						end)
end)


RegisterNetEvent("esx_policejob:jail")
AddEventHandler("esx_policejob:jail", function()
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()

    if closestPlayer == -1 or closestDistance > 2.0 then
        QBCore.Functions.Notify("Yakında Kimse Yok!", "error")
    else
		TriggerEvent("esx-qalle-jail:openJailMenu", src)
		end
end)



