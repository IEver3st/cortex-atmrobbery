World = { recs = {} }

local R = CxAtmRob.Bay
local NEAR_TWIN, FAR_TWIN = 140.0, 170.0
local NEAR_KIT, FAR_KIT = 45.0, 60.0
local HIDE_RADIUS = 0.3
local DOOR_FALL_MS, PLATE_FALL_MS, SLIDE_MS = 760, 640, 520
local SCREW_OUT = 0.007

local recs = World.recs

local function rig(name)
    return R and R[name]
end

local function now() return GetGameTimer() end

local function seeded(id, salt)
    local x = math.sin(id * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)
end

local function frames(rec)
    local def = CxAtmRob.Machines[rec.snap.model]
    rec.def = def
    rec.base = Geo.frame(rec.snap.coords, rec.snap.rot)
    rec.bay = Geo.frame(rec.snap.coords, rec.snap.rot, def.bay)
end

function World.point(rec, x, y, z)
    return Geo.toWorld(rec.bay, x, y, z)
end

function World.normal(rec)
    return -rec.bay.forward
end

local function attach(rec, obj, x, y, z, rx, ry, rz)
    if not obj or not rec.twin then return end
    local b = rec.def.bay
    AttachEntityToEntity(obj, rec.twin, -1, b.x + x, b.y + y, b.z + z, (rx or 0.0) + 0.0, (ry or 0.0) + 0.0, (rz or 0.0) + 0.0,
        false, false, false, false, 2, true)
end

local function floorZ(rec)
    if rec.floor then return rec.floor end
    local probe = World.point(rec, 0.0, -0.45, 0.0)
    local found, z = GetGroundZFor_3dCoord(probe.x, probe.y, probe.z + 0.6, false)
    local local0 = rec.base.base.z
    if found and math.abs(z - local0) < 1.5 then
        rec.floor = z - local0 - rec.def.bay.z
    else
        rec.floor = -rec.def.bay.z
    end
    return rec.floor
end

local function outOfService(rec, on)
    pcall(function() exports['cortex-banking']:SetMachineOutOfService('atmrob:' .. rec.id, on and rec.snap.coords or nil) end)
end

local function hide(rec)
    if rec.hidden then return end
    local c = rec.snap.coords
    CreateModelHide(c.x + 0.0, c.y + 0.0, c.z + 0.0, HIDE_RADIUS, rec.def.hash, true)
    CreateModelHide(c.x + 0.0, c.y + 0.0, c.z + 0.0, HIDE_RADIUS, joaat(rec.def.vanilla), true)
    rec.hidden = true
    outOfService(rec, true)
end

local function unhide(rec)
    if not rec.hidden then return end
    local c = rec.snap.coords
    RemoveModelHide(c.x + 0.0, c.y + 0.0, c.z + 0.0, HIDE_RADIUS, rec.def.hash, false)
    RemoveModelHide(c.x + 0.0, c.y + 0.0, c.z + 0.0, HIDE_RADIUS, joaat(rec.def.vanilla), false)
    rec.hidden = false
    outOfService(rec, false)
end

AddEventHandler('onClientResourceStart', function(name)
    if name ~= 'cortex-banking' then return end
    SetTimeout(1000, function()
        for _, rec in pairs(recs) do
            if rec.hidden then outOfService(rec, true) end
        end
    end)
end)

