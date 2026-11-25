local machines = Robbery.machines

local function reply(source, text)
    if source == 0 then
        print(('[cortex-atmrobbery] %s'):format(text))
        return
    end
    TriggerClientEvent('chat:addMessage', source, { args = { 'ATM Robbery', text } })
end

local function describe(machine)
    local left = Robbery.remaining(machine)
    return ('#%d %s %s at %.1f, %.1f, %.1f | %d of %d bundles left | strikes %d%s%s'):format(machine.id, machine.model, machine.stage,
        machine.coords.x, machine.coords.y, machine.coords.z, left, machine.bundles, machine.strikes,
        machine.worker and (' | worked by ' .. machine.worker) or '', machine.dye and ' | dyed' or '')
end

local commands = {}

function commands.list(source)
    local count = 0
    for _, machine in pairs(machines) do
        count = count + 1
        reply(source, describe(machine))
    end
    if count == 0 then reply(source, 'No ATMs are broken into.') end
end

function commands.reset(source, target)
    if target == 'all' then
        local list = {}
        for _, machine in pairs(machines) do list[#list + 1] = machine end
        for _, machine in ipairs(list) do Robbery.remove(machine) end
        Robbery.audit(source ~= 0 and source or nil, 'admin reset', nil, ('%d machines'):format(#list))
        reply(source, ('Repaired %d ATMs.'):format(#list))
        return
    end
    local id = math.tointeger(tonumber(target))
    local machine = id and machines[id]
    if not machine then
        reply(source, 'Usage: /atmrob reset <id|all>  (see /atmrob list)')
        return
    end
    Robbery.remove(machine)
    Robbery.audit(source ~= 0 and source or nil, 'admin reset', machine)
    reply(source, ('Repaired ATM #%d.'):format(id))
end

function commands.cooldown(source, target)
    local player = math.tointeger(tonumber(target))
    if not player or not GetPlayerName(player) then
        reply(source, 'Usage: /atmrob cooldown <server id>')
        return
    end
    Robbery.clearCooldown(player)
    Robbery.audit(source ~= 0 and source or nil, 'admin cleared cooldown', nil, GetPlayerName(player))
    reply(source, ('Cleared the robbery cooldown for %s.'):format(GetPlayerName(player)))
end

RegisterCommand('atmrob', function(source, args)
    local run = commands[args[1] or '']
    if not run then
        reply(source, 'Usage: /atmrob list | reset <id|all> | cooldown <server id>')
        return
    end
    run(source, args[2])
end, true)
