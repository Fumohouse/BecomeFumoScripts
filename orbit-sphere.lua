local data = {}
local layer_count = 5
local layer_num = 0
local in_layer = 1

function inLayer(x)
    return 6
    --return 1 + layer_count * math.abs(math.sin(x * math.pi / (layer_count - 1)))
end

getgenv().orbitFunction = function(ctx)
    if ctx.PartIndex == 0 then
        data = {}
        layer_num = 0
    end

    if data[layer_num] == in_layer then
        layer_num = layer_num + 1
        in_layer = inLayer(layer_num)
    end

    if not data[layer_num] then
        data[layer_num] = -1
    end

    data[layer_num] = data[layer_num] + 1

    local ang_per_layer_lat = math.pi / layer_count
    local latitude = math.pi / 2 + layer_num * ang_per_layer_lat -- around vert

    local longitude = (ctx.Time + data[layer_num] * 2 * math.pi / in_layer) % (2 * math.pi) -- around horiz

    local colatitude = math.pi / 2 - latitude

    local rad = 1
    local xOff = rad * math.cos(longitude) * math.sin(colatitude)
    local yOff = rad * math.sin(longitude) * math.sin(colatitude)
    local zOff = rad * math.cos(colatitude)

    return ctx.Pivot.Position + Vector3.new(xOff, zOff + 5, yOff)
end