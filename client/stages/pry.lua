Pry = {}

local HOVER_PX = 46
local TRAVEL = 0.20
local SEAM_Y = -0.006

local function points(s)
    local door = CxAtmRob.Bay and CxAtmRob.Bay.door
    local out = {}
    for i = 1, CxAtmRob.PryPoints do
        local p = door and door.pry and door.pry[i]
        out[i] = { at = p and World.point(s.rec, p.x, SEAM_Y, p.z), skip = s.rec.snap.pry[i] or false, x = p and p.x, z = p and p.z }
    end
    return out
end

local function zoneFor(s, point)
    local z = Config.Pry.zone
    local shift = (math.sin((s.id or 1) * 3.1 + point * 1.7)) * 0.04
    return Geo.clamp(z[1] + shift, 0.2, 0.86), Geo.clamp(z[2] + shift, 0.28, 0.92)
end

function Pry.enter(s)
    s.lever = nil
    s.rec.lever = nil
    Nui.send({ type = 'tools', list = {}, active = false })
end

function Pry.exit(s)
    s.lever = nil
    s.rec.lever = nil
    Nui.send({ type = 'gauge', gauge = false })
    Nui.send({ type = 'targets', list = {} })
    Tools.drop('hand')
end

local function release(s)
    s.lever = nil
    s.rec.lever = nil
    Nui.send({ type = 'gauge', gauge = false })
end

local function slip(s)
    local l = s.lever
    release(s)
    s.slippedAt = GetGameTimer()
    Fx.sound('clang', l and l.at)
    Camera.shake('SMALL_EXPLOSION_SHAKE', 0.06)
    CreateThread(function() Rob.await('strike', s.id, 'slip') end)
    Rob.notify('error', L('pry.slip'))
end

local function pop(s, l)
    release(s)
    Fx.sound('creak', l.at, 0.7)
    CreateThread(function()
        local ok = Rob.await('pry', s.id, l.point)
        if Rob.session ~= s then return end
        if ok then
            Fx.sound('pop', l.at)
            Camera.shake('HAND_SHAKE', 0.25)
        else
            Rob.notify('inform', L('pry.stuck'))
        end
    end)
end

function Pry.frame(s, nx, ny)
    local list = points(s)
    local targets = {}
    for i, p in ipairs(list) do
        if p.at and not p.skip then
            local sp = Pointer.screen(p.at)
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'seam', hot = s.hover == i or (s.lever and s.lever.point == i) } end
        end
    end
    local l = s.lever
    if l then
        local raw = (ny - l.startY) / TRAVEL
        local tremor = math.sin(GetGameTimer() * 0.031) * 0.012 * Geo.clamp(raw * 1.4, 0.0, 1.0)
        l.value = Geo.clamp(raw + tremor, 0.0, 1.05)
        s.rec.lever = { point = l.point, value = Geo.clamp(l.value, 0.0, 1.0) }
        local now = GetGameTimer()
        if l.value >= Config.Pry.slipAt then
            slip(s)
        elseif l.value >= l.low and l.value <= l.high then
            l.inZone = l.inZone or now
            if not l.groaned and now - l.inZone > Config.Pry.holdMs * 0.4 then
                l.groaned = true
                Fx.sound('creak', l.at)
            end
            if now - l.inZone >= Config.Pry.holdMs then
                pop(s, l)
            end
        else
            l.inZone = nil
            l.groaned = false
        end
        if s.lever then
            local sp = Pointer.screen(l.at)
            Nui.send({ type = 'gauge', gauge = { kind = 'lever', x = sp and sp.x or nx, y = sp and sp.y or ny, value = l.value,
                low = l.low, high = l.high, slip = Config.Pry.slipAt,
                hold = l.inZone and Geo.clamp((now - l.inZone) / Config.Pry.holdMs, 0.0, 1.0) or 0 } })
        end
    else
        local hover = Pointer.nearest(nx, ny, list, HOVER_PX)
        if hover ~= s.hover then
            s.hover = hover
            if hover then Fx.sound('tick', nil, 0.35) end
        end
        Nui.send({ type = 'hover', label = hover and L('hud.seam') or false })
    end
    Nui.send({ type = 'targets', list = targets })

    local tip, dir
    if s.lever then
        tip = s.lever.at - World.normal(s.rec) * 0.004
        local v = Geo.view
        local push = s.lever.point == 3 and v.up or -v.right
        dir = Geo.norm(Tools.handDir(tip, 0.10, 0.20) + push * (0.10 + s.lever.value * 0.55))
    else
        local hit = Pointer.onPlane(nx, ny, World.point(s.rec, 0.0, SEAM_Y - 0.012, 0.0), World.normal(s.rec))
        tip = hit or World.point(s.rec, 0.0, -0.05, 0.0)
        dir = Tools.handDir(tip, 0.12, 0.20)
    end
    Tools.hold('hand', 'crowbar', tip, dir, 90.0)
end

function Pry.down(s, button, nx, ny)
    if button ~= 0 or s.lever then return end
    if s.slippedAt and GetGameTimer() - s.slippedAt < 500 then return end
    local list = points(s)
    local hover = Pointer.nearest(nx, ny, list, HOVER_PX)
    if not hover then return end
    local low, high = zoneFor(s, hover)
    s.lever = { point = hover, at = list[hover].at, startY = ny, value = 0.0, low = low, high = high }
    Fx.sound('bite', list[hover].at)
end

function Pry.up(s, button)
    if button == 0 and s.lever then release(s) end
end

function Pry.help()
    return {
        { label = L('help.lever'), value = 'LMB' },
        { label = L('help.leave'), value = 'ESC' },
    }
end
