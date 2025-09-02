-- client/main.lua - Complete gang client system (FIXED DRAG SYSTEM)

local playerGang = nil
local playerInService = false
local currentGangConfig = nil
local spawnedNPCs = {}
local cuffedPlayersLocal = {}
local isDragging = false
local draggingID = 0
local isCuffed = false
local currentBlip = nil

-- Drag system variables (FIXED)
local dragThread = nil
local currentDragger = nil

ESX = exports['es_extended']:getSharedObject()

-- Player loaded event
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    ESX.PlayerLoaded = true
    checkPlayerGang()
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
    cleanupGang()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
    checkPlayerGang()
end)

function checkPlayerGang()
    if ESX.PlayerData and ESX.PlayerData.job then
        local jobName = ESX.PlayerData.job.name
        if Config.Gangs[jobName] then
            playerGang = jobName
            currentGangConfig = Config.Gangs[jobName]
            initializeGang()
        else
            cleanupGang()
        end
    end
end

function initializeGang()
    if not currentGangConfig then return end
    createGangNPC()
    setupTargetZones()
    setupGlobalInteractions()
    Wait(1000)
    TriggerServerEvent('gang:forceBlip')
end

function cleanupGang()
    for _, ped in pairs(spawnedNPCs) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedNPCs = {}
    playerGang = nil
    currentGangConfig = nil
    if currentBlip then
        RemoveBlip(currentBlip)
        currentBlip = nil
    end
    
    -- Clean up drag state
    if dragThread then
        dragThread = nil
    end
    currentDragger = nil
    isDragging = false
    draggingID = 0
end

