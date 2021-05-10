ESX = nil
local E_KEY = 38
local LEFTCTRL = 36
local upMarginOfError = 1.5
local downMarginOfError = 0.7
local TOMANY_TRY = 300
local START_DELAY = 11000

local finishCord = nil
local finishBlip = nil
local pPid = PlayerPedId()
local currentRace = nil
local raceStarted = false
local finished = false
local raceOwner = false
local generating = false

AddEventHandler(
    'skinchanger:modelLoaded',
    function()
        pPid = PlayerPedId()
    end
)

function genFinishCord(dist, retryCount)
    generating = true
    local playerPos = GetEntityCoords(pPid)
    local x = math.random(dist * downMarginOfError, dist * upMarginOfError)
    local y = math.random(dist * downMarginOfError, dist * upMarginOfError)
    if math.random(0, 1) == 0 then
        y = y * -1
    end
    if math.random(0, 1) == 0 then
        x = x * -1
    end
    _, finishCord, _ = GetClosestRoad(playerPos.x + x, playerPos.y + y, playerPos.z, 1.0, 1, false)
    local genedDistance = CalculateTravelDistanceBetweenPoints(finishCord, playerPos)
    if (genedDistance < dist * downMarginOfError or genedDistance > dist * upMarginOfError) and genedDistance ~= 100000 then
        Wait(0)
        if retryCount > TOMANY_TRY then
            ESX.ShowNotification('Unable to find a good race path, retry somewhere else or with an other distance')
            return
        end
        return genFinishCord(dist, retryCount + 1)
    else
        generating = false
    end
end

