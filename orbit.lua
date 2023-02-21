--[[
    Become Fumo Scripts Orbit Script
    Copyright (c) 2021-2022 voided_etc & contributors
    Licensed under the MIT license. See the LICENSE.txt file at the project root for details.
]]

getgenv().orbitFunction = function(ctx)
    local theta = (ctx.Time + 2 * ctx.PartIndex) * 3

    local r = 2
    local sep = 0.1
    local xOff = r * math.cos(theta)
    local yOff = sep * ctx.PartIndex
    local zOff = r * math.sin(theta)

    local cf = ctx.TargetPart.CFrame * ctx.PartInfo.TotalOffset
    local currentLook = CFrame.lookAt(ctx.PartInfo.Part.Position, cf.Position)

    return ctx.Pivot.Position + Vector3.new(xOff, yOff, zOff), currentLook - currentLook.Position
end

--[[
getgenv().orbitFunction = function(ctx)
    local cf = ctx.TargetPart.CFrame * ctx.PartInfo.TotalOffset

    local d = 3 * math.sin(ctx.Time)
    local look = CFrame.lookAt(cf.Position, ctx.TargetPart.Position)
    local vec = look * Vector3.new(d, 0, 0)

    local currentLook = CFrame.lookAt(ctx.PartInfo.Part.Position, ctx.TargetPart.Position)

    return vec, (cf - cf.Position) * (currentLook - currentLook.Position)
end
]]