local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP", "vrp_cad")

print("[vrp_cad] Server script successfully initialized with vRP.")

local activeOfficers = {}

local vehicleFriendlyNames = {
    ["police"] = "Police Cruiser",
    ["police2"] = "Police Cruiser 2",
    ["charger"] = "Unmarked Charger",
    ["fbi"] = "Unmarked Charger",
    ["apoliceu15"] = "Unmarked Police Charger",
    ["oracle"] = "BMW M6 Gran Coupe",
}

local function getFriendlyVehicleName(spawnCode)
    if not spawnCode then return "Unknown Vehicle" end
    local cleanCode = string.lower(tostring(spawnCode)):gsub("^%s*(.-)%s*$", "%1")
    return vehicleFriendlyNames[cleanCode] or spawnCode
end

-- ===== Department helpers =====
local function getDepts(uid)
    local isCop = vRP.hasPermission({uid, "police.menu"}) or vRP.hasPermission({uid, "police.loadout"}) or vRP.hasGroup({uid, "cop"}) or vRP.hasGroup({uid, "Police"})
    local isEms = vRP.hasPermission({uid, "ems.menu"}) or vRP.hasPermission({uid, "ems.revive"}) or vRP.hasGroup({uid, "ems"}) or vRP.hasGroup({uid, "EMS"})
    return isCop, isEms
end

-- Only returns calls this user's department(s) should see
local function getCallsFor(uid, cb)
    local isCop, isEms = getDepts(uid)
    local depts = "'all'"
    if isCop then depts = depts .. ",'police'" end
    if isEms then depts = depts .. ",'ems'" end
    exports.ghmattimysql:execute("SELECT * FROM vrp_cad_calls WHERE status != 'closed' AND department IN (" .. depts .. ") ORDER BY id DESC", {}, cb)
end

local function broadcastCalls()
    for uid, src in pairs(vRP.getUsers({})) do
        local isCop, isEms = getDepts(uid)
        if isCop or isEms then
            getCallsFor(uid, function(calls)
                TriggerClientEvent('vrp_cad:client:updateCalls', src, calls or {})
            end)
        end
    end
end

-- ===== 911 call from the phone (exported) =====
local function create911Call(src, dept, description, x, y, z, streetName)
    local user_id = vRP.getUserId({src})
    if not user_id then return false end
    if dept ~= "police" and dept ~= "ems" then return false end

    description = (tostring(description or ""):gsub("~", "")):sub(1, 300)
    if description == "" then description = "No description provided" end
    streetName = tostring(streetName or "Unknown Location")

    exports.ghmattimysql:execute("SELECT * FROM vrp_user_identities WHERE user_id = @uid", {['@uid'] = user_id}, function(rows)
        local row = rows and rows[1] or nil
        local callerName = row and (row.firstname .. " " .. (row.name or row.registration or "")) or ("Citizen #" .. user_id)
        local phone = row and row.phone or "N/A"
        local age = row and tostring(row.age) or "N/A"

        exports.ghmattimysql:execute("SELECT home, number FROM vrp_user_homes WHERE user_id = @uid", {['@uid'] = user_id}, function(homeRows)
            local address = "N/A"
            if homeRows and #homeRows > 0 then
                address = homeRows[1].home .. (homeRows[1].number and (" #" .. homeRows[1].number) or "")
            end

            local typeLabel = dept == "police" and "911 Police Call" or "911 EMS Call"

            exports.ghmattimysql:execute("INSERT INTO vrp_cad_calls (call_type, location, description, status, coords_x, coords_y, coords_z, assigned_units, caller_name, caller_phone, caller_age, caller_address, department) VALUES (@type, @loc, @desc, 'active', @x, @y, @z, '', @cname, @cphone, @cage, @caddr, @dept)", {
                ['@type'] = typeLabel,
                ['@loc'] = streetName,
                ['@desc'] = description,
                ['@x'] = tonumber(x) or 0.0,
                ['@y'] = tonumber(y) or 0.0,
                ['@z'] = tonumber(z) or 0.0,
                ['@cname'] = callerName,
                ['@cphone'] = phone,
                ['@cage'] = age,
                ['@caddr'] = address,
                ['@dept'] = dept
            }, function()
                -- Sound + notification only to the correct group
                for uid, s in pairs(vRP.getUsers({})) do
                    local isCop, isEms = getDepts(uid)
                    if (dept == "police" and isCop) or (dept == "ems" and isEms) then
                        TriggerClientEvent('vrp_cad:client:playAudioAlert', s, 'cad_dispatch.mp3')
                        TriggerClientEvent('vrp_cad:client:newDispatch', s, {
                            type = typeLabel,
                            location = streetName,
                            description = description
                        })
                    end
                end
                broadcastCalls()
            end)
        end)
    end)
    return true
