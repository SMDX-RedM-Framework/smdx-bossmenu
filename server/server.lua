local SMDXCore = exports['smdx-core']:GetSMDX()
local Accounts = {}

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = _type == 'success' and '^2' or '^1'

    print(('^1['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then 
            versionCheckPrint('error', 'Currently unable to run a version check.')
            return 
        end

        --versionCheckPrint('success', ('Current Version: %s'):format(currentVersion))
        --versionCheckPrint('success', ('Latest Version: %s'):format(text))
        
        if text == currentVersion then
            versionCheckPrint('success', 'You are running the latest version.')
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

-----------------------------------------------------------------------

-------------------------------------------------------------------------------------------
-- functions
-------------------------------------------------------------------------------------------

function GetAccount(account)
    return Accounts[account] or 0
end

function AddMoney(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end

    Accounts[account] = Accounts[account] + amount
    MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount', { ['job_name'] = account, ['amount'] = Accounts[account], ['type'] = 'boss' })
end

function RemoveMoney(account, amount)
    local isRemoved = false
    if amount > 0 then
        if not Accounts[account] then
            Accounts[account] = 0
        end

        if Accounts[account] >= amount then
            Accounts[account] = Accounts[account] - amount
            isRemoved = true
        end

        MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "boss"', { Accounts[account], account })
    end
    return isRemoved
end

MySQL.ready(function ()
    local bossmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "boss"', {})
    if not bossmenu then return end

    for _,v in ipairs(bossmenu) do
        Accounts[v.job_name] = v.amount
    end
end)

-------------------------------------------------------------------------------------------
-- withdraw money
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:server:withdrawMoney', function(amount)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    local job = Player.PlayerData.job.name
    if RemoveMoney(job, amount) then
        Player.Functions.AddMoney('cash', amount, Lang:t('lang_24'))
        TriggerEvent('smdx-log:server:CreateLog', 'bossmenu', Lang:t('lang_25'), 'blue', Player.PlayerData.name.. Lang:t('lang_26') .. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_27') ..amount, type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_28'), type = 'error', duration = 5000 })
    end
end)

-------------------------------------------------------------------------------------------
-- deposit money
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:server:depositMoney', function(amount)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    if Player.Functions.RemoveMoney('cash', amount) then
        local job = Player.PlayerData.job.name
        AddMoney(job, amount)
        TriggerEvent('smdx-log:server:CreateLog', 'bossmenu', Lang:t('lang_29'), 'blue', Player.PlayerData.name.. Lang:t('lang_30') .. amount .. ' (' .. job .. ')', false)
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_31') ..amount, type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_32'), type = 'error', duration = 5000 })
    end

    TriggerClientEvent('smdx-bossmenu:client:OpenMenu', src)
end)

SMDXCore.Functions.CreateCallback('smdx-bossmenu:server:GetAccount', function(_, cb, jobname)
    local result = GetAccount(jobname)
    cb(result)
end)

-------------------------------------------------------------------------------------------
-- get employees
-------------------------------------------------------------------------------------------
SMDXCore.Functions.CreateCallback('smdx-bossmenu:server:GetEmployees', function(source, cb, jobname)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)

    if not Player.PlayerData.job.isboss then return end

    local employees = {}
    local players = MySQL.query.await("SELECT * FROM `players` WHERE `job` LIKE '%".. jobname .."%'", {})
    if players[1] ~= nil then
        for _, value in pairs(players) do
            local isOnline = SMDXCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                employees[#employees+1] = {
                empSource = isOnline.PlayerData.citizenid,
                grade = isOnline.PlayerData.job.grade,
                isboss = isOnline.PlayerData.job.isboss,
                name = '🟢 ' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                }
            else
                employees[#employees+1] = {
                empSource = value.citizenid,
                grade =  json.decode(value.job).grade,
                isboss = json.decode(value.job).isboss,
                name = '❌ ' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                }
            end
        end
        table.sort(employees, function(a, b)
            return a.grade.level > b.grade.level
        end)
    end
    cb(employees)
end)

