Wires = {}

local WIRE_PX = 16
local TERMINAL_PX = 18
local LCD_HOLD_MS = 1800

local function bay() return CxAtmRob.Bay or {} end

local function paths(s)
    local out = {}
    local wires = bay().wires or {}
    for i = 1, CxAtmRob.WireCount do
        local w = wires[i]
        local list = {}
        if w and w.path then
            for j, p in ipairs(w.path) do list[j] = World.point(s.rec, p.x, p.y, p.z) end
        end
        out[i] = list
    end
    return out
end

local function terminals(s)
    local out = {}
    local left = bay().terminals and bay().terminals.left or {}
    for i = 1, CxAtmRob.WireCount do
        local t = left[i]
        out[i] = { at = t and World.point(s.rec, t.x, t.y - 0.004, t.z) }
    end
    return out
end

local function colourOf(i)
    local w = bay().wires and bay().wires[i]
    return w and w.colour or CxAtmRob.Wiring.colours[i]
end

local function wireLabel(i)
    return L('hud.wire', L('colour.' .. colourOf(i)))
end

local function jumperAt(s, terminal)
    for index, pair in ipairs(s.rec.snap.jumpers) do
        if pair[1] == terminal or pair[2] == terminal then return index end
    end
    return nil
end

local function leadsLeft(s)
    return Config.Wires.jumperLeads - #s.rec.snap.jumpers
end

function Wires.toolList(s)
    local stage = s.rec.snap.stage
    return {
        { id = 'meter', key = '1', label = L('tool.meter') },
        { id = 'cutters', key = '2', label = L('tool.cutters') },
        { id = 'jumper', key = '3', label = L('tool.jumper'), count = leadsLeft(s) },
        { id = 'hand', key = '4', label = L('tool.hand'), locked = stage ~= 'cassette' },
    }
end

function Wires.enter(s)
    s.tool = s.tool or 'meter'
    s.clip = nil
    s.notebook = s.notebook or {}
    Tools.lcd({ type = 'reading', reading = false })
end

function Wires.exit(s)
    if s.tool == 'hand' then Cassette.up(s) end
    s.probing = nil
    Nui.send({ type = 'gauge', gauge = false })
    s.clip = nil
    Tools.drop('hand')
    Tools.drop('clip')
    Tools.meter(false)
    Nui.send({ type = 'targets', list = {} })
end

local function showReading(s, wire, reading)
    s.reading = { wire = wire, reading = reading, untilAt = GetGameTimer() + LCD_HOLD_MS }
    local r = CxAtmRob.Wiring.readings[reading] or CxAtmRob.Wiring.readings.dead
    Tools.lcd({ type = 'reading', reading = reading, value = r.value, unit = r.unit, mode = r.mode })
    s.notebook[wire] = reading
    Session.notebook(s)
end

local function probe(s, wire, at)
    s.probing = { wire = wire, at = at }
    Fx.sound('probe', at, 0.6)
    CreateThread(function()
        local reading = Rob.await('probe', s.id, wire)
        if Rob.session ~= s or not reading then return end
        showReading(s, wire, reading)
    end)
end

local function cut(s, wire, at)
    s.snipAt = GetGameTimer()
    Fx.sound('snip', at)
    CreateThread(function()
        local effect = Rob.await('cut', s.id, wire)
        if Rob.session ~= s then return end
        Session.outcome(s, 'cut', effect, at)
    end)
end

local function clipOn(s, terminal, at)
    if leadsLeft(s) <= 0 then
        Rob.notify('inform', L('jumper.none_left'))
        return
    end
    s.clip = { terminal = terminal, at = at }
    Fx.sound('clip', at)
end

local function bridge(s, a, b, at)
    s.clip = nil
    Fx.sound('clip', at)
    CreateThread(function()
        local effect = Rob.await('jump', s.id, a, b)
        if Rob.session ~= s then return end
        Session.outcome(s, 'jump', effect, at)
    end)
end

local function unclip(s, index, at)
    Fx.sound('unclip', at)
    CreateThread(function()
        local effect = Rob.await('unjump', s.id, index)
        if Rob.session ~= s then return end
        Session.outcome(s, 'unjump', effect, at)
    end)
end