function createGangNPC()
    if not currentGangConfig or not currentGangConfig.locations.npc then return end
    
    local npcData = currentGangConfig.locations.npc
    local modelHash = GetHashKey(npcData.model)
    
    lib.requestModel(modelHash)
    
    local ped = CreatePed(0, modelHash, npcData.coords.x, npcData.coords.y, npcData.coords.z - 1, npcData.rotation, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_AA_SMOKE", 0, true)
    
    spawnedNPCs[#spawnedNPCs + 1] = ped
end

function setupTargetZones()
    if not currentGangConfig then return end
    
    local locations = currentGangConfig.locations
    local ox_target = exports.ox_target
    
    -- Main area (storage, boss storage)
    ox_target:addSphereZone({
        coords = locations.main,
        radius = 1,
        options = {
            {
                name = "gang:openStorage:" .. playerGang,
                event = "gang:openStorage:" .. playerGang,
                icon = "fas fa-vault",
                label = Config.Locales['storage'],
                groups = playerGang,
                canInteract = function()
                    return not Config.EnableESXService or playerInService
                end,
            },
            {
                name = "gang:openBossStorage:" .. playerGang,
                event = "gang:openBossStorage:" .. playerGang,
                icon = "fas fa-vault",
                label = Config.Locales['boss_storage'],
                canInteract = function()
                    return ESX.PlayerData.job.grade >= currentGangConfig.bossRank and (not Config.EnableESXService or playerInService)
                end,
                groups = {[playerGang] = currentGangConfig.bossRank}
            }
        }
    })
    
    -- Cloakroom
    ox_target:addSphereZone({
        coords = locations.cloakroom,
        radius = 1,
        options = {
            {
                name = "gang:openCloakroom:" .. playerGang,
                event = "gang:openCloakroom:" .. playerGang,
                icon = "fas fa-tshirt",
                label = Config.Locales['change_clothes'],
                groups = playerGang,
            }
        }
    })
    
    -- Boss actions
    ox_target:addSphereZone({
        coords = locations.boss,
        radius = 1,
        options = {
            {
                name = "gang:bossMenu:" .. playerGang,
                event = "gang:bossMenu:" .. playerGang,
                icon = "fas fa-address-card",
                label = Config.Locales['boss_menu'],
                groups = {[playerGang] = currentGangConfig.bossRank}
            }
        }
    })
    
    -- Vehicle spawner
    if locations.vehicles then
        ox_target:addSphereZone({
            coords = locations.vehicles.spawner,
            radius = 1,
            options = {
                {
                    name = "gang:openVehicleMenu:" .. playerGang,
                    event = "gang:openVehicleMenu:" .. playerGang,
                    icon = "fas fa-car",
                    label = Config.Locales['vehicle_menu'],
                    groups = playerGang,
                    canInteract = function()
                        return not Config.EnableESXService or playerInService
                    end,
                }
            }
        })
    end
end

function setupGlobalInteractions()
    local ox_target = exports.ox_target
    
    ox_target:addGlobalPlayer({
        {
            icon = "fa-solid fa-handcuffs",
            label = Config.Locales['cuff_person'],
            distance = 2.0,
            canInteract = function(entity)
                if not playerGang then return false end
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return not cuffedPlayersLocal[targetId]
            end,
            onSelect = function(data) 
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                
                ESX.TriggerServerCallback('gang:checkZiptie', function(hasZiptie)
                    if not hasZiptie then
                        lib.notify({
                            title = 'Gang System',
                            description = Config.Locales['no_ziptie'],
                            type = 'error',
                            duration = 3000
                        })
                        return
                    end
                    
                    local success = lib.progressCircle({
                        duration = 3000,
                        label = Config.Locales['handcuffing_player'],
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = false,
                        anim = {
                            dict = 'mp_arrest_paired',
                            clip = 'cop_p2_back_right',
                            flag = 0
                        },
                        disable = {
                            move = true,
                            combat = true,
                            car = true
                        }
                    })
                    
                    if success then
                        lib.callback('gauja-sv:CuffPlayer', false, function(state)
                            if state then
                                cuffedPlayersLocal[targetId] = true
                                lib.notify({
                                    title = 'Gang System',
                                    description = Config.Locales['player_cuffed'],
                                    type = 'success',
                                    duration = 3000
                                })
                            end
                        end, targetId)
                    end
                end)
            end
        },
        {
            icon = "fa-solid fa-unlock",
            label = "Uncuff person", 
            distance = 2.0,
            canInteract = function(entity)
                if not playerGang then return false end
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return cuffedPlayersLocal[targetId] == true
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                
                local success = lib.progressCircle({
                    duration = 3000,
                    label = Config.Locales['uncuffing_player'],
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = false,
                    anim = {
                        dict = 'mp_arresting',
                        clip = 'a_uncuff',
                        flag = 0
                    },
                    disable = {
                        move = true,
                        combat = true,
                        car = true
                    }
                })
                
                if success then
                    lib.callback('gauja-sv:CuffPlayer', false, function(state)
                        if state then
                            cuffedPlayersLocal[targetId] = false
                            lib.notify({
                                title = 'Gang System',
                                description = Config.Locales['player_uncuffed'],
                                type = 'success',
                                duration = 3000
                            })
                        end
                    end, targetId)
                end
            end
        },
        {
            icon = "fa-solid fa-handshake-angle",
            label = Config.Locales['drag_person'],
            distance = 2.0,
            canInteract = function(entity)
                if not playerGang then return false end
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return cuffedPlayersLocal[targetId] == true and not isDragging
            end,
            onSelect = function(data) 
                local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                
                lib.callback('gauja:dragPlayer', false, function(success)
                    if success then
                        isDragging = true
                        draggingID = target
                        lib.showTextUI('[X] - ' .. Config.Locales['stop_dragging'], { 
                            icon = "people-pulling" 
                        })
                    end
                end, target)
            end
        },
        {
            icon = "fa-solid fa-car",
            label = Config.Locales['put_in_vehicle'],
            distance = 2.0,
            canInteract = function(entity)
                if not playerGang then return false end
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return cuffedPlayersLocal[targetId] == true
            end,
            onSelect = function(data)
                TriggerServerEvent('gang:putInVehicle', GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity)))
            end
        },
        {
            icon = "fa-solid fa-magnifying-glass",
            label = Config.Locales['search_person'],
            distance = 2.0,
            canInteract = function(entity)
                if not playerGang then return false end
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                return cuffedPlayersLocal[targetId] == true
            end,
            onSelect = function(data)
                exports.ox_inventory:openInventory('player', GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity)))
            end
        },
    })
    
    -- Vehicle interactions
    ox_target:addGlobalVehicle({
        {
            name = 'gang:outVehicle',
            icon = 'fa-solid fa-car',
            label = Config.Locales['remove_from_vehicle'],
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                return playerGang and (Config.EnableESXService and playerInService or true)
            end,
            onSelect = function(data)
                local entity = data.entity
                local maxSeats = GetVehicleMaxNumberOfPassengers(entity)
                
                for i = maxSeats - 1, 0, -1 do
                    local seatPed = GetPedInVehicleSeat(entity, i)
                    if seatPed ~= 0 then
                        local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(seatPed))
                        TriggerServerEvent('gang:outVehicle', serverId)
                    end
                end
            end
        }
    })
