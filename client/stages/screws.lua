Screws = {}

local HOVER_PX = 40
local MIN_RADIUS_PX = 10
local WINDOW_MS = 350
local CAM_OUT_LOSS = 0.6

local function plate() return CxAtmRob.Bay and CxAtmRob.Bay.plate end

local function points(s)
    local p = plate()
    local out = {}
    for i = 1, CxAtmRob.ScrewCount do
        local at = p and p.screws and p.screws[i]
        out[i] = { at = at and World.point(s.rec, at.x, (p.y or 0.010) - 0.003, at.z), skip = s.rec.snap.screws[i] or false }
    end
    return out
end

function Screws.enter(s)
    s.turn = nil
    s.rec.turn = nil
    Nui.send({ type = 'tools', list = {}, active = false })
end

function Screws.exit(s)
    s.turn = nil
    s.rec.turn = nil
    Nui.send({ type = 'gauge', gauge = false })
    Nui.send({ type = 'targets', list = {} })
    Tools.drop('hand')
end

local function release(s)
    local t = s.turn
    if t then
        s.rec.progress = s.rec.progress or {}
        s.rec.progress[t.screw] = t.turns
    end
    s.turn = nil
    s.rec.turn = nil
    Nui.send({ type = 'gauge', gauge = false })
end

local function camOut(s)
    local t = s.turn
    t.turns = math.max(0.0, t.turns - CAM_OUT_LOSS)
    t.cammed = GetGameTimer()
    t.samples = {}
    Fx.sound('cam', t.at)
    Camera.shake('HAND_SHAKE', 0.4)
    CreateThread(function() Rob.await('strike', s.id, 'cam') end)
    Rob.notify('error', L('screw.cam'))
end

local function finish(s, t)
    t.sending = true
    CreateThread(function()
        for _ = 1, 8 do
            local ok = Rob.await('screw', s.id, t.screw)
            if Rob.session ~= s then return end
            if ok then
                if s.turn == t then release(s) end
                return
            end
            Wait(450)
            if s.turn ~= t then return end
        end
        if s.turn == t then
            t.sending = false
            release(s)
        end
    end)
end

local function angleAround(cx, cy, nx, ny)
    local v = Geo.view
    local w, h = v and v.w or 1920, v and v.h or 1080
    local dx, dy = (nx - cx) * w, (ny - cy) * h
    return math.atan(dy, dx), math.sqrt(dx * dx + dy * dy)
end

function Screws.frame(s, nx, ny)
    local list = points(s)
    local targets = {}
    for i, p in ipairs(list) do
        if p.at and not p.skip then
            local sp = Pointer.screen(p.at)
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'screw', hot = s.hover == i or (s.turn and s.turn.screw == i) } end
        end
    end
    Nui.send({ type = 'targets', list = targets })

    local t = s.turn
    local spin = 0.0
    if t then
        local sp = Pointer.screen(t.at)
        if sp and not t.sending then
            local angle, radius = angleAround(sp.x, sp.y, nx, ny)
            if radius >= MIN_RADIUS_PX * Geo.scale() then
                if t.angle then
                    local d = angle - t.angle
                    if d > math.pi then d = d - 2 * math.pi elseif d < -math.pi then d = d + 2 * math.pi end
                    local delta = -d / (2 * math.pi)
                    if not (t.cammed and GetGameTimer() - t.cammed < 400) then
                        t.turns = math.max(0.0, t.turns + delta)
                        local now = GetGameTimer()
                        t.samples[#t.samples + 1] = { at = now, d = math.max(0.0, delta) }
                        while t.samples[1] and now - t.samples[1].at > WINDOW_MS do table.remove(t.samples, 1) end
                        local sum = 0.0
                        for _, smp in ipairs(t.samples) do sum = sum + smp.d end
                        t.speed = sum / (WINDOW_MS / 1000)
                        if delta > 0.004 and now - (t.squeakAt or 0) > 180 then
                            t.squeakAt = now
                            Fx.sound('squeak', t.at, 0.45)
                        end
                        if delta < -0.02 and now - (t.tightAt or 0) > 2500 then
                            t.tightAt = now
                            Nui.send({ type = 'hint', text = L('screw.tighten') })
                        end
                        if t.speed > Config.Screws.maxTurnsPerSecond then camOut(s) end
                    end
                end
                t.angle = angle
            else
                t.angle = nil
            end
            if t.turns >= Config.Screws.turns then finish(s, t) end
        end
        spin = t.turns * 360.0
        s.rec.turn = { screw = t.screw, turns = t.turns }
        Nui.send({ type = 'gauge', gauge = { kind = 'turn', x = sp and sp.x or nx, y = sp and sp.y or ny,
            value = Geo.clamp(t.turns / Config.Screws.turns, 0.0, 1.0),
            speed = Geo.clamp((t.speed or 0) / Config.Screws.maxTurnsPerSecond, 0.0, 1.2) } })
    else
        local hover = Pointer.nearest(nx, ny, list, HOVER_PX)
        if hover ~= s.hover then
            s.hover = hover
            if hover then Fx.sound('tick', nil, 0.35) end
        end
        Nui.send({ type = 'hover', label = hover and L('hud.screw') or false })
    end

    local tip, dir
    if t then
        tip = t.at - World.normal(s.rec) * (0.001 + Geo.clamp(t.turns / Config.Screws.turns, 0.0, 1.0) * 0.007)
        dir = Geo.norm(World.normal(s.rec) * 1.0 + Tools.handDir(tip, 0.10, 0.12) * 0.35)
    else
        local p = plate()
        local hit = Pointer.onPlane(nx, ny, World.point(s.rec, 0.0, (p and p.y or 0.010) - 0.02, 0.0), World.normal(s.rec))
        tip = hit or World.point(s.rec, 0.0, -0.05, 0.0)
        dir = Geo.norm(World.normal(s.rec) * 0.8 + Tools.handDir(tip, 0.10, 0.14) * 0.6)
    end
    Tools.hold('hand', 'screwdriver', tip, dir, -spin)
end

function Screws.down(s, button, nx, ny)
    if button ~= 0 or s.turn then return end
    local list = points(s)
    local hover = Pointer.nearest(nx, ny, list, HOVER_PX)
    if not hover then return end
    local before = s.rec.progress and s.rec.progress[hover] or 0.0
    s.turn = { screw = hover, at = list[hover].at, turns = before, samples = {}, speed = 0.0 }
    Fx.sound('bite', list[hover].at, 0.6)
end

function Screws.up(s, button)
    if button ~= 0 or not s.turn or s.turn.sending then return end
    release(s)
end

function Screws.help()
    return {
        { label = L('help.unscrew'), value = 'LMB' },
        { label = L('help.leave'), value = 'ESC' },
    }
end
