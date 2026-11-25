Session = {}

local KNEEL_DICT, KNEEL_CLIP = 'amb@medic@standing@kneel@base', 'base'
local WORK_DICT, WORK_CLIP = 'amb@medic@standing@tendtodead@idle_a', 'idle_a'
local STAND_BACK = 0.62

local function stageModule(stage)
    if stage == 'door' then return Pry end
    if stage == 'plate' then return Screws end
    if stage == 'wires' or stage == 'cassette' then return Wires end
    return nil
end

local function legend(s)
    local m = stageModule(s.stage)
    if not m then
        lib.hideHelp()
        return
    end
    lib.showHelp(m.help(s), { compact = true })
end

function Session.tools(s)
    if s.stage == 'wires' or s.stage == 'cassette' then
        Nui.send({ type = 'tools', list = Wires.toolList(s), active = s.tool })
    else
        Nui.send({ type = 'tools', list = {}, active = false })
    end
    legend(s)
end

function Session.notebook(s)
    local rows = {}
    for i = 1, CxAtmRob.WireCount do
        local w = CxAtmRob.Bay and CxAtmRob.Bay.wires and CxAtmRob.Bay.wires[i]
        rows[i] = { wire = i, colour = w and w.colour or CxAtmRob.Wiring.colours[i], reading = s.notebook and s.notebook[i] or false,
            cut = s.rec.snap.cut[i] or false }
    end
    Nui.send({ type = 'notebook', rows = rows })
end

local function hudStage(s)
    Nui.send({ type = 'stage', stage = s.stage, hint = L('hint.' .. s.stage), machine = L(s.rec.def.label) })
end

local function hudStrikes(s, flash)
    Nui.send({ type = 'strikes', count = s.rec.snap.strikes, max = Config.Strikes, flash = flash and GetGameTimer() or 0 })
end

local function standPoint(rec)
    local f = rec.base
    local b = rec.def.bay
    local at = Geo.toWorld(f, 0.0, b.y - STAND_BACK, 0.0)
    return at, rec.snap.rot.z % 360.0
end

local function pose(s)
    local ped = PlayerPedId()
    local at, heading = standPoint(s.rec)
    local pos = GetEntityCoords(ped)
    if #(vector2(pos.x, pos.y) - vector2(at.x, at.y)) > 0.25 then
        TaskGoStraightToCoord(ped, at.x, at.y, pos.z, 1.0, 2000, heading, 0.05)
        local deadline = GetGameTimer() + 2200
        while GetGameTimer() < deadline and #(vector2(GetEntityCoords(ped).x, GetEntityCoords(ped).y) - vector2(at.x, at.y)) > 0.2 do Wait(50) end
    end
    if Rob.session ~= s then return end
    SetEntityHeading(ped, heading)
    if Rob.loadDict(KNEEL_DICT) then
        TaskPlayAnim(ped, KNEEL_DICT, KNEEL_CLIP, 3.0, 3.0, -1, 1, 0.0, false, false, false)
    end
end

local function work(s)
    local ped = PlayerPedId()
    if not Rob.loadDict(WORK_DICT) then return end
    if not IsEntityPlayingAnim(ped, WORK_DICT, WORK_CLIP, 3) then
        TaskPlayAnim(ped, WORK_DICT, WORK_CLIP, 4.0, 4.0, 1800, 1, 0.0, false, false, false)
        SetTimeout(1850, function()
            if Rob.session == s and Rob.loadDict(KNEEL_DICT) then
                TaskPlayAnim(PlayerPedId(), KNEEL_DICT, KNEEL_CLIP, 3.0, 3.0, -1, 1, 0.0, false, false, false)
            end
        end)
    end
end

local function hud(visible)
    if GetResourceState('cortex-hud') ~= 'started' then return end
    pcall(function()
        if visible then exports['cortex-hud']:showHud(Rob.resource) else exports['cortex-hud']:hideHud(Rob.resource) end
    end)
end

local function enterStage(s, stage)
    local before = stageModule(s.stage)
    local after = stageModule(stage)
    if before and before ~= after and before.exit then before.exit(s) end
    local was = s.stage
    s.stage = stage
    s.hover = nil
    if after and (after ~= before or was == nil) and after.enter then after.enter(s) end
    if stage == 'cassette' and was == 'wires' then
        s.tool = 'hand'
        Camera.stage('cassette')
    elseif stage == 'wires' or stage == 'cassette' then
        Camera.stage(s.tool == 'hand' and 'cassette' or 'wires')
    else
        Camera.stage(stage)
    end
    hudStage(s)
    Session.tools(s)
    if stage == 'wires' or stage == 'cassette' then Session.notebook(s) end