end

-- Event handlers for gang actions
for gangName, gangConfig in pairs(Config.Gangs) do
    RegisterNetEvent('gang:openStorage:' .. gangName)
    AddEventHandler('gang:openStorage:' .. gangName, function()
        local ox_inventory = exports.ox_inventory
        TriggerServerEvent('gang:openStorage:' .. gangName)
        ox_inventory:openInventory('stash', gangName)
    end)
    
    RegisterNetEvent('gang:openBossStorage:' .. gangName)
    AddEventHandler('gang:openBossStorage:' .. gangName, function()
        local ox_inventory = exports.ox_inventory
        TriggerServerEvent('gang:openBossStorage:' .. gangName)
        ox_inventory:openInventory('stash', gangName .. 'boss')
    end)
    
    RegisterNetEvent('gang:openCloakroom:' .. gangName)
    AddEventHandler('gang:openCloakroom:' .. gangName, function()
        openCloakroomMenu(gangConfig)
    end)
    
    RegisterNetEvent('gang:bossMenu:' .. gangName)
    AddEventHandler('gang:bossMenu:' .. gangName, function()
        TriggerEvent('esx_society:openBossMenu', gangName, function(data, menu)
            menu.close()
        end, { wash = false })
    end)
    
    RegisterNetEvent('gang:openVehicleMenu:' .. gangName)
    AddEventHandler('gang:openVehicleMenu:' .. gangName, function()
        openVehicleSpawnerMenu()
    end)
end

-- Cloakroom system
function openCloakroomMenu(gang)
    local elements = {
        {
            title = Config.Locales['civilian_clothes'],
            description = Config.Locales['civilian_clothes_desc'],
            icon = 'shirt',
            onSelect = function()
                changeToCivilian()
            end
        }
    }

    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(appearance)
        local uniforms = gang.uniforms[appearance.sex == 0 and 'male' or 'female'] or {}
        
        for _, uniform in ipairs(uniforms) do
            elements[#elements+1] = {
                title = uniform.name,
                description = Config.Locales['work_uniform'],
                icon = 'user-tie',
                onSelect = function()
                    changeToUniform(uniform)
                end
            }
        end
        
        lib.registerContext({
            id = 'gang_cloakroom',
            title = Config.Locales['wardrobe'],
            options = elements
        })
        
        lib.showContext('gang_cloakroom')
    end)
end

function changeToCivilian()
    local progress = lib.progressBar({
        duration = 5000,
        label = Config.Locales['changing_clothes'],
        useWhileDead = false,
        canCancel = true,
        anim = { dict = 'clothingtie', clip = 'try_tie_negative_a' },
        disable = { move = true, combat = true }
    })

    if not progress then return end

    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(appearance)
        exports['fivem-appearance']:setPedComponents(cache.ped, appearance.components)
        exports['fivem-appearance']:setPedProps(cache.ped, appearance.props)
    end)

    if Config.EnableESXService then
        TriggerServerEvent('esx_service:disableService', playerGang)
        ESX.ShowNotification(Config.Locales['service_out'])
        playerInService = false
    end
end

function changeToUniform(uniform)
    local progress = lib.progressBar({
        duration = 5000,
        label = Config.Locales['changing_clothes'],
        useWhileDead = false,
        canCancel = true,
        anim = { dict = 'clothingtie', clip = 'try_tie_negative_a' },
        disable = { move = true, combat = true }
    })

    if not progress then return end

    setUniform(uniform, cache.ped)

    if Config.EnableESXService then
        ESX.TriggerServerCallback('esx_service:isInService', function(isInService, playerName)
            if not isInService then
                ESX.TriggerServerCallback('esx_service:enableService', function(canTakeService, maxInService, inServiceCount)
                    if not canTakeService then
                        ESX.ShowNotification('Service full: ' .. inServiceCount .. '/' .. maxInService)
                    else
                        ESX.ShowNotification(Config.Locales['service_in'])
                        playerInService = true
                    end
                end, playerGang)
            end
        end, playerGang)
    end
end