-------------------------------------------------------------------------------------------
-- grade update
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:server:GradeUpdate', function(data)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)
    local Employee = SMDXCore.Functions.GetPlayerByCitizenId(data.cid)

    if not Player.PlayerData.job.isboss then return end
    if data.grade > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_33'), type = 'error', duration = 5000 }) return end
    
    if Employee then
        if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_34'), type = 'success', duration = 5000 })
            TriggerClientEvent('ox_lib:notify', src, {title = Employee.PlayerData.source, Lang:t('lang_35') ..data.gradename..'.', type = 'success', duration = 5000 })
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_36'), type = 'error', duration = 5000 })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_37'), type = 'error', duration = 5000 })
    end
end)

-------------------------------------------------------------------------------------------
-- fire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:server:FireEmployee', function(target)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)
    local Employee = SMDXCore.Functions.GetPlayerByCitizenId(target)

    if not Player.PlayerData.job.isboss then return end

    if Employee then
        if target ~= Player.PlayerData.citizenid then
            if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_38'), type = 'error', duration = 5000 }) return end
            if Employee.Functions.SetJob('unemployed', '0') then
                TriggerEvent('smdx-log:server:CreateLog', 'bossmenu', Lang:t('lang_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
                TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_41'), type = 'success', duration = 5000 })
                TriggerClientEvent('ox_lib:notify', src, {title = Employee.PlayerData.source , Lang:t('lang_42'), type = 'error', duration = 5000 })
            else
                TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_43'), type = 'error', duration = 5000 })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_44'), type = 'error', duration = 5000 })
        end
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] ~= nil then
            Employee = player[1]
            Employee.job = json.decode(Employee.job)
            if Employee.job.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_45'), type = 'error', duration = 5000 }) return end
            local job = {}
            job.name = 'unemployed'
            job.label = 'Unemployed'
            job.payment = SMDXCore.Shared.Jobs[job.name].grades['0'].payment or 500
            job.onduty = true
            job.isboss = false
            job.grade = {}
            job.grade.name = nil
            job.grade.level = 0
            MySQL.update('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), target })
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_41'), type = 'success', duration = 5000 })
            TriggerEvent('smdx-log:server:CreateLog', 'bossmenu', Lang:t('lang_39'), 'red', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. Lang:t('lang_40') .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.job.name .. ')', false)
        else
            TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_37'), type = 'error', duration = 5000 })
        end
    end
end)

-------------------------------------------------------------------------------------------
-- hire employee
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:server:HireEmployee', function(recruit)
    local src = source
    local Player = SMDXCore.Functions.GetPlayer(src)
    local Target = SMDXCore.Functions.GetPlayer(recruit)

    if not Player.PlayerData.job.isboss then return end

    if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang_46') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. Lang:t('lang_47') .. Player.PlayerData.job.label .. '', type = 'success', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', src, {title = Target.PlayerData.source , Lang:t('lang_48') .. Player.PlayerData.job.label .. '', type = 'success', duration = 5000 })
        TriggerEvent('smdx-log:server:CreateLog', 'bossmenu', Lang:t('lang_49'), 'lightgreen', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. Lang:t('lang_50') .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', false)
    end
end)

-------------------------------------------------------------------------------------------
-- get closest player
-------------------------------------------------------------------------------------------
SMDXCore.Functions.CreateCallback('smdx-bossmenu:getplayers', function(source, cb)
    local src = source
    local players = {}
    local PlayerPed = GetPlayerPed(src)
    local pCoords = GetEntityCoords(PlayerPed)
    for _, v in pairs(SMDXCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local tCoords = GetEntityCoords(targetped)
        local dist = #(pCoords - tCoords)
        if PlayerPed ~= targetped and dist < 10 then
            local ped = SMDXCore.Functions.GetPlayer(v)
            players[#players+1] = {
            id = v,
            coords = GetEntityCoords(targetped),
            name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer = ped.PlayerData.source
            }
        end
    end
        table.sort(players, function(a, b)
            return a.name < b.name
        end)
    cb(players)
end)

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
