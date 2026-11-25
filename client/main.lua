local PROMPT = 'atmrob'
local REACH = 1.3
local SCAN_MS, NEAR_MS = 700, 250

local near
local promptKey

local function startKey()
    local raw = GetControlInstructionalButton(0, joaat('+cortexatmrob_start') | 0x80000000, true)
    if type(raw) == 'string' and raw:sub(1, 2) == 't_' then return raw:sub(3) end
    return Config.Keys.start
end

local function crowbarOut()
    local item = Config.Tools.crowbar
    if item == false then return true end
    return GetSelectedPedWeapon(PlayerPedId()) == joaat(item)
end

local function inFront(pos, f)
    local d = pos - f.at
    return Geo.dot(d, f.forward) < 0.15
end

local function candidate(pos)
    local best, bestD
    for _, rec in pairs(World.recs) do
        local at = World.point(rec, 0.0, 0.0, 0.0)
        local d = #(vector2(pos.x, pos.y) - vector2(at.x, at.y))
        if d < REACH and math.abs(pos.z - at.z) < 2.0 and inFront(pos, rec.bay) and (not bestD or d < bestD) then
            best, bestD = { rec = rec, at = at, model = rec.snap.model, coords = rec.base.base, rot = Geo.v3(rec.snap.rot) }, d
        end
    end
    local pool = GetGamePool('CObject')
    for i = 1, #pool do
        local entity = pool[i]
        local name = Rob.hashes[GetEntityModel(entity)]
        if name and IsEntityVisible(entity) then
            local coords = GetEntityCoords(entity)
            if not World.find(coords) then
                local rot = GetEntityRotation(entity, 2)
                local f = Geo.frame(coords, rot, CxAtmRob.Machines[name].bay)
                local d = #(vector2(pos.x, pos.y) - vector2(f.at.x, f.at.y))
                if d < REACH and math.abs(pos.z - f.at.z) < 2.0 and inFront(pos, f) and (not bestD or d < bestD) then
                    best, bestD = { entity = entity, at = f.at, model = name, coords = coords, rot = rot }, d
                end
            end
        end
    end
    return best
end

local function labelFor(c)
    if c.rec then
        local snap = c.rec.snap
        if snap.stage == 'empty' or snap.stage == 'dead' then return nil end
        if snap.worker and snap.worker ~= GetPlayerServerId(PlayerId()) then return nil end
        return L('prompt.resume')
    end
    if not crowbarOut() then return nil end
    return L('prompt.start')
end

local function hidePrompt()
    if not promptKey then return end
    promptKey = nil
    lib.hideInteraction(PROMPT)
end

local function showPrompt(c, label)
    local key = ('%s|%.2f|%.2f|%s'):format(label, c.at.x, c.at.y, startKey())
    if promptKey == key then return end
    promptKey = key
    lib.showInteraction({
        id = PROMPT, label = label, key = startKey(), priority = 45,
        anchor = { type = 'world', x = c.at.x, y = c.at.y, z = c.at.z + 0.05, maxDistance = REACH + 0.2 },
    })
end

CreateThread(function()
    while true do
        local sleep = SCAN_MS
        local ped = PlayerPedId()
        if Rob.session or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedCuffed(ped) then
            near = nil
            hidePrompt()
            sleep = 1000
        else
            local c = candidate(GetEntityCoords(ped))
            local label = c and labelFor(c)
            if c and label then
                near = c
                showPrompt(c, label)
                sleep = NEAR_MS
            else
                near = nil
                hidePrompt()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStart', function(name)
    if name == 'cortex-lib' then promptKey = nil end
end)

local starting = false

local ERRORS = {
    invalid = 'begin.invalid', unfit = 'begin.unfit', busy = 'begin.busy', far = 'begin.far', spent = 'begin.spent',
    taken = 'begin.taken', cooldown = 'begin.cooldown', police = 'begin.police', tool = 'begin.tool',
}