function setUniform(uniform, ped)
    if uniform.components then
        for _, comp in ipairs(uniform.components) do
            exports['fivem-appearance']:setPedComponent(ped, {
                component_id = comp.component_id,
                drawable = comp.drawable,
                texture = comp.texture,
            })
        end
    end

    if uniform.props then
        for _, prop in ipairs(uniform.props) do
            exports['fivem-appearance']:setPedProp(ped, {
                prop_id = prop.prop_id,
                drawable = prop.drawable,
                texture = prop.texture,
            })
        end
    end

    if uniform.armour then
        SetPedArmour(ped, 100)
    else
        SetPedArmour(ped, 0)
    end
end

-- Vehicle spawner menu
function openVehicleSpawnerMenu()
    if not currentGangConfig or not ESX.PlayerData then return end
    
    local elements = {
        {
            title = Config.Locales['garage_storeditem'],
            description = 'Open garage to get your vehicles',
            icon = 'warehouse',
            onSelect = function()
                openGarageMenu()
            end
        },
        {
            title = Config.Locales['garage_storeitem'],
            description = 'Store nearby vehicle',
            icon = 'square-parking',
            onSelect = function()
                storeNearbyVehicle()
            end
        },
        {
            title = Config.Locales['garage_buyitem'],
            description = 'Buy new vehicles',
            icon = 'car',
            onSelect = function()
                openVehicleShop()
            end
        }
    }
    
    lib.registerContext({
        id = 'gang_vehicle_menu',
        title = Config.Locales['vehicle_menu'],
        options = elements
    })
    
    lib.showContext('gang_vehicle_menu')
end

function openVehicleShop()
    if not currentGangConfig or not ESX.PlayerData then return end
    
    local jobGrade = ESX.PlayerData.job.grade_name
    local availableVehicles = currentGangConfig.vehicles[jobGrade] or {}
    
    if #availableVehicles == 0 then
        lib.notify({
            title = 'Gang System',
            description = Config.Locales['garage_notauthorized'],
            type = 'error',
            duration = 3000
        })
        return
    end
    
    local elements = {}
    for _, vehicle in ipairs(availableVehicles) do
        elements[#elements+1] = {
            title = GetDisplayNameFromVehicleModel(vehicle.model),
            description = Config.Locales['shop_item'],
            icon = 'car',
            onSelect = function()
                purchaseVehicle(vehicle)
            end
        }
    end
    
    lib.registerContext({
        id = 'gang_vehicle_shop',
        title = Config.Locales['vehicleshop_title'],
        options = elements
    })
    
    lib.showContext('gang_vehicle_shop')
end

function purchaseVehicle(vehicleData)
    local input = lib.inputDialog(Config.Locales['vehicleshop_confirm'], {
        {type = 'input', label = 'Vehicle Plate', required = true, max = 8}
    })
    
    if not input or not input[1] then return end
    
    local plate = string.upper(input[1])
    if string.len(plate) > 8 then
        lib.notify({
            title = 'Gang System',
            description = 'Plate too long (max 8 characters)',
            type = 'error',
            duration = 3000
        })
        return
    end
    
    local vehicleProps = {
        model = GetHashKey(vehicleData.model),
        plate = plate
    }
    
    ESX.TriggerServerCallback('gang:buyJobVehicle', function(success)
        if success then
            lib.notify({
                title = 'Gang System',
                description = Config.Locales['vehicleshop_bought'],
                type = 'success',
                duration = 3000
            })
        else
            lib.notify({
                title = 'Gang System',
                description = 'Failed to purchase vehicle',
                type = 'error',
                duration = 3000
            })
        end
    end, vehicleProps, playerGang)
end

function openGarageMenu()
    ESX.TriggerServerCallback('gang:getOwnedVehicles', function(vehicles)
        if #vehicles == 0 then
            lib.notify({
                title = 'Gang System',
                description = Config.Locales['garage_empty'],
                type = 'error',
                duration = 3000
            })
            return
        end
        
        local elements = {}
        for _, vehicle in ipairs(vehicles) do
            local stored = vehicle.stored and Config.Locales['garage_stored'] or Config.Locales['garage_notstored']
            elements[#elements+1] = {
                title = GetDisplayNameFromVehicleModel(vehicle.vehicle.model) .. ' [' .. vehicle.plate .. ']',
                description = stored,
                icon = vehicle.stored and 'car' or 'car-burst',
                onSelect = function()
                    if vehicle.stored then
                        spawnVehicle(vehicle)
                    else
                        lib.notify({
                            title = 'Gang System',
                            description = Config.Locales['garage_notstored'],
                            type = 'error',
                            duration = 3000
                        })
                    end
                end
            }
        end
        
        lib.registerContext({
            id = 'gang_garage',
            title = Config.Locales['garage_title'],
            options = elements
        })
        
        lib.showContext('gang_garage')
    end, playerGang)
