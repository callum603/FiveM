-- author: Callum Jackson
-- description: vRP Mobile Phone Addon Client Logic

local phoneOpen = false

RegisterCommand('phone', function()
    phoneOpen = not phoneOpen
    SetNuiFocus(phoneOpen, phoneOpen)
    SendNUIMessage({
        action = "openPhone",
        status = phoneOpen
    })
    
    if phoneOpen then
        TriggerServerEvent("vrp_phone:requestData")
    end
end, false)

RegisterKeyMapping('phone', 'Open Mobile Phone', 'keyboard', 'm')

RegisterNetEvent('vrp_phone:receiveData', function(phoneNumber)
    SendNUIMessage({
        action = "updatePhoneNumber",
        phoneNumber = phoneNumber
    })
end)

RegisterNetEvent('vrp_phone:receiveText', function(sender, message)
    SendNUIMessage({
        action = "receiveText",
        sender = sender,
        message = message
    })
end)

-- Native Sound Triggers for GTA V Audio
RegisterNetEvent('vrp_phone:playRingSound', function()
    PlaySoundFrontend(-1, "Cellular_Ring", "DLC_HEISTS_GENERAL_SOUNDSET", true)
end)

RegisterNetEvent('vrp_phone:playDialSound', function()
    PlaySoundFrontend(-1, "Dial_Tone", "DLC_HEISTS_GENERAL_SOUNDSET", true)
end)

RegisterNetEvent('vrp_phone:stopSounds', function()
    StopSound(-1)
end)

RegisterNetEvent('vrp_phone:incomingCall', function(callerPhone)
    TriggerEvent('vrp_phone:playRingSound')
    SendNUIMessage({
        action = "incomingCall",
        callerPhone = callerPhone
    })
end)

RegisterNetEvent('vrp_phone:callDeclined', function()
    TriggerEvent('vrp_phone:stopSounds')
    SendNUIMessage({
        action = "callDeclined"
    })
end)

RegisterNetEvent('vrp_phone:connectCallVoice', function(channel)
    TriggerEvent('vrp_phone:stopSounds')
    if exports['pma-voice'] then
        exports['pma-voice']:setCallChannel(channel)
    end
    SendNUIMessage({ action = "callConnected" })
end)

RegisterNetEvent('vrp_phone:terminateCall', function()
    TriggerEvent('vrp_phone:stopSounds')
    if exports['pma-voice'] then
        exports['pma-voice']:setCallChannel(0)
    end
    SendNUIMessage({ action = "callEnded" })
end)

RegisterNetEvent('vrp_phone:textSentSuccess', function()
    SendNUIMessage({ action = "textSentSuccess" })
end)

RegisterNetEvent('vrp_phone:contactActionSuccess', function()
    SendNUIMessage({ action = "refreshContacts" })
end)

RegisterNetEvent('vrp_phone:clientCallHistory', function(history)
    SendNUIMessage({
        action = "loadCallHistory",
        history = history
    })
end)

-- NUI Callbacks
RegisterNUICallback('closePhone', function(data, cb)
    phoneOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('getConversations', function(data, cb)
    TriggerServerEvent('vrp_phone:getConversations', data.myPhone)
    cb('ok')
end)

RegisterNUICallback('getChatLog', function(data, cb)
    TriggerServerEvent('vrp_phone:getChatLog', data.myPhone, data.targetPhone)
    cb('ok')
end)

RegisterNUICallback('sendText', function(data, cb)
    TriggerServerEvent('vrp_phone:sendText', data.senderPhone, data.targetPhone, data.message)
    cb('ok')
end)

RegisterNUICallback('startCall', function(data, cb)
    TriggerEvent('vrp_phone:playDialSound')
    TriggerServerEvent('vrp_phone:startCall', data.callerPhone, data.targetPhone)
    cb('ok')
end)

RegisterNUICallback('acceptCall', function(data, cb)
    TriggerServerEvent('vrp_phone:acceptCall', data.callerPhone, data.targetPhone)
    cb('ok')
end)

RegisterNUICallback('rejectCall', function(data, cb)
    TriggerServerEvent('vrp_phone:rejectCall', data.callerPhone)
    cb('ok')
end)

RegisterNUICallback('endCall', function(data, cb)
    TriggerEvent('vrp_phone:stopSounds')
    TriggerServerEvent('vrp_phone:endCall', data.otherPhone)
    cb('ok')
end)

RegisterNUICallback('getContacts', function(data, cb)
    TriggerServerEvent('vrp_phone:getContacts', data.myPhone)
    cb('ok')
end)

RegisterNUICallback('getCallHistory', function(data, cb)
    TriggerServerEvent('vrp_phone:getCallHistory', data.myPhone)
    cb('ok')
end)

RegisterNetEvent('vrp_phone:clientContacts', function(contacts)
    SendNUIMessage({
        action = "loadContacts",
        contacts = contacts
    })
end)

RegisterNetEvent('vrp_phone:clientConversations', function(conversations)
    SendNUIMessage({
        action = "loadConversations",
        conversations = conversations
    })
end)

RegisterNetEvent('vrp_phone:clientChatLog', function(targetPhone, messages)
    SendNUIMessage({
        action = "loadChatLog",
        targetPhone = targetPhone,
        messages = messages
    })
end)

RegisterNUICallback('addContact', function(data, cb)
    TriggerServerEvent('vrp_phone:addContact', data.myPhone, data.name, data.number)
    cb('ok')
end)

RegisterNUICallback('editContact', function(data, cb)
    TriggerServerEvent('vrp_phone:editContact', data.myPhone, data.id, data.name, data.number)
    cb('ok')
end)

RegisterNUICallback('deleteContact', function(data, cb)
    TriggerServerEvent('vrp_phone:deleteContact', data.myPhone, data.id)
    cb('ok')
end)

-- Save settings NUI callback
RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('vrp_phone:saveSettings', data)
    cb('ok')
end)

-- Get settings NUI callback
RegisterNUICallback('getSettings', function(data, cb)
    -- Request from server, server will respond back via client event
    TriggerServerEvent('vrp_phone:getSettings', data)
    cb('ok')
end)

-- Listen for settings data coming back from the server
RegisterNetEvent('vrp_phone:clientReceiveSettings')
AddEventHandler('vrp_phone:clientReceiveSettings', function(settingsData)
    SendNUIMessage({
        action = "loadSettings",
        settings = settingsData
    })
end)

-- ===== 911 =====
local function GetStreetAndZone()
    local coords = GetEntityCoords(PlayerPedId())
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

RegisterNUICallback('send911', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('vrp_phone:send911', data.dept, data.description,
        { x = coords.x, y = coords.y, z = coords.z }, GetStreetAndZone())
    cb('ok')
end)

RegisterNetEvent('vrp_phone:911result', function(success, message)
    SendNUIMessage({ action = "emergencyResult", success = success, message = message })
end)

-- ===== Own records =====
RegisterNUICallback('getPoliceRecords', function(data, cb)
    TriggerServerEvent('vrp_phone:getMyPoliceRecords')
    cb('ok')
end)

RegisterNUICallback('getMedicalRecords', function(data, cb)
    TriggerServerEvent('vrp_phone:getMyMedicalRecords')
    cb('ok')
end)

RegisterNetEvent('vrp_phone:clientPoliceRecords', function(records)
    SendNUIMessage({ action = "loadPoliceRecords", records = records })
end)

RegisterNetEvent('vrp_phone:clientMedicalRecords', function(records)
    SendNUIMessage({ action = "loadMedicalRecords", records = records })
end)
