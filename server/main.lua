ESX, hotelRooms, labelTable = nil, {}, {}

TriggerEvent(Config.esxGetter, function(obj)
    ESX = obj
    MySQL.Async.fetchAll("SELECT * FROM hotel_rooms", {}, function(result)
        for k,v in pairs(result) do
            hotelRooms[v.identifier] = {expiration = v.expiration, safe = json.decode(v.safe)}
        end
    end)
    MySQL.Async.fetchAll("SELECT name,label FROM items", {}, function(result)
        for k,v in pairs(result) do
            labelTable[v.name] = v.label
        end
    end)
end)


local function formatExpiration(time)
    local t = os.date("*t", time)
    return t.day.."/"..t.month.."/"..t.year.." à "..t.hour..":"..t.min
end

RegisterNetEvent("hotel:requestMenu")
AddEventHandler("hotel:requestMenu", function()
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier
    local isOwner = hotelRooms[identifier] ~= nil

    if not isOwner then
        TriggerClientEvent("hotel:openMenu", _src, false)
        return
    end

    -- Expiration ?
    local time = os.time()
    local expiration = hotelRooms[identifier].expiration
    if time > expiration then
        MySQL.Async.execute("DELETE FROM hotel_rooms WHERE identifier = @a", {
            ["a"] = identifier
        })
        hotelRooms[identifier] = nil
        TriggerClientEvent("hotel:openMenu", _src, false)
        return
    end

    TriggerClientEvent("hotel:openMenu", _src, true, formatExpiration(hotelRooms[identifier].expiration))
end)

RegisterNetEvent("hotel:rent")
AddEventHandler("hotel:rent", function(qty)
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier

    if hotelRooms[identifier] ~= nil then 
        TriggerClientEvent("hotel:serverCb", _src, "~r~Une erreur est survenue")
        return
    end

    local price = qty * Config.pricePerDay
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price)
    elseif xPlayer.getAccount("bank").money >= price then
        xPlayer.removeAccountMoney("bank", price)
    else
        TriggerClientEvent("hotel:serverCb", _src, "~r~Vous n'avez pas assez d'argent pour payer "..qty.." nuit" .. (qty > 0 and "s" or ""))
        return
    end
    local time = os.time()
    local rentTime = (time+(60*60*24*qty))
    MySQL.Async.insert("INSERT INTO hotel_rooms (identifier,expiration,safe) VALUES(@a,@b,@c)", {
        ["a"] = identifier,
        ["b"] = rentTime,
        ["c"] = json.encode({})
    }, function()
        hotelRooms[identifier] = {expiration = rentTime, safe = {}}
        TriggerClientEvent("hotel:serverCb", _src, "~g~Achat effectué, profitez bien de votre séjour chez ~y~"..Config.name)
    end)
end)

RegisterNetEvent("hotel:exitRoom")
AddEventHandler("hotel:exitRoom", function()
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier

    if hotelRooms[identifier] == nil then
        TriggerClientEvent("hotel:serverCb", _src, nil)
        return
    end
    
    SetPlayerRoutingBucket(_src, 0)
    TriggerClientEvent("hotel:serverCb", _src)
    TriggerClientEvent("hotel:exitRoom", _src)
end)

RegisterNetEvent("hotel:enter")
AddEventHandler("hotel:enter", function()
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier

    if hotelRooms[identifier] == nil then
        TriggerClientEvent("hotel:serverCb", _src)
        return
    end

    SetPlayerRoutingBucket(_src, (Config.instanceRange+_src))
    TriggerClientEvent("hotel:serverCb", _src, nil)
    TriggerClientEvent("hotel:enterRoom", _src)
end)

RegisterNetEvent("hotel:openSafe")
AddEventHandler("hotel:openSafe", function()
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier

    if hotelRooms[identifier] == nil then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Une erreur est survenue")
        return
    end

    local inventory = xPlayer.getInventory(true)
    local playerInventory = {}
    for name, count in pairs(inventory) do
        playerInventory[name] = count
    end
    TriggerClientEvent("hotel:openSafe", _src, playerInventory, hotelRooms[identifier].safe, labelTable)
end)

local function formatPlayerInventory(xPlayer)
    local playerInventory = {}
    for name, count in pairs(xPlayer.getInventory(true)) do
        playerInventory[name] = count
    end
    return playerInventory
end

RegisterNetEvent("hotel:itemRecover")
AddEventHandler("hotel:itemRecover", function(itemName, qty)
    qty = tonumber(qty)
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier
    if hotelRooms[identifier] == nil then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Une erreur est survenue")
        return
    end
    if not hotelRooms[identifier].safe[itemName] or hotelRooms[identifier].safe[itemName] < qty then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Le coffre n'a pas assez d'item de ce type")
        return
    end
    local roomInventory = hotelRooms[identifier].safe
    if (roomInventory[itemName] or 0) - qty <= 0 then
        roomInventory[itemName] = nil
    else
        roomInventory[itemName] = roomInventory[itemName] - qty
    end
    xPlayer.addInventoryItem(itemName, qty)
    hotelRooms[identifier].safe = roomInventory
    MySQL.Async.execute("UPDATE hotel_rooms SET safe = @a WHERE identifier = @b", {
        ["a"] = json.encode(hotelRooms[identifier].safe),
        ["b"] = identifier
    })
    TriggerClientEvent("hotel:updateContent", _src, hotelRooms[identifier].safe)
    TriggerClientEvent("hotel:updatePlayerContent", _src, formatPlayerInventory(xPlayer))
    TriggerClientEvent("hotel:serverCb", _src, "~g~Objet"..(qty > 1 and "s" or "").." retiré"..(qty > 1 and "s" or "").." avec succès")
end)

RegisterNetEvent("hotel:itemDeposit")
AddEventHandler("hotel:itemDeposit", function(itemName, qty)
    qty = tonumber(qty)
    local _src = source
    local xPlayer = ESX.GetPlayerFromId(_src)
    local identifier = xPlayer.identifier

    if hotelRooms[identifier] == nil then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Une erreur est survenue")
        return
    end

    local inventory = formatPlayerInventory(xPlayer)
    local roomInventory = hotelRooms[identifier].safe
    local max = Config.safeMaxQty
    if not inventory[itemName] or inventory[itemName] < qty then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Vous ne pouvez pas déposer autant de "..labelTable[itemName])
        return
    end
    if countItems(roomInventory) + qty > max then
        TriggerClientEvent("hotel:serverCb", _src, "~r~Limite de stockage dépassée")
        return
    end
    xPlayer.removeInventoryItem(itemName, qty)
    if not roomInventory[itemName] then
        roomInventory[itemName] = 0
    end
    roomInventory[itemName] = roomInventory[itemName] + qty
    hotelRooms[identifier].safe = roomInventory
    MySQL.Async.execute("UPDATE hotel_rooms SET safe = @a WHERE identifier = @b", {
        ["a"] = json.encode(hotelRooms[identifier].safe),
        ["b"] = identifier
    })
    TriggerClientEvent("hotel:updateContent", _src, hotelRooms[identifier].safe)
    TriggerClientEvent("hotel:updatePlayerContent", _src, formatPlayerInventory(xPlayer))
    TriggerClientEvent("hotel:serverCb", _src, "~g~Objet"..(qty > 1 and "s" or "").." déposé"..(qty > 1 and "s" or "").." avec succès")
end)

