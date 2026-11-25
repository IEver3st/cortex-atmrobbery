Tools = {}

local T = CxAtmRob.Tools or {}
local ws = lib.worldScreen

local held = {}
local lcd = { page = nil, swap = nil }

local function quat(X, Y, Z)
    local m00, m01, m02 = X.x, Y.x, Z.x
    local m10, m11, m12 = X.y, Y.y, Z.y
    local m20, m21, m22 = X.z, Y.z, Z.z
    local trace = m00 + m11 + m22
    if trace > 0 then
        local s = 0.5 / math.sqrt(trace + 1.0)
        return (m21 - m12) * s, (m02 - m20) * s, (m10 - m01) * s, 0.25 / s
    elseif m00 > m11 and m00 > m22 then
        local s = 2.0 * math.sqrt(1.0 + m00 - m11 - m22)
        return 0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s
    elseif m11 > m22 then
        local s = 2.0 * math.sqrt(1.0 + m11 - m00 - m22)
        return (m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s
    end
    local s = 2.0 * math.sqrt(1.0 + m22 - m00 - m11)
    return (m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s
end

function Tools.basis(z, hint, spin)
    z = Geo.norm(z)
    local x = Geo.cross(hint, z)
    if #x < 1e-4 then x = Geo.cross(vector3(0.0, 0.0, 1.0), z) end
    x = Geo.norm(x)
    local y = Geo.cross(z, x)
    if spin and spin ~= 0.0 then
        local a = math.rad(spin)
        local c, s = math.cos(a), math.sin(a)
        x, y = x * c + y * s, y * c - x * s
    end
    return x, y, z
end

local function model(name, variant)
    local def = T[name]
    if not def then return nil end
    if variant == 'closed' and def.closed then return def.closed end
    return def.model
end

local function object(slot, name, variant)
    local want = model(name, variant)
    local h = held[slot]
    if h and h.model == want and DoesEntityExist(h.obj) then return h.obj end
    if want and Rob.ready(want) == false then return h and DoesEntityExist(h.obj) and h.obj or nil end
    if h then Rob.delete(h.obj) end
    held[slot] = nil
    if not want or not Rob.ready(want) then return nil end
    local v = Geo.view
    local obj = Rob.spawn(want, v and v.pos or GetEntityCoords(PlayerPedId()))
    if not obj then return nil end
    SetEntityLodDist(obj, 60)
    held[slot] = { obj = obj, model = want }
    return obj
end

function Tools.hold(slot, name, tip, dir, spin, variant)
    local obj = object(slot, name, variant)
    if not obj then return nil end
    local v = Geo.view
    local hint = v and v.up or vector3(0.0, 0.0, 1.0)
    local x, y, z = Tools.basis(dir, hint, spin)
    SetEntityCoordsNoOffset(obj, tip.x, tip.y, tip.z, false, false, false)
    local qx, qy, qz, qw = quat(x, y, z)
    SetEntityQuaternion(obj, qx, qy, qz, qw)
    return obj
end

function Tools.drop(slot)
    local h = held[slot]
    if not h then return end
    Rob.delete(h.obj)
    held[slot] = nil
end

function Tools.dropAll()
    for slot in pairs(held) do Tools.drop(slot) end
end

function Tools.handDir(tip, side, lift)
    local v = Geo.view
    if not v then return vector3(0.0, -1.0, 0.0) end
    local hand = v.pos + v.right * (side or 0.16) - v.up * (lift or 0.16) - v.forward * 0.02
    return Geo.norm(hand - tip)
end

function Tools.length(name)
    local def = T[name]
    return def and def.length or 0.2
end

local function lcdPage()
    if lcd.page then return lcd.page end
    local meter = T.meter
    if not meter or not meter.lcd then return nil end
    local ok, page = pcall(ws.page, { url = ('nui://%s/web/lcd/index.html'):format(Rob.resource), width = 512, height = 256, txd = 'cx_atmrob_lcd_rt' })
    if not ok or not page then return nil end
    lcd.page = page
    local fine, swap = pcall(ws.replace, { model = meter.model, dict = meter.lcd.dict, name = meter.lcd.name, page = page })
    if fine then lcd.swap = swap end
    return page
end

function Tools.lcd(msg)
    local page = lcdPage()
    if page then pcall(page.send, page, msg) end
end

function Tools.meter(on)
    if not on then
        Tools.drop('meter')
        return
    end
    local v = Geo.view
    local meter = T.meter
    if not v or not meter then return end
    lcdPage()
    local obj = object('meter', 'meter')
    if not obj then return end
    local at = v.pos + v.forward * 0.30 - v.right * 0.135 - v.up * 0.092
    local facing = Geo.norm(v.pos - at)
    local z = facing
    local tilt = Geo.norm(v.up + v.right * 0.18)
    local y = Geo.norm(tilt - z * Geo.dot(tilt, z))
    local x = Geo.cross(y, z)
    SetEntityCoordsNoOffset(obj, at.x, at.y, at.z, false, false, false)
    local qx, qy, qz, qw = quat(x, y, z)
    SetEntityQuaternion(obj, qx, qy, qz, qw)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    for _, h in pairs(held) do pcall(Rob.delete, h.obj) end
    if lcd.swap and lcd.swap.release then pcall(lcd.swap.release, lcd.swap) end
end)
