-- server/main.lua - Complete gang server system

ESX = exports['es_extended']:getSharedObject()

-- State management
local handCuffed = {}
local unCuffing = {}
local drag = {}
local unDrag = {}

-- Server callback to check for ziptie
ESX.RegisterServerCallback('gang:checkZiptie', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then 
        cb(false)
        return 
    end
    
    local hasZiptie = exports.ox_inventory:GetItem(source, 'ziptie', nil, true)
    cb(hasZiptie and hasZiptie >= 1)
end)

-- Main cuffing system (FIXED STATE MANAGEMENT)
lib.callback.register('gauja-sv:CuffPlayer', function(source, target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    print("DEBUG SERVER: CuffPlayer called, source =", source, "target =", target)
    
    if not xPlayer or not xTarget then 
        return false 
    end
    
    if not isPlayerInGang(source) then
        xPlayer.kick('Unauthorized action!')
        return false
    end
    
    local check = checkTable(handCuffed, xTarget.identifier)
    print("DEBUG SERVER: Target cuffed =", check)
    
    if not check then
        -- CUFFING PROCESS
        local hasZiptie = exports.ox_inventory:GetItem(source, 'ziptie', nil, true)
        if not hasZiptie or hasZiptie < 1 then
            TriggerClientEvent('esx:showNotification', source, Config.Locales['no_ziptie'])
            return false
        end
        
        exports.ox_inventory:RemoveItem(source, 'ziptie', 1)
        handCuffed[#handCuffed+1] = xTarget.identifier
        
        print('DEBUG SERVER: CUFFED player:', target)
        
        TriggerClientEvent('gang:updateCuffedState', -1, target, true)
        TriggerClientEvent('gauja-cl:syncCuff', target)
        TriggerClientEvent('esx:showNotification', source, Config.Locales['player_cuffed'])
        
        return true
    else
        -- UNCUFFING PROCESS
        print("DEBUG SERVER: UNCUFFING player", target)
        
        -- ACTUALLY REMOVE from handcuffed table
        removePlayerFromTable(handCuffed, xTarget.identifier)
        
        print('DEBUG SERVER: UNCUFFED player:', target, 'Remaining in table:', #handCuffed)
        
        TriggerClientEvent('gang:updateCuffedState', -1, target, false)
        TriggerClientEvent('gauja-cl:syncUnCuff', target)
        TriggerClientEvent('esx:showNotification', source, Config.Locales['player_uncuffed'])
        
        return true
    end
end)

-- Check handcuff state
lib.callback.register('gauja:checkHandcuff', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local check = checkTable(handCuffed, xPlayer.identifier)
    local uncuffCheck = checkTable(unCuffing, xPlayer.identifier)

    if check and not uncuffCheck then
        return true
    elseif check and uncuffCheck then
        removePlayerFromTable(unCuffing, xPlayer.identifier)
        removePlayerFromTable(handCuffed, xPlayer.identifier)
        TriggerClientEvent('gang:updateCuffedState', -1, source, false)
        return true
    else
        return false
    end
end)

-- Dragging system (FIXED ATTACHMENT ISSUE)
lib.callback.register('gauja:dragPlayer', function(source, target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    print("DEBUG SERVER: dragPlayer called, source =", source, "target =", target)
    
    if not xPlayer or not xTarget then 
        return false 
    end
    
    if not isPlayerInGang(source) then
        xPlayer.kick('Unauthorized action!')
        return false
    end
    
    local check = checkTable(drag, xTarget.identifier)
    
    if not check then
        drag[#drag+1] = xTarget.identifier
        print('DEBUG SERVER: Started drag:', target)
        TriggerClientEvent('gauja-cl:syncDrag', target, source)
        return true
    else
        -- If already dragging, stop it
        removePlayerFromTable(drag, xTarget.identifier)
        print('DEBUG SERVER: Stopped drag (toggle):', target)
        TriggerClientEvent('gauja-cl:syncUnDrag', target)
        return true
    end
end)

lib.callback.register('gauja:unDrag', function(source, target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    print("DEBUG SERVER: unDrag called, source =", source, "target =", target)
    
    if not xPlayer or not xTarget then 
        print("DEBUG SERVER: Invalid players in unDrag")
        return false 
    end
    
    if not isPlayerInGang(source) then
        print("DEBUG SERVER: Not authorized for unDrag")
        return false
    end
    
    local check = checkTable(drag, xTarget.identifier)
    print("DEBUG SERVER: Target in drag table =", check)
    
    if check then
        removePlayerFromTable(drag, xTarget.identifier)
        print('DEBUG SERVER: Successfully stopped drag:', target)
        
        -- FORCE detachment on target
        TriggerClientEvent('gauja-cl:syncUnDrag', target)
        
        return true
    else
        print("DEBUG SERVER: Target not in drag table")
        return false
    end
end)

lib.callback.register('gauja:checkDrag', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local check = checkTable(drag, xPlayer.identifier)
    local dragCheck = checkTable(unDrag, xPlayer.identifier)
    
    if check and not dragCheck then
        return true
    elseif check and dragCheck then
        removePlayerFromTable(drag, xPlayer.identifier)
        removePlayerFromTable(unDrag, xPlayer.identifier)
        return true
    else
        return false
    end
end)

-- Vehicle system
ESX.RegisterServerCallback('gang:buyJobVehicle', function(source, cb, vehicleProps, gangName)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not isPlayerInGang(source) or xPlayer.job.name ~= gangName then
        cb(false)
        return
    end

    local price = getPriceFromHash(vehicleProps.model, xPlayer.job.grade_name, gangName)
    
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price, "Gang Vehicle Purchase")

        MySQL.insert('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)', 
            { xPlayer.identifier, json.encode(vehicleProps), vehicleProps.plate, 'car', xPlayer.job.name, true },
            function (rowsChanged)
                cb(rowsChanged > 0)
            end)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback('gang:storeNearbyVehicle', function(source, cb, plates)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not isPlayerInGang(source) then
        cb(false)
        return
    end

    local plate = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job = ?', 
        {xPlayer.identifier, plates, xPlayer.job.name})

    if plate then
        MySQL.update('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job = ?', 
            {xPlayer.identifier, plate, xPlayer.job.name},
            function(rowsChanged)
                cb(rowsChanged > 0 and plate or false)
            end)
    else
        cb(false)
    end
end)

ESX.RegisterServerCallback('gang:getOwnedVehicles', function(source, cb, gangName)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not isPlayerInGang(source) or xPlayer.job.name ~= gangName then
        cb({})
        return
    end

    MySQL.query('SELECT vehicle, plate, stored FROM owned_vehicles WHERE owner = ? AND job = ?', 
        {xPlayer.identifier, xPlayer.job.name},
        function(result)
            local vehicles = {}
            for i = 1, #result do
                local vehicle = result[i]
                vehicles[#vehicles+1] = {
                    vehicle = json.decode(vehicle.vehicle),
                    plate = vehicle.plate,
                    stored = vehicle.stored == 1
                }
            end
            cb(vehicles)
        end)
end)

ESX.RegisterServerCallback('gang:setVehicleState', function(source, cb, plate, stored)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not isPlayerInGang(source) then
        cb(false)
        return
    end

    MySQL.update('UPDATE owned_vehicles SET `stored` = ? WHERE owner = ? AND plate = ? AND job = ?', 
        {stored, xPlayer.identifier, plate, xPlayer.job.name},
        function(rowsChanged)
            cb(rowsChanged > 0)
        end)
end)

-- Storage system
local ox_inventory = exports.ox_inventory

for gangName, gangConfig in pairs(Config.Gangs) do
    RegisterNetEvent('gang:openStorage:' .. gangName)
    AddEventHandler('gang:openStorage:' .. gangName, function()
        ox_inventory:RegisterStash(gangName, gangConfig.name .. ' Storage', 900, 20000000, false)
    end)
    
    RegisterNetEvent('gang:openBossStorage:' .. gangName)
    AddEventHandler('gang:openBossStorage:' .. gangName, function()
        ox_inventory:RegisterStash(gangName .. 'boss', gangConfig.name .. ' Boss Storage', 900, 20000000, false)
    end)
end

-- Additional gang actions
RegisterNetEvent('gang:putInVehicle')
AddEventHandler('gang:putInVehicle', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    if not xPlayer or not xTarget then return end
    
    if not isPlayerInGang(source) then
        xPlayer.kick('Unauthorized action!')
        return
    end
    
    local isCuffedCheck = checkTable(handCuffed, xTarget.identifier)
    if not isCuffedCheck then
        TriggerClientEvent('esx:showNotification', source, 'Player is not cuffed')
        return
    end
    
    TriggerClientEvent('gang:putInNearestVehicle', target)
end)

RegisterNetEvent('gang:outVehicle')
AddEventHandler('gang:outVehicle', function(target)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    if not xPlayer or not xTarget then return end
    
    if not isPlayerInGang(source) then
        xPlayer.kick('Unauthorized action!')
        return
    end
    
    TriggerClientEvent('gang:removeFromVehicle', target)
end)

-- Blip management
RegisterNetEvent('gang:forceBlip')
AddEventHandler('gang:forceBlip', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local gangName = xPlayer.job.name
    local gangConfig = Config.Gangs[gangName]
    
    if gangConfig then
        TriggerClientEvent('gang:createBlip', source, gangConfig)
    end
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer then
        removePlayerFromTable(handCuffed, xPlayer.identifier)
        removePlayerFromTable(unCuffing, xPlayer.identifier)
        removePlayerFromTable(drag, xPlayer.identifier)
        removePlayerFromTable(unDrag, xPlayer.identifier)
        
        TriggerClientEvent('gang:updateCuffedState', -1, source, false)
    end
end)

-- Utility functions (fixed versions)
function checkTable(table, identifier)
    for k, v in pairs(table) do
        if v == identifier then
            return true
        end
    end
    return false
end

function removePlayerFromTable(table, identifier)
    for i = #table, 1, -1 do -- Go backwards to avoid index issues
        if table[i] == identifier then
            table[i] = table[#table] -- Move last element to this position
            table[#table] = nil -- Remove last element
            print("DEBUG SERVER: Removed", identifier, "from table, new size:", #table)
            break
        end
    end
end

function addPlayerToTable(table, identifier)
    table[#table + 1] = identifier
end

-- Utility function to check if player is in any gang
function isPlayerInGang(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    return Config.Gangs[xPlayer.job.name] ~= nil
end