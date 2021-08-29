Config = {
    instanceRange = 78456561, -- DO NOT TOUCH
    name = "PablHotel",
    esxGetter = "esx:getSharedObject",
    blip = true,
    position = vector3(-96.11, 6324.78, 31.58),
    pricePerDay = 150,

    safeMaxQty = 10,

    animationGod = true,

    positions = {
        indoorPosition = {pos = vector3(151.4, -1007.41, -99.0), heading = 357.0},
        safePosition = vector3(151.91, -1001.45, -99.0)
    },
}

function countTable(table)
    local i = 0
    for _,_ in pairs(table) do
        i = i + 1
    end
    return i
end

function countItems(content)
    local i = 0
    for item, qty in pairs(content) do
        i = i + qty
    end
    return i
end