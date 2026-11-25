Cassette = {}

local HANDLE_PX = 60
local BUNDLE_PX = 42
local PULL_TRAVEL = 0.16
local JIGGLE = 0.035

local function rig() return CxAtmRob.Bay and CxAtmRob.Bay.cassette end

local function handlePoint(s)
    local c = rig()
    local h = c and c.handle
    if not h then return nil end
    return World.point(s.rec, h.x, h.y + (s.rec.slide or 0.0) - 0.004, h.z)
end

local function reachable(snap, slot)
    if not snap.slots[slot] then return false end
    local above = slot - CxAtmRob.SlotsPerLayer
    while above >= 1 do
        if snap.slots[above] then return false end
        above = above - CxAtmRob.SlotsPerLayer
    end
    return true
end

local function bundles(s)
    local c = rig()
    local out = {}
    local slide = s.rec.slide or 0.0
    local top = c and c.bundle and c.bundle.h or 0.016
    for i = 1, CxAtmRob.SlotCount do
        local at = c and c.slots and c.slots[i]
        local live = at and reachable(s.rec.snap, i) and not (s.grabbing and s.grabbing == i)
        out[i] = { at = at and World.point(s.rec, at.x, at.y + slide, at.z + top), skip = not live }
    end
    return out
end

function Cassette.frame(s, nx, ny, targets)
    local snap = s.rec.snap
    local label
    if not snap.drawer then
        local at = handlePoint(s)
        local p = s.pulling
        if p then
            local raw = (ny - p.startY) / PULL_TRAVEL
            if snap.stage ~= 'cassette' then
                s.rec.pull = Geo.clamp(raw, 0.0, 1.0) * JIGGLE
                World.wake()
                if raw > 0.25 and not p.clunked then
                    p.clunked = true
                    Fx.sound('locked', at)
                    Rob.notify('inform', L('cassette.locked'))
                end
            else
                local value = Geo.clamp(raw, 0.0, 1.0)
                s.rec.pull = value
                World.wake()
                if value >= 1.0 and not p.sent then
                    p.sent = true
                    CreateThread(function()
                        local result = Rob.await('pull', s.id)
                        if Rob.session ~= s then return end
                        s.pulling = nil
                        if not result then
                            s.rec.pull = nil
                            return
                        end
                        Session.outcome(s, 'pull', result, at)
                    end)
                end
            end
            local sp = at and Pointer.screen(at)
            Nui.send({ type = 'gauge', gauge = { kind = 'pull', x = sp and sp.x or nx, y = sp and sp.y or ny, value = Geo.clamp(raw, 0.0, 1.0),
                locked = snap.stage ~= 'cassette' } })
        else
            local sp = at and Pointer.screen(at)
            local hot = sp and Geo.pixels(nx, ny, sp.x, sp.y) <= HANDLE_PX * Geo.scale()
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'handle', hot = hot } end
            if hot then label = L('hud.handle') end
            Nui.send({ type = 'gauge', gauge = false })
        end
    else
        Nui.send({ type = 'gauge', gauge = false })
        local list = bundles(s)
        local hover = Pointer.nearest(nx, ny, list, BUNDLE_PX)
        if hover ~= s.hover then
            s.hover = hover
            if hover then Fx.sound('tick', nil, 0.3) end
        end
        for i, b in ipairs(list) do
            if not b.skip then
                local sp = Pointer.screen(b.at)
                if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'bundle', hot = hover == i } end
            end
        end
        if hover then
            local value = Config.Reward.perBundle
            if snap.dye then value = math.floor(value * Config.Reward.dyedShare + 0.5) end
            label = L('hud.bundle', Rob.money(value))
        end
    end
    Nui.send({ type = 'targets', list = targets })
    return label
end

function Cassette.down(s, nx, ny)
    local snap = s.rec.snap
    if not snap.drawer then
        local at = handlePoint(s)
        local sp = at and Pointer.screen(at)
        if not sp or Geo.pixels(nx, ny, sp.x, sp.y) > HANDLE_PX * Geo.scale() then return end
        s.pulling = { startY = ny }
        Fx.sound('grip', at, 0.6)
        return
    end
    if s.grabbing then return end
    local list = bundles(s)
    local hover = Pointer.nearest(nx, ny, list, BUNDLE_PX)
    if not hover then return end
    s.grabbing = hover
    local at = list[hover].at
    CreateThread(function()
        local result = Rob.await('grab', s.id, hover)
        if Rob.session ~= s then return end
        s.grabbing = nil
        if not result or not result.ok then
            if result and result.error == 'carry' then Rob.notify('error', L('cassette.carry')) end
            return
        end
        Session.outcome(s, 'grab', result, at)
    end)
end

function Cassette.up(s)
    local p = s.pulling
    if not p or p.sent then return end
    s.pulling = nil
    s.rec.pull = nil
    World.wake()
end