end

function Session.active() return Rob.session ~= nil end

function Session.finish(reason)
    local s = Rob.session
    if not s or s.closing then return end
    s.closing = true
    local m = stageModule(s.stage)
    if m and m.exit then pcall(m.exit, s) end
    Tools.dropAll()
    s.rec.lever, s.rec.turn, s.rec.pull = nil, nil, nil
    Rob.session = nil
    Nui.send({ type = 'session', open = false })
    Nui.focus(false)
    lib.hideHelp()
    Camera.exit(reason == 'stopped')
    hud(true)
    local ped = PlayerPedId()
    if reason == 'shock' then
        SetPedToRagdoll(ped, 1600, 2000, 0, false, false, false)
    else
        ClearPedTasks(ped)
    end
    TriggerServerEvent('cortex-atmrobbery:server:leave')
    World.wake()
end

local function tooFar(s)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) or IsPedCuffed(ped) then return true end
    return #(GetEntityCoords(ped) - s.rec.base.base) > CxAtmRob.Reach
end

local function loop(s)
    CreateThread(function()
        while Rob.session == s do
            if tooFar(s) then
                Session.finish('distance')
                return
            end
            local nx, ny = Pointer.pos()
            Camera.sway(nx, ny)
            DisableAllControlActions(0)
            if GetGameTimer() >= (Camera.readyAt or 0) then
                local m = stageModule(s.stage)
                if m then
                    local ok, err = pcall(m.frame, s, nx, ny)
                    if not ok then print(('^1[cortex-atmrobbery]^7 %s frame: %s'):format(s.stage, tostring(err))) end
                end
            end
            Wait(0)
        end
    end)
end

function Session.start(rec)
    if Rob.session then return end
    rec.notebook = rec.notebook or {}
    local s = { id = rec.id, rec = rec, stage = nil, tool = rec.snap.stage == 'cassette' and 'hand' or 'meter', notebook = rec.notebook }
    Rob.session = s
    Nui.reset()
    Nui.send({ type = 'session', open = true, machine = L(rec.def.label) })
    Nui.focus(true)
    hud(false)
    CreateThread(function()
        pose(s)
        if Rob.session ~= s then return end
        World.wake()
        Camera.enter(rec, rec.snap.stage)
        enterStage(s, rec.snap.stage)
        hudStrikes(s, false)
        Nui.send({ type = 'alarmHud', seconds = math.ceil(Fx.alarmLeft(rec.id) / 1000) })
        loop(s)
    end)
end

function Session.updated(rec, old)
    local s = Rob.session
    if not s or s.rec ~= rec then return end
    local snap = rec.snap
    if s.ending then return end
    if old and snap.strikes ~= old.strikes then hudStrikes(s, true) end
    if snap.stage == 'dead' or snap.stage == 'empty' then
        s.ending = true
        local m = stageModule(s.stage)
        if m and m.exit then pcall(m.exit, s) end
        Tools.dropAll()
        s.stage = snap.stage
        Nui.send({ type = 'hover', label = false, status = false })
        Nui.send({ type = 'gauge', gauge = false })
        lib.hideHelp()
        if snap.stage == 'dead' then
            Rob.notify('error', L('end.dead'))
            SetTimeout(900, function() if Rob.session == s then Session.finish('dead') end end)
        else
            Fx.frontend('ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET')
            Rob.notify('success', L('end.empty', Rob.money(snap.paid)))
            SetTimeout(1400, function() if Rob.session == s then Session.finish('empty') end end)
        end
        return
    end
    if snap.stage ~= s.stage then enterStage(s, snap.stage) end
    if snap.stage == 'wires' or snap.stage == 'cassette' then
        Session.tools(s)
        Session.notebook(s)
    end
    Nui.send({ type = 'alarmHud', seconds = math.ceil(Fx.alarmLeft(rec.id) / 1000) })
end

function Session.removed(id)
    local s = Rob.session
    if s and s.id == id then Session.finish('removed') end
end