end

function spawnVehicle(vehicleData)
    if not currentGangConfig.locations.vehicles.spawnPoints then return end
    
    local spawnPoint = nil
    for _, point in ipairs(currentGangConfig.locations.vehicles.spawnPoints) do
        if ESX.Game.IsSpawnPointClear(point.coords, point.radius) then
            spawnPoint = point
            break
        end
    end
    
    if not spawnPoint then
        lib.notify({
            title = 'Gang System',
            description = Config.Locales['garage_blocked'],
            type = 'error',
            duration = 3000
        })
        return
    end
    
    ESX.TriggerServerCallback('gang:setVehicleState', function(success)
        if success then
            ESX.Game.SpawnVehicle(vehicleData.vehicle.model, spawnPoint.coords, spawnPoint.heading, function(vehicle)
                ESX.Game.SetVehicleProperties(vehicle, vehicleData.vehicle)
                lib.notify({
                    title = 'Gang System',
                    description = Config.Locales['garage_released'],
                    type = 'success',
                    duration = 3000
                })
            end)
        end
    end, vehicleData.plate, false)
end

function storeNearbyVehicle()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = nil
    
    if IsPedInAnyVehicle(playerPed) then
        vehicle = GetVehiclePedIsIn(playerPed, false)
    else
        vehicle = ESX.Game.GetClosestVehicle(coords)
    end
    
    if vehicle == 0 or #(coords - GetEntityCoords(vehicle)) > 5.0 then
        lib.notify({
            title = 'Gang System',
            description = Config.Locales['garage_store_nearby'],
            type = 'error',
            duration = 3000
        })
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local progress = lib.progressBar({
        duration = 3000,
        label = Config.Locales['garage_storing'],
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true }
    })
    
    if not progress then return end
    
    ESX.TriggerServerCallback('gang:storeNearbyVehicle', function(success)
        if success then
            ESX.Game.DeleteVehicle(vehicle)
            lib.notify({
                title = 'Gang System',
                description = Config.Locales['garage_has_stored'],
                type = 'success',
                duration = 3000
            })
        else
            lib.notify({
                title = 'Gang System',
                description = Config.Locales['garage_has_notstored'],
                type = 'error',
                duration = 3000
            })
        end
    end, {plate})
end

-- Initialize on resource start
CreateThread(function()
    Wait(1000)
    if ESX.PlayerLoaded then
        checkPlayerGang()
    end
end)

