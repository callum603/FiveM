-- author: Callum Jackson
-- description: vRP Mobile Phone Addon Server Logic (ghmattimysql)

local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

-- Initialize database tables on start
CreateThread(function()
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS `vrp_phone_contacts` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `phone` VARCHAR(50),
            `name` VARCHAR(100),
            `number` VARCHAR(50)
        )
    ]])
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS `vrp_phone_messages` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `sender` VARCHAR(50),
            `target` VARCHAR(50),
            `message` TEXT,
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS `vrp_phone_calls` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `my_phone` VARCHAR(50),
            `other_number` VARCHAR(50),
            `type` VARCHAR(20),
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS `phone_settings` (
            `phone` VARCHAR(50) PRIMARY KEY,
            `settings` TEXT
        )
    ]])
end)

function getPhoneNumber(user_id, cb)
    exports.ghmattimysql:execute("SELECT phone FROM vrp_user_identities WHERE user_id = @user_id", {['@user_id'] = user_id}, function(rows)
        if rows and rows[1] and rows[1].phone then
            cb(rows[1].phone)
        else
            cb(nil)
        end
    end)
end

function getUserByPhoneNumber(phoneNumber, cb)
    exports.ghmattimysql:execute("SELECT user_id FROM vrp_user_identities WHERE phone = @phone", {['@phone'] = phoneNumber}, function(rows)
        if rows and rows[1] and rows[1].user_id then
            cb(rows[1].user_id)
        else
            cb(nil)
        end
    end)
end

RegisterServerEvent('vrp_phone:requestData', function()
    local source = source
    local user_id = vRP.getUserId({source})
    if user_id then
        getPhoneNumber(user_id, function(phone)
            if phone then
                TriggerClientEvent('vrp_phone:receiveData', source, phone)
            else
                TriggerClientEvent('vrp_phone:receiveData', source, "555-0100")
            end
        end)
    end
end)

-- Contacts
RegisterServerEvent('vrp_phone:getContacts', function(myPhone)
    local source = source
    exports.ghmattimysql:execute("SELECT * FROM vrp_phone_contacts WHERE phone = @phone", {['@phone'] = myPhone}, function(contacts)
        TriggerClientEvent('vrp_phone:clientContacts', source, contacts or {})
    end)
end)

RegisterServerEvent('vrp_phone:addContact', function(myPhone, name, number)
    local source = source
    exports.ghmattimysql:execute("INSERT INTO vrp_phone_contacts (phone, name, number) VALUES (@phone, @name, @number)", {
        ['@phone'] = myPhone, ['@name'] = name, ['@number'] = number
    }, function()
        TriggerClientEvent('vrp_phone:contactActionSuccess', source)
    end)
end)

RegisterServerEvent('vrp_phone:editContact', function(myPhone, id, name, number)
    local source = source
    exports.ghmattimysql:execute("UPDATE vrp_phone_contacts SET name = @name, number = @number WHERE id = @id AND phone = @phone", {
        ['@name'] = name, ['@number'] = number, ['@id'] = id, ['@phone'] = myPhone
    }, function()
        TriggerClientEvent('vrp_phone:contactActionSuccess', source)
    end)
end)

RegisterServerEvent('vrp_phone:deleteContact', function(myPhone, id)
    local source = source
    exports.ghmattimysql:execute("DELETE FROM vrp_phone_contacts WHERE id = @id AND phone = @phone", {
        ['@id'] = id, ['@phone'] = myPhone
    }, function()
        TriggerClientEvent('vrp_phone:contactActionSuccess', source)
    end)
end)

-- Messages
RegisterServerEvent('vrp_phone:getConversations', function(myPhone)
    local source = source
    exports.ghmattimysql:execute("SELECT * FROM vrp_phone_messages WHERE sender = @phone OR target = @phone ORDER BY id DESC", {['@phone'] = myPhone}, function(rows)
        TriggerClientEvent('vrp_phone:clientConversations', source, rows or {})
    end)
end)