local function shock(s, at)
    Fx.sparks(at, 0.55)
    Nui.send({ type = 'flash', kind = 'shock' })
    Camera.shake('SMALL_EXPLOSION_SHAKE', 0.22)
    local ped = PlayerPedId()
    local damage = math.floor(Config.Wires.shockDamage)
    if damage > 0 then ApplyDamageToPed(ped, damage, false) end
    Rob.notify('error', L('wire.shock'))
    SetTimeout(250, function() if Rob.session == s then Session.finish('shock') end end)
end

function Session.outcome(s, action, effect, at)
    work(s)
    if action == 'cut' then
        if effect == 'shock' then return shock(s, at) end
        if effect == 'bricked' then
            Fx.sparks(at, 0.3)
            return
        end
        if effect == 'alarm' then
            Rob.notify('error', L('wire.alarm'))
            return
        end
        if effect == 'safe' then
            Fx.sound('disarm', at, 0.7)
            return
        end
        return
    end
    if action == 'jump' then
        if effect == 'bolt' then
            Rob.notify('success', L('jumper.bolt'))
            return
        end
        if effect == 'bypass' then
            Fx.sound('hum', at, 0.6)
            return
        end
        if effect == 'alarm' then
            Fx.sparks(at, 0.35)
            Rob.notify('error', L('jumper.alarm'))
            return
        end
        if effect == 'dye' then
            Fx.sparks(at, 0.35)
            Nui.send({ type = 'flash', kind = 'dye' })
            Rob.notify('error', L('jumper.dye'))
            return
        end
        if effect == 'short' then
            Fx.sparks(at, 0.45)
            Camera.shake('SMALL_EXPLOSION_SHAKE', 0.10)
            Rob.notify('error', L('jumper.short'))
            return
        end
        if effect == 'settle' then return Rob.notify('inform', L('jumper.settle')) end
        if effect == 'cutwire' then return Rob.notify('inform', L('jumper.cutwire')) end
        if effect == 'none_left' then return Rob.notify('inform', L('jumper.none_left')) end
        if effect == 'occupied' then return Rob.notify('inform', L('jumper.occupied')) end
        return
    end
    if action == 'unjump' then
        if effect == 'alarm' then Rob.notify('error', L('wire.alarm')) end
        return
    end
    if action == 'pull' then
        if effect.dye then
            Nui.send({ type = 'flash', kind = 'dye' })
            Rob.notify('error', L('cassette.dye'))
        end
        if effect.alarm then Rob.notify('error', L('cassette.alarm')) end
        return
    end
    if action == 'grab' then
        Fx.sound('grab', at)
        Fx.frontend('PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
        Nui.send({ type = 'cash', amount = effect.amount, total = effect.total or effect.amount, dyed = s.rec.snap.dye })
    end
end

local function key(s, name, down)
    if name == 'Escape' or name == 'Backspace' then
        if not down then return end
        if s.clip then
            s.clip = nil
            return
        end
        Session.finish('leave')
        return
    end
    if name == 'Tab' then
        if s.stage == 'wires' or s.stage == 'cassette' then
            Nui.send({ type = 'notes', open = down })
        end
        return
    end
    if not down then return end
    if s.stage == 'wires' or s.stage == 'cassette' then
        local tools = { ['1'] = 'meter', ['2'] = 'cutters', ['3'] = 'jumper', ['4'] = 'hand' }
        if tools[name] then Wires.select(s, tools[name]) end
    end
end

function Session.input(data)
    local s = Rob.session
    if not s or s.closing or not s.stage then return end
    if GetGameTimer() < (Camera.readyAt or 0) then return end
    local m = stageModule(s.stage)
    local kind = data.kind
    if kind == 'tool' and type(data.id) == 'string' then
        if s.stage == 'wires' or s.stage == 'cassette' then Wires.select(s, data.id) end
        return
    end
    if kind == 'key' and type(data.key) == 'string' and #data.key <= 12 then
        return key(s, data.key, data.down ~= false)
    end
    local button = math.tointeger(data.button) or 0
    local nx, ny = Pointer.pos()
    if kind == 'down' then
        if m and m.down then m.down(s, button, nx, ny) end
    elseif kind == 'up' then
        if m and m.up then m.up(s, button) end
    end
end

RegisterNetEvent('cortex-atmrobbery:client:kicked', function(id)
    local s = Rob.session
    if s and s.id == id then Session.finish('kicked') end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    if Rob.session then
        pcall(Session.finish, 'stopped')
        pcall(ClearPedTasks, PlayerPedId())
    end
end)