local function makeTwin(rec)
    if rec.twin then return true end
    local hash = Rob.model(rec.def.open)
    if not hash or recs[rec.id] ~= rec or rec.twin then return rec.twin ~= nil end
    local c, r = rec.snap.coords, rec.snap.rot
    local obj = CreateObjectNoOffset(hash, c.x + 0.0, c.y + 0.0, c.z + 0.0, false, false, false)
    if obj == 0 then return false end
    SetEntityRotation(obj, r.x + 0.0, r.y + 0.0, r.z + 0.0, 2, false)
    SetEntityCoordsNoOffset(obj, c.x + 0.0, c.y + 0.0, c.z + 0.0, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityInvincible(obj, true)
    rec.twin = obj
    return true
end

local function part(rec, key, model)
    local kit = rec.kit
    local held = kit[key]
    if held and held.model == model and DoesEntityExist(held.obj) then return held.obj end
    local ready = Rob.ready(model)
    if ready == false then
        rec.waiting = true
        World.wake()
        return held and DoesEntityExist(held.obj) and held.obj or nil
    end
    if held then Rob.delete(held.obj) end
    kit[key] = nil
    if not ready then return nil end
    local obj = Rob.spawn(model, World.point(rec, 0.0, 0.0, 0.0))
    if not obj then return nil end
    kit[key] = { obj = obj, model = model }
    return obj
end

local function drop(rec, key)
    local held = rec.kit[key]
    if not held then return end
    Rob.delete(held.obj)
    rec.kit[key] = nil
end

local function doorOff(s)
    for i = 1, CxAtmRob.PryPoints do
        if not s.pry[i] then return false end
    end
    return true
end

local function plateOff(s)
    for i = 1, CxAtmRob.ScrewCount do
        if not s.screws[i] then return false end
    end
    return true
end

local function doorFloor(rec)
    local f = floorZ(rec)
    local jx = (seeded(rec.id, 1) - 0.5) * 0.12
    local jr = (seeded(rec.id, 2) - 0.5) * 40.0
    return 0.18 + jx, -0.42, f + 0.003, -90.0, 0.0, 12.0 + jr
end

local function plateFloor(rec)
    local f = floorZ(rec)
    local jx = (seeded(rec.id, 3) - 0.5) * 0.10
    local jr = (seeded(rec.id, 4) - 0.5) * 30.0
    return -0.22 + jx, -0.30, f + 0.002, -90.0, 0.0, -18.0 + jr
end

local function doorBent(rec)
    local s, l = rec.snap, rec.lever
    local hinge = (rig('door') and rig('door').w or 0.474) * 0.5
    local yaw = 0.0
    local pitch = 0.0
    if s.pry[1] then yaw = yaw + 2.2 end
    if s.pry[2] then yaw = yaw + 2.2 end
    if s.pry[3] then pitch = pitch + 2.6 end
    if l and l.point then
        if l.point == 3 then pitch = pitch + l.value * 3.4 else yaw = yaw + l.value * 3.0 end
    end
    local a, b = math.rad(-yaw), math.rad(pitch)
    local x = -hinge + hinge * math.cos(a)
    local y = -0.002 + hinge * math.sin(a)
    local halfH = (rig('door') and rig('door').h or 0.204) * 0.5
    y = y - halfH * math.sin(b)
    local z = -halfH + halfH * math.cos(b)
    return x, y, z, pitch, 0.0, -yaw
end

local function animate(rec, key, ms, from, to, arc, done)
    rec.anims[key] = { started = now(), ms = ms, from = from, to = to, arc = arc or 0.0, done = done }
    World.wake()
end

local function poseOf(anim)
    local t = Geo.clamp((now() - anim.started) / anim.ms, 0.0, 1.0)
    local k = Geo.ease(t)
    local out = {}
    for i = 1, 6 do out[i] = Geo.lerp(anim.from[i], anim.to[i], i <= 3 and (i == 3 and t * t or k) or k) end
    out[2] = out[2] - math.sin(t * math.pi) * anim.arc
    return out, t >= 1.0
end

local function placeDoor(rec)
    local s = rec.snap
    local model = rig('door') and rig('door').model or 'cx_atmrob_door'
    local obj = part(rec, 'door', model)
    if not obj then return end
    local anim = rec.anims.door
    if anim then
        local p, finished = poseOf(anim)
        attach(rec, obj, p[1], p[2], p[3], p[4], p[5], p[6])
        if finished then
            rec.anims.door = nil
            if anim.done then anim.done() end
        end
        return
    end
    if not doorOff(s) then
        attach(rec, obj, doorBent(rec))
    else
        attach(rec, obj, doorFloor(rec))
    end
end

local function placePlate(rec)
    local s = rec.snap
    local plate = rig('plate')
    local obj = part(rec, 'plate', plate and plate.model or 'cx_atmrob_plate')
    if not obj then return end
    local anim = rec.anims.plate
    if anim then
        local p, finished = poseOf(anim)
        attach(rec, obj, p[1], p[2], p[3], p[4], p[5], p[6])
        if finished then
            rec.anims.plate = nil
            if anim.done then anim.done() end
        end
        return
    end
    if not plateOff(s) then
        attach(rec, obj, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    else
        attach(rec, obj, plateFloor(rec))
    end
end

local function placeScrews(rec)
    local s = rec.snap
    local plate = rig('plate')
    local screwModel = rig('screw') and rig('screw').model or 'cx_atmrob_screw'
    local y0 = plate and plate.y or 0.010
    local onPlate = not plateOff(s)
    for i = 1, CxAtmRob.ScrewCount do
        local key = 'screw' .. i
        local at = plate and plate.screws and plate.screws[i]
        local falling = rec.anims[key]
        if not at and falling then rec.anims[key] = nil end
        if at and (falling or (onPlate and not s.screws[i])) then
            local obj = part(rec, key, screwModel)
            if not obj and falling and now() - falling.started > falling.ms then rec.anims[key] = nil end
            if obj then
                if falling then
                    local p, finished = poseOf(falling)
                    attach(rec, obj, p[1], p[2], p[3], p[4], p[5], p[6])
                    if finished then
                        rec.anims[key] = nil
                        drop(rec, key)
                    end
                else
                    local turns = (rec.turn and rec.turn.screw == i and rec.turn.turns) or (rec.progress and rec.progress[i]) or 0.0
                    local progress = Geo.clamp(turns / Config.Screws.turns, 0.0, 1.0)
                    local spin = -turns * 360.0
                    attach(rec, obj, at.x, y0 - progress * SCREW_OUT, at.z, 0.0, spin % 360.0, 0.0)
                end
            end
        else
            drop(rec, key)
        end
    end
end

local function placeCore(rec)
    local core = rig('core')
    local obj = part(rec, 'core', core and core.model or 'cx_atmrob_core')
    if obj then attach(rec, obj, 0.0, 0.0, 0.0) end
end

local function placeWires(rec)
    local s = rec.snap
    local wires = rig('wires') or {}
    for i = 1, CxAtmRob.WireCount do
        local w = wires[i]
        if w then
            local obj = part(rec, 'wire' .. i, s.cut[i] and w.cut or w.model)
            if obj then attach(rec, obj, 0.0, 0.0, 0.0) end
        end
    end
end

local function placeJumpers(rec)
    local s = rec.snap
    local jumper = rig('jumper')
    local left = rig('terminals') and rig('terminals').left
    local wanted = {}
    for index, pair in ipairs(s.jumpers) do
        local a, b = math.min(pair[1], pair[2]), math.max(pair[1], pair[2])
        local model = jumper and jumper.models and jumper.models[b - a]
        local at = left and left[a]
        if model and at then
            local key = 'jumper' .. index
            wanted[key] = true
            local obj = part(rec, key, model)
            if obj then attach(rec, obj, at.x, at.y, at.z) end
        end
    end
    for key in pairs(rec.kit) do
        if key:sub(1, 6) == 'jumper' and not wanted[key] then drop(rec, key) end
    end
end

local function placeBolt(rec)
    local s = rec.snap
    local bolt = rig('bolt')
    local obj = part(rec, 'bolt', bolt and bolt.model or 'cx_atmrob_bolt')
    if not obj then return end
    local lift = 0.0
    local anim = rec.anims.bolt
    if anim then
        local t = Geo.clamp((now() - anim.started) / anim.ms, 0.0, 1.0)
        lift = (bolt and bolt.travel or 0.016) * (t < 0.6 and t / 0.6 * 1.15 or 1.15 - (t - 0.6) / 0.4 * 0.15)
        if t >= 1.0 then rec.anims.bolt = nil end
    elseif s.bolt then
        lift = bolt and bolt.travel or 0.016
    end
    attach(rec, obj, 0.0, 0.0, lift)
end

local function placeLamp(rec)
    local s = rec.snap
    local lamp = rig('lamp')
    if not lamp then return end
    local want
    if s.stage ~= 'dead' and not s.unpowered then
        if Fx.alarmOn(rec.id) then
            want = (now() // 260) % 2 == 0 and lamp.red or nil
        else
            want = s.bolt and lamp.green or lamp.red
        end
    end
    if not want then
        drop(rec, 'lamp')
        return
    end
    local obj = part(rec, 'lamp', want)
    if obj then attach(rec, obj, 0.0, 0.0, 0.0) end
end

local function cassetteSlide(rec)
    local c = rig('cassette')
    local travel = c and c.travel or 0.150
    local anim = rec.anims.drawer
    if anim then
        local t = Geo.clamp((now() - anim.started) / anim.ms, 0.0, 1.0)
        if t >= 1.0 then rec.anims.drawer = nil end
        return -travel * Geo.ease(t)
    end
    local pull = rec.pull
    if pull then return -travel * Geo.clamp(pull, 0.0, 1.0) end
    return rec.snap.drawer and -travel or 0.0
end

local function placeCassette(rec)
    local s = rec.snap
    local c = rig('cassette')
    if not c then return end
    local slide = cassetteSlide(rec)
    rec.slide = slide
    local obj = part(rec, 'cassette', c.model)
    if obj then attach(rec, obj, 0.0, slide, 0.0) end
    local bundle = c.bundle
    for i = 1, CxAtmRob.SlotCount do
        local key = 'bundle' .. i
        local at = c.slots and c.slots[i]
        local lifted = rec.lifted and rec.lifted.slot == i and rec.lifted or nil
        if at and bundle and (s.slots[i] or lifted) then
            local b = part(rec, key, s.dye and bundle.dyed or bundle.model)
            if b then
                if lifted then
                    local t = Geo.clamp((now() - lifted.started) / 420, 0.0, 1.0)
                    local k = Geo.ease(t)
                    attach(rec, b, at.x * (1.0 - k), at.y + slide - k * 0.20, at.z + k * 0.09, -k * 35.0, 0.0, k * 12.0)
                    if t >= 1.0 and not s.slots[i] then
                        rec.lifted = nil
                        drop(rec, key)
                    end
                else
                    attach(rec, b, at.x, at.y + slide, at.z)
                end
            end
        else
            drop(rec, key)
        end
    end
end

local function clearKit(rec)
    for key in pairs(rec.kit) do drop(rec, key) end
    rec.kit = {}
    rec.anims = {}
end

local function placeAll(rec)
    if not rec.twin then return end
    local was = rec.waiting
    rec.waiting = false
    placeDoor(rec)
    placePlate(rec)
    placeScrews(rec)
    placeCore(rec)
    placeWires(rec)
    placeJumpers(rec)
    placeBolt(rec)
    placeLamp(rec)
    placeCassette(rec)
    if rec.waiting and not was then rec.waitSince = now() end
end

World.placeAll = placeAll

local function busy(rec)
    if rec.waiting and now() - (rec.waitSince or 0) < 10000 then return true end
    return next(rec.anims) ~= nil or rec.lever ~= nil or rec.turn ~= nil or rec.pull ~= nil or rec.lifted ~= nil
        or Fx.alarmOn(rec.id) or (Rob.session and Rob.session.id == rec.id)
end

local animating = false
function World.wake()
    if animating then return end
    animating = true
    CreateThread(function()
        while true do
            local any = false
            for _, rec in pairs(recs) do
                if rec.kitOn and busy(rec) then
                    any = true
                    placeAll(rec)
                end
            end
            if not any then break end
            Wait(0)
        end
        animating = false
    end)
end

local function transitions(rec, old, new)
    if not rec.kitOn or not old then return end
    if not doorOff(old) and doorOff(new) then
        local x, y, z, rx, ry, rz = doorBent(rec)
        local fx, fy, fz, frx, fry, frz = doorFloor(rec)
        animate(rec, 'door', DOOR_FALL_MS, { x, y, z, rx, ry, rz }, { fx, fy, fz, frx, fry, frz }, 0.10, function()
            Fx.sound('clang', World.point(rec, fx, fy, fz))
        end)
        Fx.sound('pop', World.point(rec, 0.0, 0.0, 0.0))
    end
    if not plateOff(old) and plateOff(new) then
        local fx, fy, fz, frx, fry, frz = plateFloor(rec)
        animate(rec, 'plate', PLATE_FALL_MS, { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }, { fx, fy, fz, frx, fry, frz }, 0.06, function()
            Fx.sound('plate', World.point(rec, fx, fy, fz))
        end)
    end
    local plate = rig('plate')
    for i = 1, CxAtmRob.ScrewCount do
        if not old.screws[i] and new.screws[i] and plate and plate.screws and plate.screws[i] then
            local at = plate.screws[i]
            local y0 = (plate.y or 0.010) - SCREW_OUT
            local f = floorZ(rec)
            animate(rec, 'screw' .. i, 520, { at.x, y0, at.z, 0.0, 0.0, 0.0 }, { at.x * 0.8, -0.18, f + 0.003, 90.0, 0.0, seeded(rec.id, 10 + i) * 360.0 }, 0.05)
            Fx.sound('screwOut', World.point(rec, at.x, y0, at.z))
        end
    end
    if not old.bolt and new.bolt then
        rec.anims.bolt = { started = now(), ms = 380 }
        World.wake()
        Fx.sound('bolt', World.point(rec, 0.16, 0.03, 0.0))
    end
    if not old.drawer and new.drawer and not rec.pull then
        rec.anims.drawer = { started = now(), ms = SLIDE_MS }
        World.wake()
        Fx.sound('drawer', World.point(rec, 0.0, -0.1, -0.06))
    end
    if new.drawer then rec.pull = nil end
    for i = 1, CxAtmRob.SlotCount do
        if old.slots[i] and not new.slots[i] and not (rec.lifted and rec.lifted.slot == i) then
            rec.lifted = { slot = i, started = now() }
            World.wake()
        end
    end
end

local function kitOn(rec)
    if rec.kitOn then return end
    if not rec.twin then return end
    rec.kitOn = true
    placeAll(rec)
    World.wake()
end

local function kitOff(rec)
    if not rec.kitOn then return end
    rec.kitOn = false
    clearKit(rec)
end

local function twinOff(rec)
    kitOff(rec)
    if rec.twin then
        Rob.delete(rec.twin)
        rec.twin = nil
    end
end

local function stream(rec, pos)
    local d = #(pos - rec.base.base)
    if d < NEAR_TWIN then
        hide(rec)
        if not rec.twin and not rec.making then
            rec.making = true
            CreateThread(function()
                makeTwin(rec)
                rec.making = false
                if rec.twin and #(GetEntityCoords(PlayerPedId()) - rec.base.base) < NEAR_KIT then kitOn(rec) end
            end)
        end
    elseif d > FAR_TWIN then
        twinOff(rec)
    end
    if rec.twin then
        if d < NEAR_KIT then kitOn(rec) elseif d > FAR_KIT then kitOff(rec) end
    end
end

function World.apply(id, snap)
    local rec = recs[id]
    if not snap then
        if rec then
            twinOff(rec)
            unhide(rec)
            Fx.forget(id)
            recs[id] = nil
            if Session and Session.removed then Session.removed(id) end
        end
        return
    end
    if not CxAtmRob.Machines[snap.model] then return end
    local old = rec and rec.snap
    if not rec then
        rec = { id = id, kit = {}, anims = {}, hidden = false }
        recs[id] = rec
    end
    rec.snap = snap
    if not old then frames(rec) end
    Fx.alarm(id, rec.base.base, tonumber(snap.alarmLeft) or 0)
    stream(rec, GetEntityCoords(PlayerPedId()))
    transitions(rec, old, snap)
    if rec.kitOn then placeAll(rec) end
    if Fx.alarmOn(id) then World.wake() end
    if Session and Session.updated then Session.updated(rec, old) end
end

function World.find(coords)
    for _, rec in pairs(recs) do
        if #(rec.base.base - coords) < 0.5 then return rec end
    end
    return nil
end

function World.get(id) return recs[id] end

function World.kitObject(rec, key)
    local held = rec.kit[key]
    return held and held.obj or nil
end

RegisterNetEvent('cortex-atmrobbery:client:machine', function(id, snap)
    if type(id) ~= 'number' then return end
    World.apply(id, type(snap) == 'table' and snap or nil)
end)

RegisterNetEvent('cortex-atmrobbery:client:all', function(list)
    if type(list) ~= 'table' then return end
    local seen = {}
    for _, snap in ipairs(list) do
        if type(snap) == 'table' and type(snap.id) == 'number' then
            seen[snap.id] = true
            World.apply(snap.id, snap)
        end
    end
    for id in pairs(recs) do
        if not seen[id] then World.apply(id, nil) end
    end
end)

local SYNC_MS = 10000
local syncedAt = 0

local function sync()
    syncedAt = GetGameTimer()
    TriggerServerEvent('cortex-atmrobbery:server:sync')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(1500, sync) end)

CreateThread(function()
    Wait(1500)
    sync()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, rec in pairs(recs) do stream(rec, pos) end
        if GetGameTimer() - syncedAt > SYNC_MS then sync() end
        Wait(next(recs) and 1000 or 2500)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    for _, rec in pairs(recs) do
        pcall(twinOff, rec)
        pcall(unhide, rec)
    end
end)
