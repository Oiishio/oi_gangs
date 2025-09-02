-- server/utils.lua - Shared utilities for all gangs
ESX = exports['es_extended']:getSharedObject()

-- Get player's job information
---@param src number
---@return table
function getJob(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.job or nil
end

-- Check if player has specific job
---@param src number
---@param jobName string
---@return boolean
function isJob(src, jobName)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.job.name == jobName or false
end

-- Check if job is a gang job
---@param jobName string
---@return boolean
function isGangJob(jobName)
    return Config.Gangs[jobName] ~= nil
end

-- Get gang configuration by job name
---@param jobName string
---@return table|nil
function getGangConfig(jobName)
    return Config.Gangs[jobName]
end

-- Check if player is in any gang
---@param src number
---@return boolean, string|nil
function isPlayerInGang(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false, nil end
    
    local jobName = xPlayer.job.name
    if Config.Gangs[jobName] then
        return true, jobName
    end
    return false, nil
end

-- Check if player is boss rank in their gang
---@param src number
---@return boolean
function isPlayerGangBoss(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    
    local gangConfig = Config.Gangs[xPlayer.job.name]
    if not gangConfig then return false end
    
    return xPlayer.job.grade >= gangConfig.bossRank
end

-- Check if identifier exists in table
---@param table table
---@param identifier string
---@return boolean
function checkTable(table, identifier)
    for k, v in pairs(table) do
        if v == identifier then
            return true
        end
    end
    return false
end

-- Add player to table
---@param table table
---@param identifier string
function addPlayerToTable(table, identifier)
    table[#table + 1] = identifier
end

-- Remove player from table
---@param table table
---@param identifier string
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

-- Get vehicle price from hash and gang config
---@param vehicleHash number
---@param jobGrade string
---@param gangName string
---@return number
function getPriceFromHash(vehicleHash, jobGrade, gangName)
    local gangConfig = Config.Gangs[gangName]
    if not gangConfig or not gangConfig.vehicles[jobGrade] then
        return 0
    end
    
    local vehicles = gangConfig.vehicles[jobGrade]
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if GetHashKey(vehicle.model) == vehicleHash then
            return vehicle.price or 0
        end
    end
    
    return 0
end

-- Send event to client
---@param eventName string
---@param src number
---@param data any
function sendClient(eventName, src, data)
    TriggerClientEvent(eventName, src, data)
end

-- Send message to Discord webhook (placeholder)
---@param channel string
---@param msg string
function sendToDiscord(channel, msg)
    -- Implement your Discord webhook logic here
    print('[GANG SYSTEM] Discord: ' .. channel .. ' - ' .. msg)
end

-- Play sound on vector3
---@param source number
---@param maxDistance number
---@param soundFile string
---@param soundVolume number
function playSound(source, maxDistance, soundFile, soundVolume)
    local ped = GetPlayerPed(source)
    local pos = GetEntityCoords(ped)
    local players = ESX.Players
    
    if maxDistance <= 10 then
        for k, v in pairs(players) do
            local tPed = GetPlayerPed(k)
            local tPos = GetEntityCoords(tPed)
            local dist = #(tPos - pos)
            
            if dist < maxDistance then
                local volume = (1 - (dist / maxDistance)) * soundVolume
                TriggerClientEvent('InteractSound_CL:PlayWithinDistance', k, dist, maxDistance, soundFile, volume)
            end
        end
    end
end

-- Get localized string
---@param key string
---@return string
function _U(key)
    return Config.Locales[key] or key
end

-- Handcuffing state management
local awaitingMinigames = {}
local cuffedPlayers = {}

-- Start handcuffing process with skill check
---@param source number
---@param target number
---@param gangName string
function startHandcuffProcess(source, target, gangName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)
    
    if not xPlayer or not xTarget then return false end
    
    if cuffedPlayers[target] then
        return false, 'Player already cuffed'
    end
    
    if awaitingMinigames[target] then
        return false, 'Player already being processed'
    end
    
    -- Set up the handcuffing process
    awaitingMinigames[target] = {
        attacker = source,
        status = 0, -- 0 = waiting, 1 = success, 2 = failed
        timeout = 5000
    }
    
    -- Freeze target and start skill check
    TriggerClientEvent('gang:startHandcuffSequence', target, source)
    TriggerClientEvent('gang:startHandcuffProgress', source, target)
    
    return true
end

-- Handle skill check response
RegisterNetEvent('gang:skillCheckResponse')
AddEventHandler('gang:skillCheckResponse', function(success)
    local playerId = source
    if awaitingMinigames[playerId] then
        awaitingMinigames[playerId].status = success and 2 or 1 -- 2 = resisted, 1 = cuffed
    end
end)

-- Complete handcuffing process
RegisterNetEvent('gang:completeHandcuff')
AddEventHandler('gang:completeHandcuff', function(target)
    local source = source
    if awaitingMinigames[target] and awaitingMinigames[target].attacker == source then
        local result = awaitingMinigames[target].status
        
        if result == 1 then -- Successfully cuffed
            cuffedPlayers[target] = true
            TriggerClientEvent('gang:setCuffed', target, true)
            TriggerClientEvent('gang:notifyResult', source, 'success', 'Player cuffed successfully')
            
            -- Remove ziptie from attacker
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                exports.ox_inventory:RemoveItem(source, 'ziptie', 1)
            end
        elseif result == 2 then -- Player resisted
            TriggerClientEvent('gang:notifyResult', source, 'error', 'Player resisted!')
            TriggerClientEvent('gang:notifyResult', target, 'success', 'You broke free!')
        else -- Timeout or failed
            TriggerClientEvent('gang:notifyResult', source, 'error', 'Handcuffing failed')
        end
        
        -- Clean up
        TriggerClientEvent('gang:endHandcuffSequence', target)
        awaitingMinigames[target] = nil
    end
end)