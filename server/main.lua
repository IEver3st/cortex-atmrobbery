local machines, working = Robbery.machines, Robbery.working

local RATE = { begin = 1500, pry = 450, strike = 400, screw = 500, probe = 350, cut = 350, jump = 350, unjump = 350, pull = 500, grab = 450, sync = 4000 }
local KIT = { screw = true, probe = true, cut = true, jump = true, unjump = true, pull = true }
local STAGE_MIN_MS = {
    door = math.floor(Config.Pry.holdMs * CxAtmRob.PryPoints * 0.6),
    plate = math.floor(Config.Screws.turns / Config.Screws.maxTurnsPerSecond * CxAtmRob.ScrewCount * 600),
    wires = 5000,
}
local lastAction = {}

local function whole(value, low, high)
    local n = math.tointeger(value)
    if not n or n < low or n > high then return nil end
    return n
end

local function vector(value)
    if type(value) ~= 'table' and type(value) ~= 'vector3' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return vec3(x + 0.0, y + 0.0, z + 0.0)
end

local function fit(source)
    local ped = GetPlayerPed(source)
    if ped == 0 or GetEntityHealth(ped) <= 0 then return nil end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil end
    if Robbery.restrained(source) then return nil end
    return ped
end

local function limited(source, action)
    local now = GetGameTimer()
    lastAction[source] = lastAction[source] or {}
    local last = lastAction[source][action]
    if last and now - last < RATE[action] then return true end
    lastAction[source][action] = now
    return false
end

local function session(source, id, action)
    id = math.tointeger(id)
    local machine = id and machines[id]
    if not machine or machine.worker ~= source or working[source] ~= id then return nil end
    local ped = fit(source)
    if not ped then return nil end
    if GetPlayerRoutingBucket(source) ~= machine.bucket then return nil end
    if #(GetEntityCoords(ped) - machine.at) > CxAtmRob.Reach then return nil end
    if limited(source, action) then return nil end
    if KIT[action] and not Robbery.hasTool(source, 'kit') then return nil end
    machine.lastAct = os.time()
    return machine
end

local function enterStage(machine, stage)
    machine.stage = stage
    machine.stageAt = GetGameTimer()
end

lib.callback.register('cortex-atmrobbery:begin', function(source, model, coords, rot)
    if type(model) ~= 'string' or not CxAtmRob.Machines[model] then return { ok = false, error = 'invalid' } end
    local at, turn = vector(coords), vector(rot)
    if not at or not turn then return { ok = false, error = 'invalid' } end
    if limited(source, 'begin') then return { ok = false, error = 'busy' } end
    local ped = fit(source)
    if not ped then return { ok = false, error = 'unfit' } end
    if working[source] then return { ok = false, error = 'busy' } end
    local heading
    at, heading = Robbery.locate(model, at)
    if not at then return { ok = false, error = 'invalid' } end
    turn = vector3(0.0, 0.0, (heading or turn.z) + 0.0)
    if #(GetEntityCoords(ped) - at) > CxAtmRob.Reach + 0.5 then return { ok = false, error = 'far' } end

    local machine = Robbery.find(GetPlayerRoutingBucket(source), at)
    local fresh = not machine or machine.openedBy ~= Robbery.identity(source)
    if machine then
        if machine.stage == 'empty' or machine.stage == 'dead' then return { ok = false, error = 'spent' } end
        if machine.worker and machine.worker ~= source then return { ok = false, error = 'taken' } end
        if machine.model ~= model then return { ok = false, error = 'invalid' } end
    end
    if fresh then
        local left = Robbery.cooldownLeft(source)
        if left > 0 then return { ok = false, error = 'cooldown', minutes = math.ceil(left / 60) } end
        if Config.Police.required > 0 and Robbery.policeOnDuty() < Config.Police.required then
            return { ok = false, error = 'police', needed = Config.Police.required }
        end
    end

    local stage = machine and machine.stage or 'door'
    if stage == 'door' and not Robbery.hasTool(source, 'crowbar') then
        return { ok = false, error = 'tool', tool = Robbery.toolLabel('crowbar') }
    end
    if not Robbery.hasTool(source, 'kit') then return { ok = false, error = 'tool', tool = Robbery.toolLabel('kit') } end

    if not machine then
        machine = Robbery.create(source, model, at, turn)
        machine.stageAt = GetGameTimer()
        Robbery.audit(source, 'opened', machine, ('%d bundles'):format(machine.bundles))
    elseif fresh then
        machine.openedBy = Robbery.identity(source)
        Robbery.stampCooldown(source)
        Robbery.audit(source, 'took over', machine, machine.stage)
    end
    machine.worker = source
    machine.idleSince = nil
    machine.repairAt = nil
    machine.lastAct = os.time()
    working[source] = machine.id
    Robbery.broadcast(machine)
    return { ok = true, machine = Robbery.snapshot(machine) }
end)

