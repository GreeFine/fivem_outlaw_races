ESX = nil
local Races = {}

TriggerEvent(
    'esx:getSharedObject',
    function(obj)
        ESX = obj
    end
)

function proposeToClosePlayers(owner, closePlayers, raceType, raceDetails)
    for _, player in pairs(closePlayers) do
        if player ~= owner then
            TriggerClientEvent('outlaw_races:race_proposal', player, raceType, raceDetails)
        end
    end
end

-- Citizen.CreateThread(
--     function()
--         Races['GreeFine'] = {
--             players = {10},
--             price = 500,
--             reward = 0,
--             finished = false,
--             started = false
--             owner = _source
--         }
--         Citizen.Wait(1000)
--         proposeToClosePlayers(10, {1}, 1, {name = 'GreeFine', startPos = vector3(-2349.284, 303.7098, 168.959), finishCord = vector3(-2341.658, 284.2644, 168.9595)})
--         Citizen.Wait(5000)
--         TriggerEvent('outlaw_races:init', 'GreeFine')
--         Citizen.Wait(2000)
--         removePlayer(Races['GreeFine'].players, 10)
--         isRaceEmpty('GreeFine')
--     end
-- )

RegisterServerEvent('outlaw_races:create')
AddEventHandler(
    'outlaw_races:create',
    function(raceType, closePlayers, raceDetails)
        local _source = source
        local xPlayer = ESX.GetPlayerFromId(_source)
        local sourceName = GetPlayerName(_source)
        if Races[sourceName] == nil then
            if xPlayer.getAccount('black_money').money > RacesType[raceType].price then
                xPlayer.removeAccountMoney('black_money', RacesType[raceType].price)
                TriggerClientEvent('esx:showNotification', _source, 'Votre ~y~course~w~ a ete créée')
                Races[sourceName] = {
                    players = {_source},
                    price = RacesType[raceType].price,
                    reward = RacesType[raceType].price,
                    finished = false,
                    started = false,
                    owner = _source
                }
                proposeToClosePlayers(_source, closePlayers, raceType, raceDetails)
            else
                TriggerClientEvent('esx:showNotification', _source, "Vous n'avez pas assez ~r~d\'argent~w~ pour créer cette ~y~course")
                TriggerClientEvent('outlaw_races:raceAbort', _source)
            end
        else
            TriggerClientEvent('esx:showNotification', _source, '~r~Une course à votre nom est déjà en cours')
        end
    end
)

RegisterServerEvent('outlaw_races:delete')
AddEventHandler(
    'outlaw_races:delete',
    function(raceName)
        local _source = source

        if Races[raceName] ~= nil then
            local players = Races[raceName].players
            for player, _ in pairs(players) do
                TriggerClientEvent('outlaw_races:raceAbort', player)
                TriggerClientEvent('esx:showNotification', player, '~r~La course a été annulée')
            end
            for _, player in pairs(players) do
                local xPlayer = ESX.GetPlayerFromId(player)
                xPlayer.addAccountMoney('black_money', Races[raceName].price)
            end
            Races[raceName] = nil
        else
            TriggerClientEvent('esx:showNotification', _source, "~r~ERROR: vous n'avez pas de course existante")
        end
    end
)

RegisterServerEvent('outlaw_races:join')
AddEventHandler(
    'outlaw_races:join',
    function(raceName)
        local _source = source
        local xPlayer = ESX.GetPlayerFromId(_source)

        if Races[raceName] == nil then
            TriggerClientEvent('esx:showNotification', _source, "~r~ERROR: cette course n'exist pas: " .. raceName)
        else
            if Races[raceName].started then
                TriggerClientEvent('esx:showNotification', _source, 'La ~y~course~w~ a deja commence')
            end
            if xPlayer.getAccount('black_money').money > Races[raceName].price then
                xPlayer.removeAccountMoney('black_money', Races[raceName].price)
                table.insert(Races[raceName].players, _source)
                Races[raceName].reward = Races[raceName].reward + Races[raceName].price
                TriggerClientEvent('esx:showNotification', _source, 'Vous avez rejoins la ~y~course~w~ de ' .. raceName)
                TriggerClientEvent('esx:showNotification', Races[raceName].owner, '~b~' .. GetPlayerName(_source) .. '~w~ a rejoint votre ~y~course')
            else
                TriggerClientEvent('esx:showNotification', _source, "Vous n'avez pas assez ~r~d\'argent~w~ pour rejoindre la ~y~course")
            end
        end
    end
)

RegisterServerEvent('outlaw_races:init')
AddEventHandler(
    'outlaw_races:init',
    function(raceName, startTime)
        local players = Races[raceName].players
        Races[raceName].started = true
        for _, player in pairs(players) do
            print('Starting for player:', player, GetPlayerName(player))
            TriggerClientEvent('outlaw_races:start', player, startTime)
        end
    end
)

function isRaceEmpty(raceName)
    local players = Races[raceName].players
    if #players == 0 then
        Races[raceName] = nil
    end
end

function removePlayer(table, player)
    for index, value in pairs(table) do
        if value == player then
            table[index] = nil
            return
        end
    end
end

RegisterServerEvent('outlaw_races:leave')
AddEventHandler(
    'outlaw_races:leave',
    function(raceName)
        local _source = source
        removePlayer(Races[raceName].players, _source)
        isRaceEmpty(raceName)
    end
)

RegisterServerEvent('outlaw_races:finished')
AddEventHandler(
    'outlaw_races:finished',
    function(raceName)
        local _source = source
        local reward = Races[raceName].reward

        if Races[raceName].finished then
            TriggerClientEvent('esx:showNotification', _source, "~r~Vous avez perdu!")
        else
            Races[raceName].finished = true

            local xPlayer = ESX.GetPlayerFromId(_source)
            xPlayer.addAccountMoney('black_money', reward)
            TriggerClientEvent('esx:showNotification', _source, 'Vous avez remporté la ~y~course~w~! Argent gagné~g~' .. reward .. '~w~$')
        end
        removePlayer(Races[raceName].players, _source)
        isRaceEmpty(raceName)
    end
)