-- Cuffed state management (FIXED ANIMATION CLEARING)
RegisterNetEvent('gauja-cl:syncCuff')
AddEventHandler('gauja-cl:syncCuff', function()
    print("DEBUG: Received syncCuff event")
    local plyPed = PlayerPedId()
    isCuffed = true
    
    ClearPedTasksImmediately(plyPed)
    SetEnableHandcuffs(plyPed, true)
    SetCurrentPedWeapon(plyPed, `WEAPON_UNARMED`, true)
    
    RequestAnimDict('mp_arresting')
    while not HasAnimDictLoaded('mp_arresting') do
        Wait(100)
    end
    TaskPlayAnim(plyPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
    
    startCuffThread()
    print("DEBUG: Player is now cuffed")
end)

RegisterNetEvent('gauja-cl:syncUnCuff')
AddEventHandler('gauja-cl:syncUnCuff', function()
    print("DEBUG: Received syncUnCuff event")
    local plyPed = PlayerPedId()
    isCuffed = false
    
    -- NUCLEAR OPTION - Complete animation reset
    SetEnableHandcuffs(plyPed, false)
    ClearPedTasksImmediately(plyPed)
    ClearPedSecondaryTask(plyPed)
    SetPedCanPlayGestureAnims(plyPed, true)
    
    -- Force complete animation clear
    RequestAnimDict('move_m@generic')
    while not HasAnimDictLoaded('move_m@generic') do
        Wait(100)
    end
    
    -- Reset to normal movement
    TaskPlayAnim(plyPed, 'move_m@generic', 'idle', 8.0, -8, 1000, 0, 0, 0, 0, 0)
    
    Wait(1000)
    ClearPedTasks(plyPed)
    
    -- Final reset
    SetPedMovementClipset(plyPed, 'move_m@generic', 0.25)
    ResetPedMovementClipset(plyPed, 1000)
    
    print("DEBUG: Player animation completely reset")
end)

function startCuffThread()
    CreateThread(function()
        while isCuffed do
            Wait(0)
            local plyPed = PlayerPedId()
            
            -- Disable controls
            DisableControlAction(0, 21, true) -- Sprint
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 45, true) -- Reload
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 44, true) -- Cover
            DisableControlAction(0, 37, true) -- Select Weapon
            DisableControlAction(0, 23, true) -- Enter
            DisableControlAction(0, 288, true) -- Phone
            DisableControlAction(0, 289, true) -- Inventory
            DisableControlAction(0, 323, true) -- Animations
            DisableControlAction(0, 167, true) -- Job
            DisableControlAction(0, 0, true) -- Changing view
            DisableControlAction(0, 26, true) -- Looking behind
            DisableControlAction(0, 73, true) -- X KEY - prevents hands up escape
            DisableControlAction(2, 199, true) -- Pause screen
            DisableControlAction(0, 59, true) -- Steering
            DisableControlAction(0, 71, true) -- Drive forward
            DisableControlAction(0, 72, true) -- Reverse
            DisableControlAction(2, 36, true) -- Stealth
            DisableControlAction(0, 47, true) -- Weapon
            DisableControlAction(0, 264, true) -- Melee
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee
            DisableControlAction(0, 143, true) -- Melee
            DisableControlAction(0, 75, true) -- Exit vehicle
            DisableControlAction(27, 75, true) -- Exit vehicle
            DisablePlayerFiring(plyPed, true)
            
            -- Keep animation active
            if not IsEntityPlayingAnim(plyPed, 'mp_arresting', 'idle', 3) then
                if not ESX.PlayerData.dead then
                    TaskPlayAnim(plyPed, 'mp_arresting', 'idle', 8.0, -8, -1, 49, 0, 0, 0, 0)
                end
            end
        end
        
        ClearPedSecondaryTask(plyPed)
        SetEnableHandcuffs(plyPed, false)
        SetPedCanPlayGestureAnims(plyPed, true)
    end)
end