RegisterServerEvent('vrp_phone:getChatLog', function(myPhone, targetPhone)
    local source = source
    exports.ghmattimysql:execute("SELECT * FROM vrp_phone_messages WHERE (sender = @p1 AND target = @p2) OR (sender = @p2 AND target = @p1) ORDER BY id ASC", {
        ['@p1'] = myPhone, ['@p2'] = targetPhone
    }, function(messages)
        TriggerClientEvent('vrp_phone:clientChatLog', source, targetPhone, messages or {})
    end)
end)

RegisterServerEvent('vrp_phone:sendText', function(senderPhone, targetPhone, message)
    local source = source
    exports.ghmattimysql:execute("INSERT INTO vrp_phone_messages (sender, target, message) VALUES (@sender, @target, @msg)", {
        ['@sender'] = senderPhone, ['@target'] = targetPhone, ['@msg'] = message
    }, function()
        TriggerClientEvent('vrp_phone:textSentSuccess', source)
        getUserByPhoneNumber(targetPhone, function(targetUserId)
            if targetUserId then
                local targetSource = vRP.getUserSource({targetUserId})
                if targetSource then
                    TriggerClientEvent('vrp_phone:receiveText', targetSource, senderPhone, message)
                end
            end
        end)
    end)
end)

-- Calls & Persistent Call History
RegisterServerEvent('vrp_phone:getCallHistory', function(myPhone)
    local source = source
    exports.ghmattimysql:execute("SELECT * FROM vrp_phone_calls WHERE my_phone = @phone ORDER BY id DESC LIMIT 50", {['@phone'] = myPhone}, function(rows)
        TriggerClientEvent('vrp_phone:clientCallHistory', source, rows or {})
    end)
end)

RegisterServerEvent('vrp_phone:startCall', function(callerPhone, targetPhone)
    local source = source
    exports.ghmattimysql:execute("INSERT INTO vrp_phone_calls (my_phone, other_number, type) VALUES (@phone, @other, 'Outgoing')", {['@phone'] = callerPhone, ['@other'] = targetPhone})
    
    getUserByPhoneNumber(targetPhone, function(targetUserId)
        if targetUserId then
            local targetSource = vRP.getUserSource({targetUserId})
            if targetSource then
                TriggerClientEvent('vrp_phone:incomingCall', targetSource, callerPhone)
            else
                TriggerClientEvent('vrp_phone:callDeclined', source)
            end
        else
            TriggerClientEvent('vrp_phone:callDeclined', source)
        end
    end)
end)

RegisterServerEvent('vrp_phone:acceptCall', function(callerPhone, targetPhone)
    local source = source
    getUserByPhoneNumber(callerPhone, function(callerUserId)
        if callerUserId then
            local callerSource = vRP.getUserSource({callerUserId})
            if callerSource then
                local channel = math.random(100, 9999)
                TriggerClientEvent('vrp_phone:connectCallVoice', callerSource, channel)
                TriggerClientEvent('vrp_phone:connectCallVoice', source, channel)
            end
        end
    end)
end)

RegisterServerEvent('vrp_phone:rejectCall', function(callerPhone)
    getUserByPhoneNumber(callerPhone, function(callerUserId)
        if callerUserId then
            local callerSource = vRP.getUserSource({callerUserId})
            if callerSource then
                TriggerClientEvent('vrp_phone:callDeclined', callerSource)
            end
        end
    end)
end)

RegisterServerEvent('vrp_phone:endCall', function(otherPhone)
    local source = source
    getUserByPhoneNumber(otherPhone, function(otherUserId)
        if otherUserId then
            local otherSource = vRP.getUserSource({otherUserId})
            if otherSource then
                TriggerClientEvent('vrp_phone:terminateCall', otherSource)
            end
        end
    end)
    TriggerClientEvent('vrp_phone:terminateCall', source)
end)