local function begin(c)
    if starting or Rob.session then return end
    starting = true
    local result = Rob.await('begin', c.model, c.coords, c.rot)
    starting = false
    if type(result) ~= 'table' then return end
    if not result.ok then
        local key = ERRORS[result.error] or 'begin.invalid'
        if result.error == 'cooldown' then
            Rob.notify('error', L(key, result.minutes or 1))
        elseif result.error == 'police' then
            Rob.notify('error', L(key, result.needed or 1))
        elseif result.error == 'tool' then
            Rob.notify('error', L(key, result.tool or ''))
        else
            Rob.notify('error', L(key))
        end
        return
    end
    local snap = result.machine
    World.apply(snap.id, snap)
    local rec = World.get(snap.id)
    if not rec then return end
    local deadline = GetGameTimer() + 4000
    while not rec.twin and GetGameTimer() < deadline do Wait(50) end
    if not rec.twin then
        Rob.notify('error', L('begin.assets'))
        TriggerServerEvent('cortex-atmrobbery:server:leave')
        return
    end
    Session.start(rec)
end

RegisterCommand('+cortexatmrob_start', function()
    if Rob.session or not near then return end
    if not lib.isInteractionActive(PROMPT) then return end
    local c = near
    CreateThread(function() begin(c) end)
end, false)
RegisterCommand('-cortexatmrob_start', function() end, false)
RegisterKeyMapping('+cortexatmrob_start', L('keymap.start'), 'keyboard', Config.Keys.start)

RegisterNetEvent('cortex-atmrobbery:client:effect', function(id, kind, data)
    local rec = World.get(id)
    if not rec or not rec.kitOn then return end
    local mine = Rob.session and Rob.session.id == id
    data = type(data) == 'table' and data or {}
    local wires = CxAtmRob.Bay and CxAtmRob.Bay.wires
    if kind == 'clang' then
        if not mine then Fx.sound('clang', World.point(rec, 0.0, -0.02, 0.0)) end
    elseif kind == 'lockdown' then
        Fx.sparks(World.point(rec, 0.1, 0.03, 0.05), 0.4)
        Fx.sound('lockdown', World.point(rec, 0.0, 0.0, 0.0))
    elseif kind == 'cut' then
        local w = wires and wires[tonumber(data.wire) or 0]
        local at = w and w.cutAt and World.point(rec, w.cutAt.x, w.cutAt.y, w.cutAt.z) or World.point(rec, 0.0, 0.03, 0.03)
        if not mine then Fx.sound('snip', at) end
        if data.effect == 'shock' or data.effect == 'bricked' then
            if not mine then Fx.sparks(at, 0.5) end
            rec.sparking = true
        end
    elseif kind == 'jump' then
        local left = CxAtmRob.Bay and CxAtmRob.Bay.terminals and CxAtmRob.Bay.terminals.left
        local t = left and left[tonumber(data.a) or 0]
        local at = t and World.point(rec, t.x, t.y, t.z) or World.point(rec, -0.2, 0.03, 0.03)
        if not mine and (data.effect == 'alarm' or data.effect == 'dye' or data.effect == 'short') then Fx.sparks(at, 0.35) end
        if data.effect == 'dye' then Fx.dye(id, World.point(rec, 0.0, -0.12, -0.04)) end
    elseif kind == 'drawer' then
        if data.dye then Fx.dye(id, World.point(rec, 0.0, -0.12, -0.04)) end
    elseif kind == 'grab' then
        if not mine then Fx.sound('grab', World.point(rec, 0.0, -0.1, -0.05)) end
    end
end)

CreateThread(function()
    while true do
        local any = false
        local cam = GetFinalRenderedCamCoord()
        for _, rec in pairs(World.recs) do
            if rec.kitOn and (rec.snap.unpowered or rec.sparking) and rec.snap.stage == 'dead' then
                local at = World.point(rec, 0.02, 0.02, 0.04)
                if #(cam - at) < 30.0 then
                    any = true
                    if math.random() < 0.55 then Fx.sparks(at + vector3((math.random() - 0.5) * 0.12, 0.0, (math.random() - 0.5) * 0.06), 0.22 + math.random() * 0.2) end
                end
            end
        end
        Wait(any and math.random(900, 2600) or 3000)
    end
end)