function Wires.frame(s, nx, ny)
    local tool = s.tool
    local hoverLabel, hoverStatus
    local tip, dir
    local plane = World.point(s.rec, 0.0, 0.03, 0.0)
    local normal = World.normal(s.rec)
    local targets = {}

    if tool == 'meter' or tool == 'cutters' then
        local wire, _, point = Pointer.nearestPath(nx, ny, paths(s), WIRE_PX)
        if wire ~= s.hover then
            s.hover = wire
            if wire then Fx.sound('tick', nil, 0.3) end
        end
        if wire then
            hoverLabel = wireLabel(wire)
            if s.rec.snap.cut[wire] then
                hoverStatus = L('hud.cut')
            elseif s.notebook[wire] then
                hoverStatus = L('hud.reading.' .. s.notebook[wire])
            end
        end
        if s.probing and tool == 'meter' then
            tip = s.probing.at
        else
            tip = point or Pointer.onPlane(nx, ny, plane, normal) or plane
        end
        dir = Tools.handDir(tip, tool == 'meter' and 0.10 or 0.13, 0.15)
        local closed = tool == 'cutters' and s.snipAt and GetGameTimer() - s.snipAt < 220
        Tools.drop('clip')
        Tools.hold('hand', tool == 'meter' and 'probe' or 'cutters', tip - normal * 0.002, dir, 0.0, closed and 'closed' or nil)
    elseif tool == 'jumper' then
        local list = terminals(s)
        local hover = Pointer.nearest(nx, ny, list, TERMINAL_PX)
        if hover ~= s.hover then
            s.hover = hover
            if hover then Fx.sound('tick', nil, 0.3) end
        end
        for i, t in ipairs(list) do
            local sp = t.at and Pointer.screen(t.at)
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'terminal', hot = hover == i, taken = jumperAt(s, i) ~= nil or (s.clip and s.clip.terminal == i) } end
        end
        if hover then
            local taken = jumperAt(s, hover)
            hoverLabel = L('hud.terminal', hover)
            if taken then hoverStatus = L('hud.unclip') elseif s.clip then hoverStatus = L('hud.bridge') end
        end
        tip = hover and list[hover].at or Pointer.onPlane(nx, ny, plane, normal) or plane
        dir = Tools.handDir(tip, 0.12, 0.13)
        Tools.drop('hand')
        Tools.hold('clip', 'clip', tip - normal * 0.003, dir, 0.0)
        if s.clip then
            Tools.hold('hand', 'clip', s.clip.at - normal * 0.003, Tools.handDir(s.clip.at, -0.05, 0.16), 0.0)
        end
    elseif tool == 'hand' then
        Tools.drop('hand')
        Tools.drop('clip')
        hoverLabel = Cassette.frame(s, nx, ny, targets)
    end

    if tool ~= 'hand' then Nui.send({ type = 'targets', list = targets }) end
    Nui.send({ type = 'hover', label = hoverLabel or false, status = hoverStatus or false })

    if s.reading and GetGameTimer() > s.reading.untilAt and not s.probing then
        s.reading = nil
        Tools.lcd({ type = 'reading', reading = false })
    end
    Tools.meter(tool == 'meter' or s.reading ~= nil)
end

function Wires.down(s, button, nx, ny)
    if button == 2 then
        if s.clip then
            s.clip = nil
            Fx.sound('unclip', nil, 0.6)
            return true
        end
        return false
    end
    if button ~= 0 then return true end
    local tool = s.tool
    if tool == 'meter' or tool == 'cutters' then
        local wire, _, point = Pointer.nearestPath(nx, ny, paths(s), WIRE_PX)
        if not wire then return true end
        if tool == 'meter' then probe(s, wire, point) else
            if s.rec.snap.cut[wire] then return true end
            cut(s, wire, point)
        end
    elseif tool == 'jumper' then
        local list = terminals(s)
        local hover = Pointer.nearest(nx, ny, list, TERMINAL_PX)
        if not hover then return true end
        local taken = jumperAt(s, hover)
        if s.clip then
            if hover == s.clip.terminal then
                s.clip = nil
                Fx.sound('unclip', list[hover].at, 0.6)
            elseif taken then
                Rob.notify('inform', L('jumper.occupied'))
            else
                bridge(s, s.clip.terminal, hover, list[hover].at)
            end
        elseif taken then
            unclip(s, taken, list[hover].at)
        else
            clipOn(s, hover, list[hover].at)
        end
    elseif tool == 'hand' then
        Cassette.down(s, nx, ny)
    end
    return true
end

function Wires.up(s, button)
    if button ~= 0 then return end
    if s.probing then
        s.probing = nil
        if s.reading then s.reading.untilAt = GetGameTimer() + LCD_HOLD_MS end
    end
    if s.tool == 'hand' then Cassette.up(s) end
end

function Wires.select(s, tool)
    if tool == s.tool then return end
    if tool ~= 'meter' and tool ~= 'cutters' and tool ~= 'jumper' and tool ~= 'hand' then return end
    if s.tool == 'hand' then
        Cassette.up(s)
        Nui.send({ type = 'gauge', gauge = false })
    end
    s.probing = nil
    s.tool = tool
    s.clip = nil
    s.hover = nil
    Fx.sound('tool', nil, 0.5)
    Session.tools(s)
    if tool == 'hand' then Camera.stage('cassette') else Camera.stage('wires') end
end

function Wires.help(s)
    local rows = {
        { label = L('help.tools'), value = '1-4' },
        { label = L('help.use'), value = 'LMB' },
        { label = L('help.notes'), value = 'TAB' },
        { label = L('help.leave'), value = 'ESC' },
    }
    if s.tool == 'jumper' then table.insert(rows, 3, { label = L('help.cancelclip'), value = 'RMB' }) end
    return rows
end
