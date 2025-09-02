-- client/functions.lua - COMPLETELY CLEAN VERSION

local helpText = nil
local ped = cache.ped
local cuffedPlayers = {}
local vehicle = cache.vehicle
local result = false

lib.onCache('ped', function(value) ped = value end)
lib.onCache('vehicle', function(value) vehicle = value end)

_cuffed = false
local animation = {dict = "mp_arresting", name = "idle"}

-- Animation events for handcuffing ONLY
RegisterNetEvent('gauja:playAnimation', function(animationType, requestId)
    local playingAnim = true

    if animationType == 1 then
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arrest_paired')
        TaskPlayAnim(ped, 'mp_arrest_paired', 'cop_p2_back_right', 8.0, 8.0, 3750, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arrest_paired')
        SetTimeout(3750, function()
            playingAnim = false
        end)
    elseif animationType == 2 then
        local requestPlayer = GetPlayerFromServerId(requestId)
        if requestPlayer ~= -1 then
            local requestPed = GetPlayerPed(requestPlayer)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(requestPed, 0.0, 1.0, -1.0))
            SetEntityHeading(ped, GetEntityHeading(requestPed))
        end
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arrest_paired')
        TaskPlayAnim(ped, 'mp_arrest_paired', 'crook_p2_back_right', 8.0, 8.0, 3750, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arrest_paired')
        SetTimeout(3950, function()
            playingAnim = false
        end)
    elseif animationType == 3 then
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arresting')
        TaskPlayAnim(ped, 'mp_arresting', 'a_uncuff', 8.0, 8.0, 5500, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arresting')
        SetTimeout(5500, function()
            playingAnim = false
        end)
    elseif animationType == 4 then
        local requestPlayer = GetPlayerFromServerId(requestId)
        if requestPlayer ~= -1 then
            local requestPed = GetPlayerPed(requestPlayer)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(requestPed, 0.0, 1.0, -1.0))
            SetEntityHeading(ped, GetEntityHeading(requestPed))
        end
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arresting')
        TaskPlayAnim(ped, 'mp_arresting', 'b_uncuff', 8.0, 8.0, 5500, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arresting')
        SetTimeout(5500, function()
            playingAnim = false
        end)
    elseif animationType == 5 then
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arresting')
        TaskPlayAnim(ped, 'mp_arresting', 'a_uncuff', 8.0, 8.0, 3500, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arresting')
        SetTimeout(3500, function()
            playingAnim = false
        end)
    elseif animationType == 6 then
        local requestPlayer = GetPlayerFromServerId(requestId)
        if requestPlayer ~= -1 then
            local requestPed = GetPlayerPed(requestPlayer)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(requestPed, 0.0, 1.0, -1.0))
            SetEntityHeading(ped, GetEntityHeading(requestPed))
        end
        Wait(250)
        ESX.Streaming.RequestAnimDict('mp_arresting')
        TaskPlayAnim(ped, 'mp_arresting', 'b_uncuff', 8.0, 8.0, 3500, 2, 0, 0, 0, 0)
        RemoveAnimDict('mp_arresting')
        SetTimeout(3700, function()
            playingAnim = false
        end)
    end
end)

-- Minigame event
RegisterNetEvent('gauja:playMinigame', function()
    local success = lib.skillCheck({'medium', 'hard'})
    lib.notify({
        title = 'Gang System',
        description = success and 'Resistance successful!' or 'Resistance failed!',
        type = success and 'success' or 'error',
        duration = 3000
    })
    TriggerServerEvent('gk-utils:minigameResponse', success)
end)

-- Handcuff events
RegisterNetEvent('gauja:handcuff', function(handcuffsOn)
    _cuffed = handcuffsOn

    if _cuffed then
        SetEnableHandcuffs(ped, true)
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        SetPedCanPlayGestureAnims(ped, false)

        CreateThread(function()
            while _cuffed do
                Wait(1000)
                if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                    if not ESX.PlayerData.dead and not playingAnim then
                        ESX.Streaming.RequestAnimDict('mp_arresting')
                        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, 8.0, -1, 49, 0.0, false, false, false)
                        RemoveAnimDict('mp_arresting')
                    elseif ESX.PlayerData.dead then
                        _cuffed = false
                    end
                end
            end

            ClearPedSecondaryTask(ped)
            SetEnableHandcuffs(ped, false)
            SetPedCanPlayGestureAnims(ped, true)
        end)

        CreateThread(function()
            while _cuffed do
                Wait(0)
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
                DisableControlAction(0, 170, true) -- Animations
                DisableControlAction(0, 167, true) -- Job
                DisableControlAction(0, 0, true) -- Changing view
                DisableControlAction(0, 26, true) -- Looking behind
                DisableControlAction(0, 73, true) -- X key (prevents escape)
                DisableControlAction(2, 199, true) -- Pause screen
                DisableControlAction(0, 59, true) -- Steering
                DisableControlAction(0, 71, true) -- Drive forward
                DisableControlAction(0, 72, true) -- Reverse
                DisableControlAction(2, 36, true) -- Stealth
                DisableControlAction(0, 47, true) -- Weapon
                DisableControlAction(0, 264, true) -- Disable melee
                DisableControlAction(0, 257, true) -- Disable melee
                DisableControlAction(0, 140, true) -- Disable melee
                DisableControlAction(0, 141, true) -- Disable melee
                DisableControlAction(0, 142, true) -- Disable melee
                DisableControlAction(0, 143, true) -- Disable melee
                DisableControlAction(0, 75, true) -- Exit vehicle
                DisableControlAction(27, 75, true) -- Exit vehicle
                DisablePlayerFiring(ped, true)
            end
        end)
    else
        ClearPedSecondaryTask(ped)
        SetEnableHandcuffs(ped, false)
        SetPedCanPlayGestureAnims(ped, true)
    end
end)

-- Utility functions
function checkPlayer(checkEntity, checkType, checkData)
    if checkType == 1 then
        local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(checkEntity))
        if cuffedPlayers[serverId] and checkData.type then
            if cuffedPlayers[serverId] == checkData.type then
                return true
            end
        end
        return false
    elseif checkType == 2 then
        return IsEntityPlayingAnim(checkEntity, 'random@mugging3', 'handsup_standing_base', 3)
    elseif checkType == 3 then
        return IsPedFatallyInjured(checkEntity)
    end
end

RegisterNetEvent('gauja:update', function(serverTable)
    cuffedPlayers = serverTable
end)

RegisterNetEvent('gauja:progress', function(data)
    lib.progressCircle(data)
end)