-- Dragging system (COMPLETELY FIXED)
RegisterNetEvent('gauja-cl:syncDrag')
AddEventHandler('gauja-cl:syncDrag', function(dragerId)
    print("DEBUG: Received syncDrag event from", dragerId)
    local playerPed = PlayerPedId()
    local draggerPed = GetPlayerPed(GetPlayerFromServerId(dragerId))
    
    -- Stop any existing drag thread
    if dragThread then
        dragThread = nil
    end
    
    currentDragger = dragerId
    
    -- Start new drag thread
    dragThread = CreateThread(function()
        while currentDragger and DoesEntityExist(draggerPed) do
            Wait(1)
            
            -- Only attach if cuffed and dragger exists
            if isCuffed and DoesEntityExist(draggerPed) then
                if not IsPedSittingInAnyVehicle(draggerPed) then
                    -- Ensure proper attachment
                    if not IsEntityAttachedToEntity(playerPed, draggerPed) then
                        AttachEntityToEntity(playerPed, draggerPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    end
                else
                    -- Dragger in vehicle, stop drag
                    print("DEBUG: Dragger in vehicle, stopping drag")
                    break
                end
                
                -- Dead player check
                if ESX.PlayerData.dead then
                    print("DEBUG: Player dead, stopping drag")
                    break
                end
            else
                print("DEBUG: Not cuffed or dragger missing, stopping drag")
                break
            end
        end
        
        -- Clean exit
        print("DEBUG: Drag thread ending, detaching")
        DetachEntity(playerPed, true, false)
        currentDragger = nil
        dragThread = nil
    end)
end)

-- Single undrag handler (FIXED - NO MORE DUPLICATES)
RegisterNetEvent('gauja-cl:syncUnDrag')
AddEventHandler('gauja-cl:syncUnDrag', function()
    print("DEBUG: Received syncUnDrag event")
    local playerPed = PlayerPedId()
    
    -- Stop drag thread
    if dragThread then
        dragThread = nil
        print("DEBUG: Stopped drag thread")
    end
    
    -- Clear dragger
    currentDragger = nil
    
    -- Force detachment from everything
    if IsEntityAttachedToAnyPed(playerPed) then
        DetachEntity(playerPed, true, false)
        print("DEBUG: Force detached from any ped")
    end
    
    if IsEntityAttachedToAnyVehicle(playerPed) then
        DetachEntity(playerPed, true, false)
        print("DEBUG: Force detached from any vehicle")
    end
    
    -- Nuclear detachment option
    DetachEntity(playerPed, true, false)
    
    print("DEBUG: UnDrag complete")
end)

-- Stop dragging command (SIMPLIFIED)
RegisterCommand('stopgaujaDrag', function()
    print("DEBUG: Stop drag command called, isDragging =", isDragging, "draggingID =", draggingID)
    if isDragging and draggingID > 0 then
        lib.callback('gauja:unDrag', false, function(state)
            print("DEBUG: Stop drag result =", state)
            if state then
                isDragging = false
                draggingID = 0
                lib.hideTextUI()
                print("DEBUG: Drag stopped via command")
            end
        end, draggingID)
    else
        print("DEBUG: Not dragging anyone")
    end
end, false)

RegisterKeyMapping('stopgaujaDrag', 'Sustoti Tempimą', 'keyboard', "X")

-- X key monitoring (CLEANED UP)
CreateThread(function()
    while true do
        Wait(0)
        if isDragging and draggingID > 0 then
            if IsControlJustPressed(0, 73) then -- X key
                print("DEBUG: X key detected, stopping drag")
                lib.callback('gauja:unDrag', false, function(state)
                    print("DEBUG: Direct X stop result =", state)
                    if state then
                        isDragging = false
                        draggingID = 0
                        lib.hideTextUI()
                    end
                end, draggingID)
            end
        else
            Wait(1000)
        end
    end
end)

-- Update cuffed state when server tells us
RegisterNetEvent('gang:updateCuffedState')
AddEventHandler('gang:updateCuffedState', function(playerId, isCuffedState)
    print("DEBUG: Server updating cuffed state for player", playerId, "to", isCuffedState)
    cuffedPlayersLocal[playerId] = isCuffedState
end)

-- Vehicle management events
RegisterNetEvent('gang:putInNearestVehicle')
AddEventHandler('gang:putInNearestVehicle', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = ESX.Game.GetClosestVehicle(coords)
    
    if vehicle ~= 0 and #(coords - GetEntityCoords(vehicle)) < 5.0 then
        local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
        for i = 0, maxSeats do
            if IsVehicleSeatFree(vehicle, i) then
                TaskWarpPedIntoVehicle(playerPed, vehicle, i)
                break
            end
        end
    end
end)

RegisterNetEvent('gang:removeFromVehicle')
AddEventHandler('gang:removeFromVehicle', function()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 16)
    end
end)

-- Blip creation
RegisterNetEvent('gang:createBlip')
AddEventHandler('gang:createBlip', function(gangConfig)
    if not Config.EnableJobBlip then return end
    
    if currentBlip then
        RemoveBlip(currentBlip)
    end
    
    currentBlip = AddBlipForCoord(gangConfig.locations.main.x, gangConfig.locations.main.y, gangConfig.locations.main.z)
    SetBlipSprite(currentBlip, gangConfig.blipSprite)
    SetBlipDisplay(currentBlip, 4)
    SetBlipScale(currentBlip, 1.0)
    SetBlipColour(currentBlip, gangConfig.blipColor)
    SetBlipAsShortRange(currentBlip, true)
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(gangConfig.name)
    EndTextCommandSetBlipName(currentBlip)
end)

-- Service management
RegisterNetEvent('gang:setPlayerInService')
AddEventHandler('gang:setPlayerInService', function(status)
    playerInService = status
end)

RegisterNetEvent('esx_service:playerDutyRestored')
AddEventHandler('esx_service:playerDutyRestored', function(jobName, isOnDuty)
    if Config.Gangs[jobName] then
        playerInService = isOnDuty
    end
end)

-- Utility function
function checkTable(table, identifier)
    for k, v in pairs(table) do
        if v == identifier then
            return true
        end
    end
    return false
end