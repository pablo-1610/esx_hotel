ESX, isMenuActive, canInteractWithZone, serverInteraction = nil, false, true, false



Citizen.CreateThread(function()
    TriggerEvent(Config.esxGetter, function(obj)
        ESX = obj
    end)

    if Config.blip then
        local blip = AddBlipForCoord(Config.position)
        SetBlipScale(blip, 0.9)
        SetBlipAsShortRange(blip, true)
        SetBlipSprite(blip, 118)
        SetBlipColour(blip, 67)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Hôtel")
        EndTextCommandSetBlipName(blip)
    end

    local position = Config.position
    while true do
        local interval = 250
        local playerPos = GetEntityCoords(PlayerPedId())
        local dst = #(position-playerPos)
        if dst <= 30.0 and canInteractWithZone and not serverInteraction then
            interval = 0
            DrawMarker(22, position, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.45, 0.45, 0.45, 255, 0, 0, 255, 55555, false, true, 2, false, false, false, false)
            if dst <= 1.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu de l'Hotel")
                if IsControlJustPressed(0, 51) then
                    serverInteraction = true
                    TriggerServerEvent("hotel:requestMenu")
                end
            end
        end
        Wait(interval)
    end
end)

-- Menu
local cat = "hotel"

local function customGroupDigits(value)
	local left,num,right = string.match(value,'^([^%d]*%d)(%d*)(.-)$')

	return left..(num:reverse():gsub('(%d%d%d)','%1' .. "."):reverse())..right
end

local function sub(name)
    return cat..name
end

local function showbox(TextEntry, ExampleText, MaxStringLenght, isValueInt)
    AddTextEntry('FMMC_KEY_TIP1', TextEntry)
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", ExampleText, "", "", "", MaxStringLenght)
    local blockinput = true
    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Wait(0)
    end
    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Wait(500)
        blockinput = false
        if isValueInt then
            local isNumber = tonumber(result)
            if isNumber and tonumber(result) > 0 then
                return result
            else
                return nil
            end
        end

        return result
    else
        Wait(500)
        blockinput = false
        return nil
    end
end

local function createMenuPanes()
    local title, desc, descSafe = "Hôtel", "~g~Logements temporaires", "~g~Coffre fort"
    RMenu.Add(cat, sub("main"), RageUI.CreateMenu(title, desc, nil, nil, "pablo", "black"))
    RMenu:Get(cat, sub("main")).Closed = function()
    end

    RMenu.Add(cat, sub("safe"), RageUI.CreateMenu(title, descSafe, nil, nil, "pablo", "black"))
    RMenu:Get(cat, sub("safe")).Closed = function()
    end

    RMenu.Add(cat, sub("safe_deposit"), RageUI.CreateSubMenu(RMenu:Get(cat, sub("safe")), title, descSafe, nil, nil, "pablo", "black"))
    RMenu:Get(cat, sub("safe_deposit")).Closed = function()
    end

    RMenu.Add(cat, sub("rent"), RageUI.CreateSubMenu(RMenu:Get(cat, sub("main")), title, desc, nil, nil, "pablo", "black"))
    RMenu:Get(cat, sub("rent")).Closed = function()
    end
end


Citizen.CreateThread(function()
    createMenuPanes()
end)