-- Handle saving settings to database via ghmattimysql
RegisterServerEvent('vrp_phone:saveSettings')
AddEventHandler('vrp_phone:saveSettings', function(data)
    local source = source
    if data and data.myPhone and data.settings then
        local settingsJson = json.encode(data.settings)
        
        exports['ghmattimysql']:execute(
            "REPLACE INTO phone_settings (phone, settings) VALUES (@phone, @settings)",
            {
                ['@phone'] = data.myPhone,
                ['@settings'] = settingsJson
            },
            function(rowsChanged)
            end
        )
    end
end)

-- Handle fetching settings from database via ghmattimysql
RegisterServerEvent('vrp_phone:getSettings')
AddEventHandler('vrp_phone:getSettings', function(data)
    local source = source
    if not data or not data.myPhone then return end

    exports['ghmattimysql']:execute(
        "SELECT settings FROM phone_settings WHERE phone = @phone",
        {
            ['@phone'] = data.myPhone
        },
        function(result)
            local settings = { theme = 'dark', accent = '#0a84ff', ringtone = 'gta', alertTone = 'classic' }
            
            if result and result[1] and result[1].settings then
                local decoded = json.decode(result[1].settings)
                if decoded then
                    settings = decoded
                end
            end
            
            TriggerClientEvent('vrp_phone:clientReceiveSettings', source, settings)
        end
    )
end)

-- ===== 911 =====
local lastEmergencyCall = {}

AddEventHandler('playerDropped', function()
    lastEmergencyCall[source] = nil
end)

RegisterServerEvent('vrp_phone:send911', function(dept, description, coords, street)
    local src = source
    local user_id = vRP.getUserId({src})
    if not user_id then return end

    if dept ~= "police" and dept ~= "ems" then return end

    if lastEmergencyCall[src] and (os.time() - lastEmergencyCall[src]) < 30 then
        TriggerClientEvent('vrp_phone:911result', src, false, "Please wait before placing another 911 call.")
        return
    end

    if type(coords) ~= "table" then coords = { x = 0.0, y = 0.0, z = 0.0 } end

    local ok, result = pcall(function()
        return exports['vrp_cad']:create911Call(src, dept, description,
            tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0,
            tostring(street or "Unknown Location"))
    end)

    if ok and result then
        lastEmergencyCall[src] = os.time()
        TriggerClientEvent('vrp_phone:911result', src, true, "911 call sent. Help is on the way.")
    else
        TriggerClientEvent('vrp_phone:911result', src, false, "Emergency services are unavailable right now.")
    end
end)

-- ===== Own records =====
local function getFullName(user_id, cb)
    exports.ghmattimysql:execute("SELECT * FROM vrp_user_identities WHERE user_id = @uid", {['@uid'] = user_id}, function(rows)
        local r = rows and rows[1]
        if r then
            cb(r.firstname .. " " .. (r.name or r.registration or ""))
        else
            cb(nil)
        end
    end)
end

RegisterServerEvent('vrp_phone:getMyPoliceRecords', function()
    local src = source
    local user_id = vRP.getUserId({src})
    if not user_id then return end

    getFullName(user_id, function(fullName)
        local uidStr = tostring(user_id)
        exports.ghmattimysql:execute("SELECT id, report_type, author, title, details, fine_amount, date FROM vrp_cad_criminal_records WHERE target_name = @n OR target_name = @u ORDER BY id DESC", {
            ['@n'] = fullName or uidStr, ['@u'] = uidStr
        }, function(rows)
            TriggerClientEvent('vrp_phone:clientPoliceRecords', src, rows or {})
        end)
    end)
end)

RegisterServerEvent('vrp_phone:getMyMedicalRecords', function()
    local src = source
    local user_id = vRP.getUserId({src})
    if not user_id then return end

    getFullName(user_id, function(fullName)
        local uidStr = tostring(user_id)
        exports.ghmattimysql:execute("SELECT id, author, diagnosis, treatment, service_fee, date FROM vrp_cad_medical_records WHERE target_name = @n OR target_name = @u ORDER BY id DESC", {
            ['@n'] = fullName or uidStr, ['@u'] = uidStr
        }, function(rows)
            TriggerClientEvent('vrp_phone:clientMedicalRecords', src, rows or {})
        end)
    end)
end)