end
exports('create911Call', create911Call)

Citizen.CreateThread(function()
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS vrp_cad_calls (
            id INT AUTO_INCREMENT PRIMARY KEY,
            call_type VARCHAR(255) NOT NULL,
            location VARCHAR(255) NOT NULL,
            description TEXT,
            status VARCHAR(50) DEFAULT 'active',
            coords_x FLOAT DEFAULT 0,
            coords_y FLOAT DEFAULT 0,
            coords_z FLOAT DEFAULT 0,
            assigned_units TEXT,
            caller_name VARCHAR(255) DEFAULT 'Unknown',
            caller_phone VARCHAR(50) DEFAULT 'N/A',
            caller_age VARCHAR(50) DEFAULT 'N/A',
            caller_address VARCHAR(255) DEFAULT 'N/A',
            department VARCHAR(20) DEFAULT 'all',
            date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function()
        -- Adds the column on existing installs (MariaDB syntax)
        exports.ghmattimysql:execute("ALTER TABLE vrp_cad_calls ADD COLUMN IF NOT EXISTS department VARCHAR(20) DEFAULT 'all'", {})
    end)
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS vrp_cad_criminal_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            target_name VARCHAR(255),
            author VARCHAR(100),
            report_type VARCHAR(50) DEFAULT 'Arrest',
            title VARCHAR(255),
            details TEXT,
            fine_amount INT DEFAULT 0,
            date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    exports.ghmattimysql:execute([[
        CREATE TABLE IF NOT EXISTS vrp_cad_medical_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            target_name VARCHAR(255),
            author VARCHAR(100),
            diagnosis VARCHAR(255),
            treatment TEXT,
            service_fee INT DEFAULT 0,
            date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end)

RegisterCommand('tablet', function(source, args, rawCommand)
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    local isCop, isEms = getDepts(user_id)

    if isCop or isEms then
        getCallsFor(user_id, function(calls)
            TriggerClientEvent('vrp_cad:client:openMDT', source, {isCop = isCop, isEms = isEms}, calls or {}, activeOfficers)
        end)
    else
        TriggerClientEvent('chat:addMessage', source, { args = {"CAD", "You do not have access to an MDT tablet."} })
    end
end, false)

RegisterServerEvent('vrp_cad:server:updateStatus')
AddEventHandler('vrp_cad:server:updateStatus', function(department, statusCode, statusDesc, clientCoords, streetName)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    local isCop = vRP.hasPermission({user_id, "police.menu"}) or vRP.hasPermission({user_id, "police.loadout"}) or vRP.hasGroup({user_id, "cop"}) or vRP.hasGroup({user_id, "Police"})
    local isEms = vRP.hasPermission({user_id, "ems.menu"}) or vRP.hasPermission({user_id, "ems.revive"}) or vRP.hasGroup({user_id, "ems"}) or vRP.hasGroup({user_id, "EMS"})

    if department == "police" and not isCop then return end
    if department == "ems" and not isEms then return end

    vRP.getUserIdentity({user_id, function(identity)
        local firstname = identity and identity.firstname or nil
        local lastname = identity and (identity.name or identity.registration) or nil

        local queryStr = "SELECT * FROM vrp_user_identities WHERE user_id = @user_id"
        local queryParams = {['@user_id'] = user_id}

        if firstname and lastname then
            queryStr = "SELECT * FROM vrp_user_identities WHERE firstname = @firstname AND name = @lastname"
            queryParams = {['@firstname'] = firstname, ['@lastname'] = lastname}
        end

        exports.ghmattimysql:execute(queryStr, queryParams, function(rows)
            local row = rows and rows[1] or nil
            local personnelName = row and (row.firstname .. " " .. (row.name or row.registration)) or (firstname and lastname and (firstname .. " " .. lastname) or ("Personnel #" .. user_id))
            local phone = row and row.phone or "N/A"
            local age = row and tostring(row.age) or "N/A"

            -- Fetch address from vrp_user_homes table
            exports.ghmattimysql:execute("SELECT home, number FROM vrp_user_homes WHERE user_id = @uid", {['@uid'] = user_id}, function(homeRows)
                local address = "N/A"
                if homeRows and #homeRows > 0 then
                    address = homeRows[1].home .. (homeRows[1].number and (" #" .. homeRows[1].number) or "")
                end

                if statusCode == "10-7" then
                    activeOfficers[user_id] = nil
                else
                    activeOfficers[user_id] = {
                        id = user_id,
                        name = personnelName,
                        department = department,
                        code = statusCode,
                        description = statusDesc
                    }
                end

                if statusCode == "10-99" then
                    TriggerClientEvent('vrp_cad:client:playAudioAlert', -1, 'cad_distress.mp3')
                    TriggerClientEvent('chat:addMessage', -1, { args = {"DISPATCH", "ATTENTION ALL UNITS: 10-99 DISTRESS SIGNAL ACTIVATED BY " .. string.upper(personnelName) .. "!"} })

                    local locationText = streetName or "Unknown Location"
                    local cx, cy, cz = 0.0, 0.0, 0.0
                    if clientCoords then
                        cx, cy, cz = clientCoords.x, clientCoords.y, clientCoords.z
                    end

                    exports.ghmattimysql:execute("INSERT INTO vrp_cad_calls (call_type, location, description, status, coords_x, coords_y, coords_z, assigned_units, caller_name, caller_phone, caller_age, caller_address) VALUES (@type, @loc, @desc, 'active', @x, @y, @z, '', @cname, @cphone, @cage, @caddr)", {
                        ['@type'] = "10-99 Distress (" .. string.upper(department) .. ")",
                        ['@loc'] = locationText,
                        ['@desc'] = personnelName .." is in critical distress/down!",
                        ['@x'] = cx,
                        ['@y'] = cy,
                        ['@z'] = cz,
                        ['@cname'] = personnelName,
                        ['@cphone'] = phone,
                        ['@cage'] = age,
                        ['@caddr'] = address
                    }, function()
                        for uid, src in pairs(vRP.getUsers({})) do
                            local c, e = getDepts(uid)
                            if c or e then
                                TriggerClientEvent('vrp_cad:client:updateOfficerRoster', src, activeOfficers)
                            end
                        end
                        broadcastCalls()
                    end)
                else
                    local userSources = vRP.getUsers({})
                    for uid, src in pairs(userSources) do
                        if vRP.hasPermission({uid, "police.menu"}) or vRP.hasGroup({uid, "cop"}) or vRP.hasGroup({uid, "Police"}) or vRP.hasPermission({uid, "ems.menu"}) or vRP.hasGroup({uid, "ems"}) or vRP.hasGroup({uid, "EMS"}) then
                            TriggerClientEvent('vrp_cad:client:updateOfficerRoster', src, activeOfficers)
                        end
                    end
                end
            end)
        end)
    end})
end)

RegisterServerEvent('vrp_cad:server:triggerPanicButton')
AddEventHandler('vrp_cad:server:triggerPanicButton', function(clientCoords, streetName)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    local isCop = vRP.hasPermission({user_id, "police.menu"}) or vRP.hasPermission({user_id, "police.loadout"}) or vRP.hasGroup({user_id, "cop"}) or vRP.hasGroup({user_id, "Police"})
    local isEms = vRP.hasPermission({user_id, "ems.menu"}) or vRP.hasPermission({user_id, "ems.revive"}) or vRP.hasGroup({user_id, "ems"}) or vRP.hasGroup({user_id, "EMS"})

    if not (isCop or isEms) then return end
    local dept = isCop and "police" or "ems"

    vRP.getUserIdentity({user_id, function(identity)
        local firstname = identity and identity.firstname or nil
        local lastname = identity and (identity.name or identity.registration) or nil

        local queryStr = "SELECT * FROM vrp_user_identities WHERE user_id = @user_id"
        local queryParams = {['@user_id'] = user_id}

        if firstname and lastname then
            queryStr = "SELECT * FROM vrp_user_identities WHERE firstname = @firstname AND name = @lastname"
            queryParams = {['@firstname'] = firstname, ['@lastname'] = lastname}
        end

        exports.ghmattimysql:execute(queryStr, queryParams, function(rows)
            local row = rows and rows[1] or nil
            local personnelName = row and (row.firstname .. " " .. (row.name or row.registration)) or (firstname and lastname and (firstname .. " " .. lastname) or ("Personnel #" .. user_id))
            local phone = row and row.phone or "N/A"
            local age = row and tostring(row.age) or "N/A"

            -- Fetch address from vrp_user_homes table
            exports.ghmattimysql:execute("SELECT home, number FROM vrp_user_homes WHERE user_id = @uid", {['@uid'] = user_id}, function(homeRows)
                local address = "N/A"
                if homeRows and #homeRows > 0 then
                    address = homeRows[1].home .. (homeRows[1].number and (" #" .. homeRows[1].number) or "")
                end

                activeOfficers[user_id] = {
                    id = user_id,
                    name = personnelName,
                    department = dept,
                    code = "10-99",
                    description = "Panic Button Triggered"
                }

                TriggerClientEvent('vrp_cad:client:playAudioAlert', -1, 'cad_distress.mp3')
                TriggerClientEvent('chat:addMessage', -1, { args = {"DISPATCH", "ATTENTION ALL UNITS: PANIC BUTTON (10-99) ACTIVATED BY " .. string.upper(personnelName) .. "!"} })

                local locationText = streetName or "Unknown Location"
                local cx, cy, cz = 0.0, 0.0, 0.0
                if clientCoords then
                    cx, cy, cz = clientCoords.x, clientCoords.y, clientCoords.z
                end

                exports.ghmattimysql:execute("INSERT INTO vrp_cad_calls (call_type, location, description, status, coords_x, coords_y, coords_z, assigned_units, caller_name, caller_phone, caller_age, caller_address) VALUES (@type, @loc, @desc, 'active', @x, @y, @z, '', @cname, @cphone, @cage, @caddr)", {
                    ['@type'] = "10-99 Panic Button (" .. string.upper(dept) .. ")",
                    ['@loc'] = locationText,
                    ['@desc'] = personnelName .. " triggered their emergency panic button!",
                    ['@x'] = cx,
                    ['@y'] = cy,
                    ['@z'] = cz,
                    ['@cname'] = personnelName,
                    ['@cphone'] = phone,
                    ['@cage'] = age,
                    ['@caddr'] = address
                }, function()
                    for uid, src in pairs(vRP.getUsers({})) do
                        local c, e = getDepts(uid)
                        if c or e then
                            TriggerClientEvent('vrp_cad:client:updateOfficerRoster', src, activeOfficers)
                        end
                    end
                    broadcastCalls()
                end)
            end)
        end)
    end})
end)

RegisterServerEvent('vrp_cad:server:assignToCall')
AddEventHandler('vrp_cad:server:assignToCall', function(callId)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    vRP.getUserIdentity({user_id, function(identity)
        local officerName = identity and (identity.firstname .. " " .. (identity.name or identity.registration)) or ("Officer #" .. user_id)

        exports.ghmattimysql:execute("SELECT assigned_units FROM vrp_cad_calls WHERE id = @id", {['@id'] = callId}, function(callRows)
            if callRows and #callRows > 0 then
                local currentAssigned = callRows[1].assigned_units or ""
                if not string.find(currentAssigned, officerName, 1, true) then
                    local newAssigned = currentAssigned == "" and officerName or (currentAssigned .. ", " .. officerName)
                    exports.ghmattimysql:execute("UPDATE vrp_cad_calls SET assigned_units = @units WHERE id = @id", {['@units'] = newAssigned, ['@id'] = callId}, function()
                        broadcastCalls()
                    end)
                end
            end
        end)
    end})
end)

RegisterServerEvent('vrp_cad:server:closeCall')
AddEventHandler('vrp_cad:server:closeCall', function(callId)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    if vRP.hasPermission({user_id, "police.menu"}) or vRP.hasGroup({user_id, "cop"}) or vRP.hasGroup({user_id, "Police"}) or vRP.hasPermission({user_id, "ems.menu"}) or vRP.hasGroup({user_id, "ems"}) or vRP.hasGroup({user_id, "EMS"}) then
        exports.ghmattimysql:execute("UPDATE vrp_cad_calls SET status = 'closed' WHERE id = @id", {['@id'] = callId}, function()
            broadcastCalls()
        end)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local user_id = vRP.getUserId({source})
    if user_id and activeOfficers[user_id] then
        activeOfficers[user_id] = nil
        local userSources = vRP.getUsers({})
        for uid, src in pairs(userSources) do
            TriggerClientEvent('vrp_cad:client:updateOfficerRoster', src, activeOfficers)
        end
    end
end)

local function performCivilianSearch(source, queryText)
    local searchQuery = "%" .. queryText .. "%"
    exports.ghmattimysql:execute("SELECT * FROM vrp_user_identities WHERE firstname LIKE @q OR name LIKE @q OR CONCAT(firstname, ' ', name) LIKE @q", {['@q'] = searchQuery}, function(identities)
        if identities and #identities > 0 then
            local civResults = {}
            local completed = 0

            for _, identity in ipairs(identities) do
                local lastNameField = identity.name or identity.registration or ""
                local fullName = identity.firstname .. " " .. lastNameField
                local userIdStr = tostring(identity.user_id)
                local targetUserId = identity.user_id

                -- Fetch home address from vrp_user_homes table
                exports.ghmattimysql:execute("SELECT home, number FROM vrp_user_homes WHERE user_id = @uid", {['@uid'] = targetUserId}, function(homeRows)
                    local addressStr = "N/A"
                    if homeRows and #homeRows > 0 then
                        local homeEntry = homeRows[1]
                        addressStr = homeEntry.home .. (homeEntry.number and (" #" .. homeEntry.number) or "")
                    end

                    exports.ghmattimysql:execute("SELECT * FROM vrp_cad_criminal_records WHERE target_name = @tname OR target_name = @uid", {['@tname'] = fullName, ['@uid'] = userIdStr}, function(criminalRows)
                        exports.ghmattimysql:execute("SELECT * FROM vrp_cad_medical_records WHERE target_name = @tname OR target_name = @uid", {['@tname'] = fullName, ['@uid'] = userIdStr}, function(medicalRows)
                            table.insert(civResults, {
                                user_id = identity.user_id,
                                firstname = identity.firstname,
                                lastname = lastNameField,
                                fullname = fullName,
                                phone = identity.phone or "N/A",
                                age = identity.age or "N/A",
                                address = addressStr,
                                criminal_records = criminalRows or {},
                                medical_records = medicalRows or {}
                            })

                            completed = completed + 1
                            if completed == #identities then
                                TriggerClientEvent('vrp_cad:client:receiveCivilianSearch', source, civResults)
                            end
                        end)
                    end)
                end)
            end
        else
            TriggerClientEvent('vrp_cad:client:receiveCivilianSearch', source, {})
        end
    end)
end

RegisterServerEvent('vrp_cad:server:searchCivilian')
AddEventHandler('vrp_cad:server:searchCivilian', function(queryText)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end
    performCivilianSearch(source, queryText)
end)

RegisterServerEvent('vrp_cad:server:lookupPlate')
AddEventHandler('vrp_cad:server:lookupPlate', function(plateText)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    if not (vRP.hasPermission({user_id, "police.menu"}) or vRP.hasGroup({user_id, "cop"})) then return end

    local cleanedPlate = plateText:gsub("^%s*(.-)%s*$", "%1")
    local searchPattern = "%" .. cleanedPlate .. "%"

    exports.ghmattimysql:execute("SELECT * FROM vrp_user_vehicles WHERE UPPER(TRIM(vehicle_plate)) LIKE UPPER(TRIM(@plate))", {['@plate'] = searchPattern}, function(vehicleRows)
        if vehicleRows and #vehicleRows > 0 then
            local veh = vehicleRows[1]
            local ownerId = veh.user_id
            local vehName = getFriendlyVehicleName(veh.vehicle)

            if ownerId then
                exports.ghmattimysql:execute("SELECT firstname, name FROM vrp_user_identities WHERE user_id = @user_id", {['@user_id'] = ownerId}, function(ownerRows)
                    local ownerName = ownerRows and #ownerRows > 0 and (ownerRows[1].firstname .. " " .. (ownerRows[1].name or ownerRows[1].registration)) or ("Citizen ID: " .. tostring(ownerId))
                    TriggerClientEvent('vrp_cad:client:receivePlateData', source, {
                        found = true,
                        plate = veh.vehicle_plate,
                        vehicle = tostring(vehName),
                        owner = ownerName
                    })
                end)
            else
                TriggerClientEvent('vrp_cad:client:receivePlateData', source, {
                    found = true,
                    plate = veh.vehicle_plate,
                    vehicle = tostring(vehName),
                    owner = "Unknown Owner"
                })
            end
        else
            TriggerClientEvent('vrp_cad:client:receivePlateData', source, { found = false })
        end
    end)
end)

RegisterNetEvent('vrp_cad:server:addCriminalRecord')
AddEventHandler('vrp_cad:server:addCriminalRecord', function(data)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end
    if type(data) ~= "table" then return end

    local targetName = data.target_name
    local targetUserId = data.target_user_id
    local reportType = data.report_type or "Arrest"
    local title = data.title or "General Report"
    local details = data.details or ""
    local fineAmount = tonumber(data.fine_amount) or 0

    vRP.getUserIdentity({user_id, function(identity)
        local officerName = identity and (identity.firstname .. " " .. (identity.name or identity.registration)) or ("Officer #" .. user_id)

        exports.ghmattimysql:execute("INSERT INTO vrp_cad_criminal_records (target_name, author, report_type, title, details, fine_amount) VALUES (@tname, @author, @rtype, @title, @details, @fine)", {
            ['@tname'] = targetName,
            ['@author'] = officerName,
            ['@rtype'] = reportType,
            ['@title'] = title,
            ['@details'] = details,
            ['@fine'] = fineAmount
        }, function(result)
            if fineAmount > 0 and targetUserId then
                vRP.tryBankPayment({targetUserId, fineAmount})
                local targetSource = vRP.getUserSource({targetUserId})
                if targetSource then
                    TriggerClientEvent('chat:addMessage', targetSource, { args = {"BILLING", "You have been fined $" .. fineAmount .. " for: " .. title} })
                end
            end

            performCivilianSearch(source, targetName)
        end)
    end})
end)

RegisterNetEvent('vrp_cad:server:deleteCriminalRecord')
AddEventHandler('vrp_cad:server:deleteCriminalRecord', function(recordId, targetName)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    if vRP.hasPermission({user_id, "police.menu"}) or vRP.hasGroup({user_id, "cop"}) or vRP.hasGroup({user_id, "Police"}) then
        exports.ghmattimysql:execute("DELETE FROM vrp_cad_criminal_records WHERE id = @id", {['@id'] = recordId}, function()
            if targetName then
                performCivilianSearch(source, targetName)
            end
        end)
    end
end)

RegisterNetEvent('vrp_cad:server:updateCriminalRecord')
AddEventHandler('vrp_cad:server:updateCriminalRecord', function(data)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    if not (vRP.hasPermission({user_id, "police.menu"}) or vRP.hasGroup({user_id, "cop"}) or vRP.hasGroup({user_id, "Police"})) then return end
    if type(data) ~= "table" then return end

    local recordId = data.id
    local targetUserId = data.target_user_id
    local targetName = data.target_name
    local reportType = data.report_type
    local title = data.title
    local details = data.details
    local newFine = tonumber(data.fine_amount) or 0

    exports.ghmattimysql:execute("SELECT fine_amount FROM vrp_cad_criminal_records WHERE id = @id", {['@id'] = recordId}, function(rows)
        local oldFine = rows and #rows > 0 and tonumber(rows[1].fine_amount) or 0
        local fineDiff = newFine - oldFine

        exports.ghmattimysql:execute("UPDATE vrp_cad_criminal_records SET report_type = @rtype, title = @title, details = @details, fine_amount = @fine WHERE id = @id", {
            ['@rtype'] = reportType,
            ['@title'] = title,
            ['@details'] = details,
            ['@fine'] = newFine,
            ['@id'] = recordId
        }, function()
            if fineDiff ~= 0 and targetUserId then
                local targetSource = vRP.getUserSource({targetUserId})
                if fineDiff > 0 then
                    vRP.tryBankPayment({targetUserId, fineDiff})
                    if targetSource then
                        TriggerClientEvent('chat:addMessage', targetSource, { args = {"BILLING", "Your fine for '" .. title .. "' was increased. An additional $" .. fineDiff .. " has been charged."} })
                    end
                elseif fineDiff < 0 then
                    local refundAmount = math.abs(fineDiff)
                    vRP.giveBankMoney({targetUserId, refundAmount})
                    if targetSource then
                        TriggerClientEvent('chat:addMessage', targetSource, { args = {"BILLING", "Your fine for '" .. title .. "' was reduced. A refund of $" .. refundAmount .. " has been issued."} })
                    end
                end
            end

            performCivilianSearch(source, targetName)
        end)
    end)
end)

RegisterNetEvent('vrp_cad:server:addMedicalRecord')
AddEventHandler('vrp_cad:server:addMedicalRecord', function(data)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end
    if type(data) ~= "table" then return end

    local targetName = data.target_name
    local targetUserId = data.target_user_id
    local diagnosis = data.diagnosis or ""
    local treatment = data.treatment or ""
    local serviceFee = tonumber(data.service_fee) or 0

    vRP.getUserIdentity({user_id, function(identity)
        local medicName = identity and (identity.firstname .. " " .. (identity.name or identity.registration)) or ("Paramedic #" .. user_id)

        exports.ghmattimysql:execute("INSERT INTO vrp_cad_medical_records (target_name, author, diagnosis, treatment, service_fee) VALUES (@tname, @author, @diag, @treat, @fee)", {
            ['@tname'] = targetName,
            ['@author'] = medicName,
            ['@diag'] = diagnosis,
            ['@treat'] = treatment,
            ['@fee'] = serviceFee
        }, function()
            if serviceFee > 0 and targetUserId then
                vRP.tryBankPayment({targetUserId, serviceFee})
                local targetSource = vRP.getUserSource({targetUserId})
                if targetSource then
                    TriggerClientEvent('chat:addMessage', targetSource, { args = {"EMS", "You have been charged $" .. serviceFee .. " for medical services: " .. treatment} })
                end

                vRP.giveBankMoney({user_id, serviceFee})
                TriggerClientEvent('chat:addMessage', source, { args = {"EMS", "You received a commission of $" .. serviceFee .. " for filing medical services."} })
            end

            performCivilianSearch(source, targetName)
        end)
    end})
end)

RegisterServerEvent('vrp_cad:server:deleteMedicalRecord')
AddEventHandler('vrp_cad:server:deleteMedicalRecord', function(recordId, targetName)
    local source = source
    local user_id = vRP.getUserId({source})
    if not user_id then return end

    if vRP.hasPermission({user_id, "ems.menu"}) or vRP.hasGroup({user_id, "ems"}) or vRP.hasGroup({user_id, "EMS"}) then
        exports.ghmattimysql:execute("DELETE FROM vrp_cad_medical_records WHERE id = @id", {['@id'] = recordId}, function()
            if targetName then performCivilianSearch(source, targetName) end
        end)
    end
end)