RegisterNetEvent("hotel:updateContent")
RegisterNetEvent("hotel:updatePlayerContent")
RegisterNetEvent("hotel:openSafe")
AddEventHandler("hotel:openSafe", function(playerContent, content, labelTable)
    if isMenuActive then return end
    isMenuActive = true
    canInteractWithZone = true
    AddEventHandler("hotel:updateContent", function(newContent)
        content = newContent
    end)
    AddEventHandler("hotel:updatePlayerContent", function(newContent)
        playerContent = newContent
    end)
    FreezeEntityPosition(PlayerPedId(), true)
    RageUI.Visible(RMenu:Get(cat, sub("safe")), true)
    Citizen.CreateThread(function()
        while isMenuActive do
            local shouldStayOpened = false
            local function tick()
                shouldStayOpened = true
            end

            RageUI.IsVisible(RMenu:Get(cat, sub("safe")), true, true, true, function()
                tick()
                RageUI.Separator("Bienvenue au ~b~"..Config.name)
                RageUI.Separator("Contenu: ~y~"..countItems(content).."~s~/~y~"..Config.safeMaxQty)
                RageUI.ButtonWithStyle("Déposer des objects", "Appuyez pour déposer des objets", {RightLabel = "→"}, true, nil, RMenu:Get(cat, sub("safe_deposit")))
                RageUI.Separator("↓ ~g~Contenu ~s~↓")
                if countTable(content) > 0 then
                    for itemName, count in pairs(content) do
                        RageUI.ButtonWithStyle("[~b~x"..count.."~s~] "..labelTable[itemName], "Appuyez pour récupérer cet item", {RightLabel = "Retirer →→"}, not serverInteraction, function(_,_,s)
                            if s then
                                local qty = showbox("Quantité à retirer du coffre", "", 20, true)
                                if qty ~= nil then
                                    serverInteraction = true
                                    TriggerServerEvent("hotel:itemRecover", itemName, qty)
                                else
                                    ESX.ShowNotification("~r~Quantité invalide")
                                end
                            end
                        end)
                    end
                else
                    RageUI.ButtonWithStyle("~r~Le coffre est vide", nil, {}, true)
                end
            end, function()
            end)

            RageUI.IsVisible(RMenu:Get(cat, sub("safe_deposit")), true, true, true, function()
                tick()
                RageUI.Separator("Bienvenue au ~b~"..Config.name)
                RageUI.Separator("Contenu: ~y~"..countItems(content).."~s~/~y~"..Config.safeMaxQty)
                RageUI.Separator("↓ ~g~Votre inventaire ~s~↓")
                if countTable(playerContent) > 0 then
                    for itemName, count in pairs(playerContent) do
                        RageUI.ButtonWithStyle("[~b~x"..count.."~s~] "..labelTable[itemName], "Appuyez pour déposer cet item", {RightLabel = "Déposer →→"}, not serverInteraction, function(_,_,s)
                            if s then
                                local qty = showbox("Quantité à déposer du coffre", "", 20, true)
                                if qty ~= nil then
                                    serverInteraction = true
                                    TriggerServerEvent("hotel:itemDeposit", itemName, qty)
                                else
                                    ESX.ShowNotification("~r~Quantité invalide")
                                end
                            end
                        end)
                    end
                else
                    RageUI.ButtonWithStyle("~r~Le coffre est vide", nil, {}, true)
                end
            end, function()
            end)

            if not shouldStayOpened and isMenuActive then
                FreezeEntityPosition(PlayerPedId(), false)
                isMenuActive = false
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent("hotel:openMenu")
AddEventHandler("hotel:openMenu", function(isOwner, expiration)
    if isMenuActive then return end
    FreezeEntityPosition(PlayerPedId(), true)
    serverInteraction = false
    isMenuActive = true
    RageUI.Visible(RMenu:Get(cat, sub("main")), true)

    Citizen.CreateThread(function()
        local selectedNights = 1
        while isMenuActive do
            local shouldStayOpened = false
            local function tick()
                shouldStayOpened = true
            end

            RageUI.IsVisible(RMenu:Get(cat, sub("main")), true, true, true, function()
                tick()
                RageUI.Separator("Bienvenue au ~b~"..Config.name)
                if isOwner then
                    RageUI.Separator("Expiration: ~y~"..expiration)
                    RageUI.Separator("↓ ~o~Interactions ~s~↓")
                    RageUI.ButtonWithStyle("Entrer dans ma chambre", "Appuyez pour entrer dans votre chambre", {}, not serverInteraction, function(_,_,s)
                        if s then
                            serverInteraction = true
                            shouldStayOpened = false
                            TriggerServerEvent("hotel:enter")
                        end
                    end)
                else
                    RageUI.Separator("Prix d'une nuit: ~g~"..customGroupDigits(Config.pricePerDay).."$~s~")
                    RageUI.Separator("↓ ~o~Interactions ~s~↓")
                    RageUI.ButtonWithStyle("Louer une chambre", "Appuyez pour louer une chambre", {}, not serverInteraction, function(_,_,s)
                    end, RMenu:Get(cat, sub("rent")))
                end
            end, function()
            end)

            RageUI.IsVisible(RMenu:Get(cat, sub("rent")), true, true, true, function()
                tick()
                RageUI.Separator("Bienvenue au ~b~"..Config.name)
                RageUI.Separator("Prix d'une nuit: ~g~"..customGroupDigits(Config.pricePerDay).."$~s~")
                RageUI.Separator("↓ ~r~Paiement ~s~↓")
                RageUI.ButtonWithStyle("Nombre de nuits à louer", nil, {RightLabel = "~o~"..selectedNights.." Nuit".. (selectedNights > 1 and "s" or "") .." ~s~→"}, true, function(_,_,s)
                    if s then
                        local qty = showbox("Nombre de nuits", "", 5, true)
                        if qty ~= nil then
                            qty = tonumber(qty)
                            selectedNights = qty
                        end
                    end
                end)
                RageUI.ButtonWithStyle("Procéder au paiement ~g~"..customGroupDigits(selectedNights * Config.pricePerDay).."$", nil, {RightLabel = "→"}, not serverInteraction, function(_,_,s)
                    if s then
                        serverInteraction = true
                        shouldStayOpened = false
                        TriggerServerEvent("hotel:rent", selectedNights)
                    end
                end)
            end, function()
            end)

            if not shouldStayOpened and isMenuActive then
                FreezeEntityPosition(PlayerPedId(), false)
                isMenuActive = false
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent("hotel:serverCb")
AddEventHandler("hotel:serverCb", function(message)
    serverInteraction = false
    if message ~= nil then ESX.ShowNotification(message) end
end)

RegisterNetEvent("hotel:exitRoom")
AddEventHandler("hotel:exitRoom", function()
    if Config.animationGod then SetEntityInvincible(PlayerPedId(), true) end
    FreezeEntityPosition(PlayerPedId(), true)
    DoScreenFadeOut(2000)
    while not IsScreenFadedOut() do Wait(1) end
    Wait(1200)
    SetEntityCoords(PlayerPedId(), Config.position, false, false, false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    DoScreenFadeIn(750)
    if Config.animationGod then SetEntityInvincible(PlayerPedId(), false) end
    Wait(750)
    canInteractWithZone = true
end)

RegisterNetEvent("hotel:enterRoom")
AddEventHandler("hotel:enterRoom", function()
    canInteractWithZone = false
    if Config.animationGod then SetEntityInvincible(PlayerPedId(), true) end
    FreezeEntityPosition(PlayerPedId(), true)
    DoScreenFadeOut(2000)
    while not IsScreenFadedOut() do Wait(1) end
    Wait(1200)
    SetEntityCoords(PlayerPedId(), Config.positions.indoorPosition.pos, false, false, false, false)
    SetEntityHeading(PlayerPedId(), Config.positions.indoorPosition.heading)
    if Config.animationGod then SetEntityInvincible(PlayerPedId(), false) end
    canInteractWithZone = true
    FreezeEntityPosition(PlayerPedId(), false)
    DoScreenFadeIn(750)
    local position, safe = Config.positions.indoorPosition.pos, Config.positions.safePosition
    
    Citizen.CreateThread(function()
        while true do
            local playerPos = GetEntityCoords(PlayerPedId())

            DrawMarker(22, position, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.45, 0.45, 0.45, 255, 0, 0, 255, 55555, false, true, 2, false, false, false, false)
            DrawMarker(22, safe, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.45, 0.45, 0.45, 255, 128, 0, 255, 55555, false, true, 2, false, false, false, false)

            local dst = #(position-playerPos)
            if dst <= 1.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour sortir de votre chambre")
                if IsControlJustPressed(0, 51) then
                    canInteractWithZone = false
                    TriggerServerEvent("hotel:exitRoom")
                    return
                end
            end

            dst = #(safe-playerPos)
            if dst <= 1.0 then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le coffre de votre chambre")
                if IsControlJustPressed(0, 51) then
                    canInteractWithZone = false
                    TriggerServerEvent("hotel:openSafe")
                end
            end
            Wait(0)
        end
    end)
end)