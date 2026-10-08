local function GetStreetAndZone()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    
    if crossingHash ~= 0 then
        local crossingName = GetStreetNameFromHashKey(crossingHash)
        if streetName and streetName ~= "" then
            return streetName .. " / " .. crossingName
        end
    end
    return (streetName and streetName ~= "") and streetName or "Unknown Location"
end

-- Panic Button Hotkey (F5)
RegisterKeyMapping('panicbutton', 'Trigger Panic Button (10-99)', 'keyboard', 'F5')
RegisterCommand('panicbutton', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local street = GetStreetAndZone()
    TriggerServerEvent('vrp_cad:server:triggerPanicButton', coords, street)
end, false)

RegisterNetEvent('vrp_cad:client:openMDT')
AddEventHandler('vrp_cad:client:openMDT', function(permissions, activeCalls, officerRoster)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMDT",
        permissions = permissions,
        calls = activeCalls,
        officers = officerRoster
    })
end)

RegisterNetEvent('vrp_cad:client:updateOfficerRoster')
AddEventHandler('vrp_cad:client:updateOfficerRoster', function(officerRoster)
    SendNUIMessage({
        action = "updateRoster",
        officers = officerRoster
    })
end)

RegisterNetEvent('vrp_cad:client:updateCalls')
AddEventHandler('vrp_cad:client:updateCalls', function(activeCalls)
    SendNUIMessage({
        action = "updateCalls",
        calls = activeCalls
    })
end)

RegisterNetEvent('vrp_cad:client:playAudioAlert')
AddEventHandler('vrp_cad:client:playAudioAlert', function(audioFileName)
    SendNUIMessage({
        action = "playAudio",
        file = audioFileName
    })
end)

RegisterNetEvent('vrp_cad:client:receiveCivilianSearch')
AddEventHandler('vrp_cad:client:receiveCivilianSearch', function(results)
    SendNUIMessage({
        action = "civilianSearchResult",
        results = results
    })
end)

RegisterNetEvent('vrp_cad:client:receivePlateData')
AddEventHandler('vrp_cad:client:receivePlateData', function(result)
    SendNUIMessage({
        action = "plateResult",
        result = result
    })
end)

RegisterNUICallback('closeMDT', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('updateStatus', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local street = GetStreetAndZone()
    TriggerServerEvent('vrp_cad:server:updateStatus', data.department, data.code, data.description, coords, street)
    cb('ok')
end)

RegisterNUICallback('assignToCall', function(data, cb)
    TriggerServerEvent('vrp_cad:server:assignToCall', data.id)
    cb('ok')
end)

RegisterNUICallback('closeCall', function(data, cb)
    TriggerServerEvent('vrp_cad:server:closeCall', data.id)
    cb('ok')
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    if data.x and data.y then
        SetNewWaypoint(data.x, data.y)
        TriggerEvent('chat:addMessage', { args = {"GPS", "Waypoint set to dispatch location."} })
    end
    cb('ok')
end)

RegisterNUICallback('searchCivilian', function(data, cb)
    TriggerServerEvent('vrp_cad:server:searchCivilian', data.query)
    cb('ok')
end)

RegisterNUICallback('lookupPlate', function(data, cb)
    TriggerServerEvent('vrp_cad:server:lookupPlate', data.plate)
    cb('ok')
end)

RegisterNuiCallback('addCriminalRecord', function(data, cb)
    TriggerServerEvent('vrp_cad:server:addCriminalRecord', data)
    cb('ok')
end)

RegisterNUICallback('deleteCriminalRecord', function(data, cb)
    TriggerServerEvent('vrp_cad:server:deleteCriminalRecord', data.id)
    cb('ok')
end)

RegisterNuiCallback('updateCriminalRecord', function(data, cb)
    TriggerServerEvent('vrp_cad:server:updateCriminalRecord', data)
    cb('ok')
end)

RegisterNuiCallback('addMedicalRecord', function(data, cb)
    TriggerServerEvent('vrp_cad:server:addMedicalRecord', data)
    cb('ok')
end)

RegisterNUICallback('deleteMedicalRecord', function(data, cb)
    TriggerServerEvent('vrp_cad:server:deleteMedicalRecord', data.id)
    cb('ok')
end)