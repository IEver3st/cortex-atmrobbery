Robbery = Robbery or {}

local function count(source, item)
    local ok, held = pcall(function() return exports.ox_inventory:GetItemCount(source, item) end)
    return ok and tonumber(held) or 0
end

function Robbery.hasTool(source, tool)
    local item = Config.Tools[tool]
    if item == false then return true end
    return count(source, item) > 0
end

function Robbery.toolLabel(tool)
    local item = Config.Tools[tool]
    if not item then return '' end
    local ok, def = pcall(function() return exports.ox_inventory:Items(item) end)
    if ok and type(def) == 'table' and def.label then return def.label end
    return item
end

function Robbery.bundleValue(dyed)
    local value = Config.Reward.perBundle
    if dyed then value = math.floor(value * Config.Reward.dyedShare + 0.5) end
    return math.max(0, value)
end

function Robbery.payBundle(source, dyed)
    local amount = Robbery.bundleValue(dyed)
    if amount <= 0 then return true, 0 end
    local item = Config.Reward.item
    local okCarry, canCarry = pcall(function() return exports.ox_inventory:CanCarryItem(source, item, amount) end)
    if not okCarry or not canCarry then return false, 'carry' end
    local okAdd, added, reason = pcall(function() return exports.ox_inventory:AddItem(source, item, amount) end)
    if not okAdd or reason == 'unknown_outcome' then return false, 'carry', true end
    if not added then return false, 'carry' end
    return true, amount
end