lib.callback.register('cortex-atmrobbery:pry', function(source, id, point)
    local machine = session(source, id, 'pry')
    point = whole(point, 1, CxAtmRob.PryPoints)
    if not machine or not point or machine.stage ~= 'door' or machine.pry[point] then return false end
    if not Robbery.hasTool(source, 'crowbar') then return false end
    local done = 0
    for i = 1, CxAtmRob.PryPoints do
        if machine.pry[i] then done = done + 1 end
    end
    if done == CxAtmRob.PryPoints - 1 and GetGameTimer() - machine.stageAt < STAGE_MIN_MS.door then return false end
    machine.pry[point] = true
    if done + 1 == CxAtmRob.PryPoints then
        enterStage(machine, 'plate')
        if math.random() < Config.Police.witnessChance then Robbery.alert(source, machine, 'witness') end
    end
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-atmrobbery:strike', function(source, id, why)
    local machine = session(source, id, 'strike')
    if not machine or machine.stage == 'empty' or machine.stage == 'dead' then return false end
    local reason = why == 'slip' and 'bar slipped' or why == 'cam' and 'driver cammed out' or 'slip'
    local locked = Robbery.strike(source, machine, reason)
    Robbery.effect(machine, locked and 'lockdown' or 'clang')
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-atmrobbery:screw', function(source, id, screw)
    local machine = session(source, id, 'screw')
    screw = whole(screw, 1, CxAtmRob.ScrewCount)
    if not machine or not screw or machine.stage ~= 'plate' or machine.screws[screw] then return false end
    local out = 0
    for i = 1, CxAtmRob.ScrewCount do
        if machine.screws[i] then out = out + 1 end
    end
    if out == CxAtmRob.ScrewCount - 1 and GetGameTimer() - machine.stageAt < STAGE_MIN_MS.plate then return false end
    machine.screws[screw] = true
    if out + 1 == CxAtmRob.ScrewCount then enterStage(machine, 'wires') end
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-atmrobbery:probe', function(source, id, wire)
    local machine = session(source, id, 'probe')
    wire = whole(wire, 1, CxAtmRob.WireCount)
    if not machine or not wire then return nil end
    if machine.stage ~= 'wires' and machine.stage ~= 'cassette' and machine.stage ~= 'dead' then return nil end
    return Robbery.reading(machine, wire)
end)

lib.callback.register('cortex-atmrobbery:cut', function(source, id, wire)
    local machine = session(source, id, 'cut')
    wire = whole(wire, 1, CxAtmRob.WireCount)
    if not machine or not wire or machine.cut[wire] then return nil end
    if machine.stage ~= 'wires' and machine.stage ~= 'cassette' then return nil end
    local effect = Robbery.cut(source, machine, wire)
    Robbery.effect(machine, 'cut', { wire = wire, effect = effect })
    Robbery.broadcast(machine)
    return effect
end)

