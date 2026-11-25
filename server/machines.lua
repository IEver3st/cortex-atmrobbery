Robbery = Robbery or {}

local ROLES = { 'coil', 'mains', 'loop', 'loop', 'tamper', 'dead' }
local READING = { coil = 'steady', mains = 'mains', loop = 'pulse', tamper = 'faint', dead = 'dead' }
local SAME_MACHINE = 0.5

local machines = {}
local working = {}
local cooldownUntil = {}
local nextId = 0
local sweeping = false

Robbery.machines = machines
Robbery.working = working

local function shuffled(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function wireOf(machine, role)
    local found = {}
    for wire, r in ipairs(machine.roles) do
        if r == role then found[#found + 1] = wire end
    end
    return found
end

local function jumperBetween(machine, roleA, roleB)
    for index, jumper in ipairs(machine.jumpers) do
        local a, b = machine.roles[jumper[1]], machine.roles[jumper[2]]
        if (a == roleA and b == roleB) or (a == roleB and b == roleA) then return index end
    end
    return nil
end

function Robbery.snapshot(machine)
    return {
        id = machine.id,
        model = machine.model,
        coords = machine.coords,
        rot = machine.rot,
        stage = machine.stage,
        pry = machine.pry,
        screws = machine.screws,
        cut = machine.cut,
        jumpers = machine.jumpers,
        bolt = machine.bolt,
        drawer = machine.drawer,
        dye = machine.dye,
        slots = machine.slots,
        strikes = machine.strikes,
        worker = machine.worker or false,
        alarmLeft = math.max(0, (machine.alarmEnds or 0) - os.time()),
        unpowered = machine.unpowered or false,
        tamperCut = machine.tamperCut or false,
        paid = machine.paid,
    }
end

local placements = {}
for _, p in ipairs(CxAtmRob.Placements or {}) do
    placements[#placements + 1] = { model = p[1], at = vec3(p[2], p[3], p[4]), heading = p[5] }
end
for i, p in ipairs(Config.ExtraAtms or {}) do
    local c = type(p) == 'table' and p.coords
    if c and type(p.model) == 'string' and CxAtmRob.Machines[p.model] and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) and tonumber(p.heading) then
        placements[#placements + 1] = { model = p.model, at = vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0), heading = tonumber(p.heading) }
    else
        print(('^3[cortex-atmrobbery]^7 Config.ExtraAtms entry %d skipped: it needs a Cortex ATM model, coords and heading'):format(i))
    end
end

function Robbery.locate(model, at)
    local best, bestD
    for _, p in ipairs(placements) do
        if p.model == model then
            local flat = #(vector2(p.at.x, p.at.y) - vector2(at.x, at.y))
            if flat < 0.25 and math.abs(p.at.z - at.z) < 1.5 and (not bestD or flat < bestD) then best, bestD = p, flat end
        end
    end
    if best then return best.at, best.heading end
end

function Robbery.broadcast(machine, removed)
    if removed then
        TriggerClientEvent('cortex-atmrobbery:client:machine', -1, machine.id, nil)
        return
    end
    local payload = Robbery.snapshot(machine)
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if GetPlayerRoutingBucket(src) == machine.bucket then
            TriggerClientEvent('cortex-atmrobbery:client:machine', src, machine.id, payload)
        end
    end
end

function Robbery.effect(machine, kind, data)
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if GetPlayerRoutingBucket(src) == machine.bucket then
            local ped = GetPlayerPed(src)
            if ped ~= 0 and #(GetEntityCoords(ped) - machine.at) < 120.0 then
                TriggerClientEvent('cortex-atmrobbery:client:effect', src, machine.id, kind, data)
            end
        end
    end
end

function Robbery.sendAll(source)
    local bucket = GetPlayerRoutingBucket(source)
    local list = {}
    for _, machine in pairs(machines) do
        if machine.bucket == bucket then list[#list + 1] = Robbery.snapshot(machine) end
    end
    TriggerClientEvent('cortex-atmrobbery:client:all', source, list)
end

local function startSweep()
    if sweeping then return end
    sweeping = true
    CreateThread(function()
        while next(machines) do
            Wait(15000)
            local now = os.time()
            for id, machine in pairs(machines) do
                if machine.worker and Robbery.stale(machine, now) then
                    local worker = machine.worker
                    TriggerClientEvent('cortex-atmrobbery:client:kicked', worker, machine.id)
                    Robbery.release(worker)
                end
                if not machine.repairAt and not machine.worker and machine.idleSince
                    and now - machine.idleSince >= Config.Cooldown.abandonMinutes * 60 then
                    local opened = machine.stage ~= 'door'
                    machine.repairAt = now + (opened and Config.Cooldown.repairMinutes * 60 or 0)
                end
                if machine.repairAt and now >= machine.repairAt and not machine.worker then
                    machines[id] = nil
                    Robbery.broadcast(machine, true)
                    Robbery.audit(nil, 'repaired', machine)
                end
            end
        end
        sweeping = false
    end)
end

local IDLE_SECONDS, ENDED_SECONDS = 180, 20

function Robbery.stale(machine, now)
    local worker = machine.worker
    local ped = GetPlayerPed(worker)
    if not ped or ped == 0 then return true end
    if GetPlayerRoutingBucket(worker) ~= machine.bucket then return true end
    if #(GetEntityCoords(ped) - machine.at) > CxAtmRob.Reach + 1.5 then return true end
    if now - (machine.lastAct or now) > IDLE_SECONDS then return true end
    if (machine.stage == 'empty' or machine.stage == 'dead') and now - (machine.endedAt or now) > ENDED_SECONDS then return true end
    return false
end

function Robbery.stampCooldown(source)
    if Config.Cooldown.playerMinutes > 0 then
        cooldownUntil[Robbery.identity(source)] = os.time() + Config.Cooldown.playerMinutes * 60
    end
end

function Robbery.wouldBolt(machine, a, b)
    local x, y = machine.roles[a], machine.roles[b]
    return (x == 'coil' and y == 'mains') or (x == 'mains' and y == 'coil')
end

function Robbery.remove(machine)
    if machine.worker then
        working[machine.worker] = nil
        TriggerClientEvent('cortex-atmrobbery:client:kicked', machine.worker, machine.id)
    end
    machines[machine.id] = nil
    Robbery.broadcast(machine, true)
end

function Robbery.find(bucket, at)
    for _, machine in pairs(machines) do
        if machine.bucket == bucket and #(machine.at - at) < SAME_MACHINE then return machine end
    end
    return nil
end

function Robbery.cooldownLeft(source)
    local untilAt = cooldownUntil[Robbery.identity(source)]
    if not untilAt then return 0 end
    return math.max(0, untilAt - os.time())
end

function Robbery.clearCooldown(source)
    cooldownUntil[Robbery.identity(source)] = nil
end

function Robbery.create(source, model, at, rot)
    nextId = nextId + 1
    local low, high = Config.Cassette.bundles[1], Config.Cassette.bundles[2]
    local bundles = math.random(low, high)
    local slots = {}
    for i = 1, CxAtmRob.SlotCount do slots[i] = i > CxAtmRob.SlotCount - bundles end
    local machine = {
        id = nextId,
        model = model,
        bucket = GetPlayerRoutingBucket(source),
        at = at,
        coords = { x = at.x, y = at.y, z = at.z },
        rot = { x = rot.x, y = rot.y, z = rot.z },
        stage = 'door',
        pry = { false, false, false },
        screws = { false, false, false, false },
        cut = { false, false, false, false, false, false },
        jumpers = {},
        roles = shuffled(ROLES),
        bolt = false,
        drawer = false,
        dye = false,
        slots = slots,
        bundles = bundles,
        paid = 0,
        strikes = 0,
        worker = nil,
        lastAct = os.time(),
        openedBy = Robbery.identity(source),
    }
    machines[machine.id] = machine
    Robbery.stampCooldown(source)
    startSweep()
    return machine
end

function Robbery.finish(machine)
    machine.endedAt = machine.endedAt or os.time()
    if machine.repairAt then return end
    machine.repairAt = os.time() + Config.Cooldown.repairMinutes * 60
end

function Robbery.tripAlarm(source, machine)
    if machine.alarmEnds and machine.alarmEnds > os.time() then return end
    machine.alarmEnds = os.time() + Config.Cassette.alarmSeconds
    Robbery.alert(source, machine, 'alarm')
end

function Robbery.kill(source, machine, why)
    machine.stage = 'dead'
    Robbery.finish(machine)
    Robbery.audit(source, 'machine dead', machine, why)
end

function Robbery.strike(source, machine, why)
    machine.strikes = machine.strikes + 1
    if machine.strikes >= Config.Strikes and machine.stage ~= 'dead' and machine.stage ~= 'empty' then
        Robbery.tripAlarm(source, machine)
        Robbery.kill(source, machine, ('locked down after %d strikes (%s)'):format(machine.strikes, why))
        return true
    end
    return false
end

local function loopClosed(machine)
    if jumperBetween(machine, 'loop', 'loop') then return true end
    if machine.drawer then return false end
    for _, wire in ipairs(wireOf(machine, 'loop')) do
        if machine.cut[wire] then return false end
    end
    return true
end

function Robbery.checkLoop(source, machine)
    if loopClosed(machine) then return false end
    Robbery.tripAlarm(source, machine)
    return true
end

function Robbery.reading(machine, wire)
    if machine.cut[wire] or machine.unpowered then return 'dead' end
    return READING[machine.roles[wire]]
end

function Robbery.cut(source, machine, wire)
    machine.cut[wire] = true
    local role = machine.roles[wire]
    if role == 'mains' then
        machine.unpowered = true
        local locked = Robbery.strike(source, machine, 'cut the mains')
        if not locked and not machine.bolt then Robbery.kill(source, machine, 'mains cut before the bolt fired') end
        return 'shock'
    end
    if role == 'coil' then
        if not machine.bolt then
            Robbery.kill(source, machine, 'bolt coil cut')
            return 'bricked'
        end
        return 'none'
    end
    if role == 'loop' then
        if Robbery.checkLoop(source, machine) then return 'alarm' end
        return 'none'
    end
    if role == 'tamper' then
        machine.tamperCut = true
        return 'safe'
    end
    return 'none'
end

function Robbery.jump(source, machine, a, b)
    local roleA, roleB = machine.roles[a], machine.roles[b]
    local function pair(x, y) return (roleA == x and roleB == y) or (roleA == y and roleB == x) end
    if pair('coil', 'mains') then
        machine.jumpers[#machine.jumpers + 1] = { a, b }
        machine.bolt = true
        machine.stage = 'cassette'
        machine.stageAt = GetGameTimer()
        return 'bolt'
    end
    if roleA == 'loop' and roleB == 'loop' then
        machine.jumpers[#machine.jumpers + 1] = { a, b }
        return 'bypass'
    end
    if pair('mains', 'loop') then
        Robbery.tripAlarm(source, machine)
        Robbery.strike(source, machine, 'mains into the alarm loop')
        return 'alarm'
    end
    if pair('mains', 'tamper') then
        machine.dye = true
        Robbery.strike(source, machine, 'mains into the tamper line')
        return 'dye'
    end
    if pair('mains', 'dead') then
        Robbery.strike(source, machine, 'dead short')
        return 'short'
    end
    machine.jumpers[#machine.jumpers + 1] = { a, b }
    return 'none'
end

function Robbery.unjump(source, machine, index)
    table.remove(machine.jumpers, index)
    if Robbery.checkLoop(source, machine) then return 'alarm' end
    return 'none'
end

function Robbery.pull(source, machine)
    machine.drawer = true
    local alarm = Robbery.checkLoop(source, machine)
    local dye = false
    if not machine.tamperCut and not machine.dye then
        machine.dye = true
        dye = true
    end
    return alarm, dye
end

function Robbery.slotReachable(machine, slot)
    if not machine.slots[slot] then return false end
    local above = slot - CxAtmRob.SlotsPerLayer
    while above >= 1 do
        if machine.slots[above] then return false end
        above = above - CxAtmRob.SlotsPerLayer
    end
    return true
end

function Robbery.remaining(machine)
    local left = 0
    for i = 1, CxAtmRob.SlotCount do
        if machine.slots[i] then left = left + 1 end
    end
    return left
end

function Robbery.release(source)
    local id = working[source]
    if not id then return end
    working[source] = nil
    local machine = machines[id]
    if not machine or machine.worker ~= source then return end
    machine.worker = nil
    machine.idleSince = os.time()
    local untouched = machine.stage == 'door' and machine.strikes == 0 and not (machine.pry[1] or machine.pry[2] or machine.pry[3])
        and machine.openedBy == Robbery.identity(source)
    if untouched then
        machines[id] = nil
        cooldownUntil[machine.openedBy] = nil
        Robbery.broadcast(machine, true)
        return
    end
    Robbery.broadcast(machine)
end

AddEventHandler('playerDropped', function()
    Robbery.release(source)
end)

AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    src = tonumber(src) or source
    if not src or not working[src] then return end
    TriggerClientEvent('cortex-atmrobbery:client:kicked', src, working[src])
    Robbery.release(src)
end)