function setBlip(coordinate)
    finishBlip = AddBlipForCoord(coordinate.x, coordinate.y, coordinate.z)

    SetBlipSprite(finishBlip, 38)
    SetBlipDisplay(finishBlip, 4)
    SetBlipScale(finishBlip, 1.0)
    SetBlipColour(finishBlip, 5)
    SetBlipAsShortRange(finishBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Finish Line')
    EndTextCommandSetBlipName(finishBlip)

    SetBlipRoute(finishBlip, true)
end

function playersLocalIdToServerId(closePlayers)
    local closePlayersSID = {}
    for _, player in pairs(closePlayers) do
        table.insert(closePlayersSID, GetPlayerServerId(player))
    end
    return closePlayersSID
end

function createRace(raceType)
    currentRace = GetPlayerName(PlayerId())
    raceOwner = true
    genFinishCord(RacesType[raceType].distance, 0)
    if generating then -- To many tries
        return raceAbort()
    end

    local coords = GetEntityCoords(pPid)
    local closePlayers = ESX.Game.GetPlayersInArea(coords, 10.0)
    TriggerServerEvent('outlaw_races:create', raceType, playersLocalIdToServerId(closePlayers), {name = currentRace, finishCord = finishCord, startPos = coords})
end

function countDown(startTime)
    local timeDiff = 1
    local blipSet = false

    while timeDiff > 0 and not finished do
        timeDiff = startTime - GetNetworkTime()
        if timeDiff <= 1000 then
            if not blipSet then
                setBlip(finishCord)
                blipSet = true
            end
            DrawHudText('GO !', {255, 191, 0, 255}, 0.5, 0.4, 4.0, 4.0)
        else
            DrawHudText(math.floor(timeDiff / 1000), {255, 191, 0, 255}, 0.5, 0.4, 4.0, 4.0)
        end
        Wait(0)
    end
end

function raceStart(startTime)
    raceStarted = true
    finished = false
    local dice = math.random(1, 100)
    local chanceCallCops = 20
    if dice < chanceCallCops then
        TriggerServerEvent('esx_alertpolice:callCops', finishCord, '~r~Signalement:~w~ Course de rue en cours.')
    end
    Citizen.CreateThread(
        function()
            countDown(startTime)
            while not finished do
                Wait(0)
                local coords = GetEntityCoords(pPid)
                DrawMarker(4, finishCord.x, finishCord.y, finishCord.z + 2, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 5.0, 5.0, 5.0, 150, 0, 50, 100, false, true, 2, false, false, false, false)
                if GetDistanceBetweenCoords(coords, finishCord, true) < 12 then
                    TriggerServerEvent('outlaw_races:finished', currentRace)
                    return raceAbort()
                end
            end
        end
    )
end

function raceAbort()
    if (finishBlip ~= nil) then
        RemoveBlip(finishBlip)
        finishBlip = nil
    end
    currentRace = nil
    raceStarted = false
    finished = true
    raceOwner = false
    generating = false
end

RegisterNetEvent('outlaw_races:raceAbort')
AddEventHandler(
    'outlaw_races:raceAbort',
    function()
        raceAbort()
    end
)

RegisterNetEvent('outlaw_races:race_proposal')
AddEventHandler(
    'outlaw_races:race_proposal',
    function(raceType, raceInfo)
        Citizen.CreateThread(
            function()
                local timer = 60 * 100
                local coords = GetEntityCoords(pPid)
                while GetDistanceBetweenCoords(coords, raceInfo.startPos, true) < 20 do
                    coords = GetEntityCoords(pPid)
                    ESX.ShowHelpNotification('~r~Nouvelle course ' .. RacesType[raceType].name .. '~g~ ' .. RacesType[raceType].price .. '$~w~ Appuyez sur ~INPUT_CONTEXT~ pour la rejoindre.')
                    if IsControlPressed(0, E_KEY) then
                        currentRace = raceInfo.name
                        finishCord = raceInfo.finishCord
                        raceOwner = false
                        TriggerServerEvent('outlaw_races:join', raceInfo.name)
                        return
                    end
                    timer = timer - 1
                    if timer <= 0 then
                        return
                    end
                    Wait(10)
                end
            end
        )
    end
)

RegisterNetEvent('outlaw_races:start')
AddEventHandler(
    'outlaw_races:start',
    function(startTime)
        raceStart(startTime)
    end
)

-------- Menu --------

Citizen.CreateThread(
    function()
        while ESX == nil do
            TriggerEvent(
                'esx:getSharedObject',
                function(obj)
                    ESX = obj
                end
            )
            Citizen.Wait(0)
        end
    end
)

exports(
    'openMenu',
    function()
        local elements = {}
        if currentRace == nil then
            for index, race in pairs(RacesType) do
                table.insert(elements, index, {label = 'Course ' .. race.name .. ' ' .. tostring(race.price) .. '$', value = index})
            end
        else
            if raceStarted == true or not raceOwner then
                elements = {
                    {label = 'Abandoner la course', value = -3}
                }
            else
                elements = {
                    {label = 'Supprimer la course', value = -1},
                    {label = 'Démarrer la course', value = -2}
                }
            end
        end
        ESX.UI.Menu.Open(
            'default',
            GetCurrentResourceName(),
            'open_menu',
            {
                title = 'Choisis la course',
                elements = elements
            },
            function(data, menu)
                menu.close()
                local value = data.current.value
                if value > 0 then
                    createRace(value)
                elseif generating then
                    ESX.ShowNotification('Race is currently generating wait...')
                elseif value == -1 then
                    TriggerServerEvent('outlaw_races:delete', currentRace)
                elseif value == -2 then
                    TriggerServerEvent('outlaw_races:init', currentRace, GetNetworkTime() + START_DELAY)
                elseif value == -3 then
                    TriggerServerEvent('outlaw_races:leave', currentRace)
                    raceAbort()
                end
            end,
            function(data, menu)
                menu.close()
            end
        )
    end
)

--[[Check for menu keys
Citizen.CreateThread(
    function()
        while true do
            if IsPedInAnyVehicle(pPid) then
                if IsControlPressed(2, LEFTCTRL) and IsControlPressed(0, E_KEY) then
                    openMenu()
                    Wait(1000)
                end
            end
            Wait(100)
        end
    end
)]]

function DrawHudText(text, colour, coordsx, coordsy, scalex, scaley) --courtesy of driftcounter
    local colourr, colourg, colourb, coloura = table.unpack(colour)
    SetTextFont(7)
    SetTextProportional(7)
    SetTextScale(scalex, scaley)
    SetTextColour(colourr, colourg, colourb, coloura)
    SetTextDropshadow(0, 0, 0, 0, coloura)
    SetTextEdge(1, 0, 0, 0, coloura)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(coordsx, coordsy)
end