lib.callback.register('cortex-atmrobbery:jump', function(source, id, a, b)
    local machine = session(source, id, 'jump')
    a, b = whole(a, 1, CxAtmRob.WireCount), whole(b, 1, CxAtmRob.WireCount)
    if not machine or not a or not b or a == b then return nil end
    if machine.stage ~= 'wires' and machine.stage ~= 'cassette' then return nil end
    if machine.cut[a] or machine.cut[b] then return 'cutwire' end
    if #machine.jumpers >= Config.Wires.jumperLeads then return 'none_left' end
    for _, jumper in ipairs(machine.jumpers) do
        if jumper[1] == a or jumper[2] == a or jumper[1] == b or jumper[2] == b then return 'occupied' end
    end
    if a > b then a, b = b, a end
    if Robbery.wouldBolt(machine, a, b) and GetGameTimer() - machine.stageAt < STAGE_MIN_MS.wires then return 'settle' end
    local effect = Robbery.jump(source, machine, a, b)
    Robbery.effect(machine, 'jump', { a = a, b = b, effect = effect })
    Robbery.broadcast(machine)
    return effect
end)

lib.callback.register('cortex-atmrobbery:unjump', function(source, id, index)
    local machine = session(source, id, 'unjump')
    index = machine and whole(index, 1, #machine.jumpers)
    if not machine or not index then return nil end
    if machine.stage ~= 'wires' and machine.stage ~= 'cassette' then return nil end
    local effect = Robbery.unjump(source, machine, index)
    if effect == 'alarm' then Robbery.effect(machine, 'alarm') end
    Robbery.broadcast(machine)
    return effect
end)

lib.callback.register('cortex-atmrobbery:pull', function(source, id)
    local machine = session(source, id, 'pull')
    if not machine or machine.stage ~= 'cassette' or machine.drawer then return nil end
    local alarm, dye = Robbery.pull(source, machine)
    Robbery.effect(machine, 'drawer', { alarm = alarm, dye = dye })
    Robbery.broadcast(machine)
    return { alarm = alarm, dye = dye }
end)

lib.callback.register('cortex-atmrobbery:grab', function(source, id, slot)
    local machine = session(source, id, 'grab')
    slot = whole(slot, 1, CxAtmRob.SlotCount)
    if not machine or not slot or machine.stage ~= 'cassette' or not machine.drawer then return { ok = false } end
    if not Robbery.slotReachable(machine, slot) then return { ok = false } end
    machine.slots[slot] = false
    local paid, amount, keep = Robbery.payBundle(source, machine.dye)
    if Robbery.machines[machine.id] ~= machine or machine.stage ~= 'cassette' then
        if paid then Robbery.audit(source, 'late bundle', machine, ('$%d after the machine closed'):format(amount)) end
        return { ok = paid == true, amount = paid and amount or nil }
    end
    if not paid and not keep then
        machine.slots[slot] = true
        return { ok = false, error = amount }
    end
    if paid then machine.paid = machine.paid + amount end
    local left = Robbery.remaining(machine)
    if not paid then
        if left == 0 then
            machine.stage = 'empty'
            Robbery.finish(machine)
            Robbery.audit(source, 'emptied', machine, ('$%d over %d bundles, last payout unconfirmed'):format(machine.paid, machine.bundles))
            Robbery.broadcast(machine)
        end
        return { ok = false, error = amount }
    end
    if left == 0 then
        machine.stage = 'empty'
        Robbery.finish(machine)
        Robbery.audit(source, 'emptied', machine, ('$%d over %d bundles%s'):format(machine.paid, machine.bundles, machine.dye and ', dyed' or ''))
    end
    Robbery.effect(machine, 'grab', { slot = slot })
    Robbery.broadcast(machine)
    return { ok = true, amount = amount, left = left, total = machine.paid }
end)

RegisterNetEvent('cortex-atmrobbery:server:leave', function()
    Robbery.release(source)
end)

RegisterNetEvent('cortex-atmrobbery:server:sync', function()
    local src = source
    if limited(src, 'sync') then return end
    Robbery.sendAll(src)
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
