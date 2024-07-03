local SMDXCore = exports['smdx-core']:GetSMDX()
local PlayerJob = SMDXCore.Functions.GetPlayerData().job

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        PlayerJob = SMDXCore.Functions.GetPlayerData().job
    end
end)

RegisterNetEvent('SMDXCore:Client:OnPlayerLoaded', function()
    PlayerJob = SMDXCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('SMDXCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

local function comma_value(amount)
    local formatted = amount
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-------------------------------------------------------------------------------------------
-- prompts and blips if needed
-------------------------------------------------------------------------------------------
CreateThread(function()
    for _, v in pairs(Config.BossLocations) do
        exports['smdx-core']:createPrompt(v.id, v.coords, SMDXCore.Shared.Keybinds[Config.Keybind], Lang:t('lang_51')..v.name, {
            type = 'client',
            event = 'smdx-bossmenu:client:mainmenu',
            args = {},
        })
        if v.showblip == true then
            local BossMenuBlip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(BossMenuBlip,  joaat(Config.Blip.blipSprite), true)
            SetBlipScale(BossMenuBlip, Config.Blip.blipScale)
            SetBlipName(BossMenuBlip, Config.Blip.blipName)
        end
    end
end)

-------------------------------------------------------------------------------------------
-- main menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:mainmenu', function()
    if not PlayerJob.name or not PlayerJob.isboss then return end
    lib.registerContext({
        id = 'boss_mainmenu',
        title = Lang:t('lang_1'),
        options = {
            {
                title = Lang:t('lang_2'),
                description = Lang:t('lang_3'),
                icon = 'fa-solid fa-list',
                event = 'smdx-bossmenu:client:employeelist',
                arrow = true
            },
            {
                title = Lang:t('lang_4'),
                description = Lang:t('lang_5'),
                icon = 'fa-solid fa-hand-holding',
                event = 'smdx-bossmenu:client:HireMenu',
                arrow = true
            },
            {
                title = Lang:t('lang_6'),
                description = Lang:t('lang_7'),
                icon = "fa-solid fa-box-open",
                event = 'smdx-bossmenu:client:Stash',
                arrow = true
            },
            {
                title = Lang:t('lang_8'),
                description = Lang:t('lang_9'),
                icon = "fa-solid fa-sack-dollar",
                event = 'smdx-bossmenu:client:SocietyMenu',
                arrow = true
            },
        }
    })
    lib.showContext("boss_mainmenu")
end)

-------------------------------------------------------------------------------------------
-- employee menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:employeelist', function()
    SMDXCore.Functions.TriggerCallback('smdx-bossmenu:server:GetEmployees', function(result)
        local options = {}
        for _, v in pairs(result) do
            options[#options + 1] = {
                title = v.name,
                description = v.grade.name,
                icon = 'fa-solid fa-circle-user',
                event = 'smdx-bossmenu:client:ManageEmployee',
                args = { player = v, work = PlayerJob },
                arrow = true,
            }
        end
        lib.registerContext({
            id = 'employeelist_menu',
            title = Lang:t('lang_10'),
            menu = 'boss_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('employeelist_menu')
    end, PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- manage employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:ManageEmployee', function(data)
    local options = {}
    for k, v in pairs(SMDXCore.Shared.Jobs[data.work.name].grades) do
        options[#options + 1] = {
            title = Lang:t('lang_11')..v.name,
            description = Lang:t('lang_12') .. k,
            icon = 'fa-solid fa-file-pen',
            serverEvent = 'smdx-bossmenu:server:GradeUpdate',
            args = { cid = data.player.empSource, grade = tonumber(k), gradename = v.name }
        }
    end
    options[#options + 1] = {
        title = Lang:t('lang_13'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = 'smdx-bossmenu:server:FireEmployee',
        args = data.player.empSource,
        iconColor = 'red'
    }
    lib.registerContext({
        id = 'manageemployee_menu',
        title = Lang:t('lang_14'),
        menu = 'employeelist_menu',
        onBack = function() end,
        position = 'top-right',
        options = options
    })
    lib.showContext('manageemployee_menu')
end)

-------------------------------------------------------------------------------------------
-- hire employees
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:HireMenu', function()
    SMDXCore.Functions.TriggerCallback('smdx-bossmenu:getplayers', function(players)
        local options = {}
        for _, v in pairs(players) do
            if v and v ~= PlayerId() then
                options[#options + 1] = {
                    title = v.name,
                    description = Lang:t('lang_15') .. v.citizenid .. Lang:t('lang_16') .. v.sourceplayer,
                    icon = 'fa-solid fa-user-check',
                    serverEvent = 'smdx-bossmenu:server:HireEmployee',
                    args = v.sourceplayer,
                    arrow = true
                }
            end
        end
        lib.registerContext({
            id = 'hireemployees_menu',
            title = Lang:t('lang_4'),
            menu = 'boss_mainmenu',
            onBack = function() end,
            position = 'top-right',
            options = options
        })
        lib.showContext('hireemployees_menu')
    end)
end)

-------------------------------------------------------------------------------------------
-- boss stash
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:Stash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "boss_" .. PlayerJob.name, {
        maxweight = 4000000,
        slots = 25,
    })
    TriggerEvent("inventory:client:SetCurrentStash", "boss_" .. PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- society menu
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:SocietyMenu', function()
    local currentmoney = SMDXCore.Functions.GetPlayerData().money['cash']
    SMDXCore.Functions.TriggerCallback('smdx-bossmenu:server:GetAccount', function(cb)
        lib.registerContext({
            id = 'society_menu',
            title = Lang:t('lang_17') .. comma_value(cb),
            options = {
                {
                    title = Lang:t('lang_18'),
                    description = Lang:t('lang_19'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'smdx-bossmenu:client:SocetyDeposit',
                    args = currentmoney,
                    iconColor = 'green',
                    arrow = true
                },
                {
                    title = Lang:t('lang_20'),
                    description = Lang:t('lang_21'),
                    icon = 'fa-solid fa-money-bill-transfer',
                    event = 'smdx-bossmenu:client:SocetyWithDraw',
                    args = comma_value(cb),
                    iconColor = 'red',
                    arrow = true
                },
            }
        })
        lib.showContext("society_menu")
    end, PlayerJob.name)
end)

-------------------------------------------------------------------------------------------
-- society deposit
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:SocetyDeposit', function(money)
    local input = lib.inputDialog(Lang:t('lang_22') .. money, {
        { 
            label = Lang:t('lang_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("smdx-bossmenu:server:depositMoney", tonumber(input[1]))
end)

-------------------------------------------------------------------------------------------
-- society withdraw
-------------------------------------------------------------------------------------------
RegisterNetEvent('smdx-bossmenu:client:SocetyWithDraw', function(money)
    local input = lib.inputDialog(Lang:t('lang_22') .. money, {
        { 
            label = Lang:t('lang_23'),
            type = 'number',
            required = true,
            icon = 'fa-solid fa-dollar-sign'
        },
    })
    if not input then return end
    TriggerServerEvent("smdx-bossmenu:server:withdrawMoney", tonumber(input[1]))
end)
