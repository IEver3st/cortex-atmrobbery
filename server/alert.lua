Robbery = Robbery or {}

local function playerName(source)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    if ok and player and player.PlayerData then
        local info = player.PlayerData.charinfo or {}
        return ('%s %s (%s)'):format(info.firstname or '?', info.lastname or '?', player.PlayerData.citizenid or '?')
    end
    return GetPlayerName(source) or ('player %s'):format(source)
end

function Robbery.identity(source)
    return GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license') or ('src:%s'):format(source)
end

function Robbery.restrained(source)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    if not ok or not player or not player.PlayerData then return false end
    local meta = player.PlayerData.metadata or {}
    return meta.isdead or meta.inlaststand or meta.ishandcuffed or false
end

function Robbery.policeOnDuty()
    local ok, count = pcall(function() return exports.qbx_core:GetDutyCountType(Config.Police.jobType) end)
    return ok and tonumber(count) or 0
end

function Robbery.audit(source, action, machine, detail)
    local who = source and playerName(source) or 'system'
    local where = machine and ('#%d %s at %.1f, %.1f, %.1f'):format(machine.id, machine.model, machine.coords.x, machine.coords.y, machine.coords.z) or '-'
    local line = ('%s | %s | %s%s'):format(who, action, where, detail and (' | ' .. detail) or '')
    print(('^5[cortex-atmrobbery]^7 %s'):format(line))
    local hook = GetConvar('cortex_atmrobbery_webhook', '')
    if hook == '' then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({ username = 'Cortex ATM Robbery', content = line:sub(1, 1900) }),
        { ['Content-Type'] = 'application/json' })
end

function Robbery.alert(source, machine, kind)
    local now = os.time()
    if machine.alertedAt and machine.alertedAt[kind] and now - machine.alertedAt[kind] < 60 then return end
    machine.alertedAt = machine.alertedAt or {}
    machine.alertedAt[kind] = now
    local data = {
        kind = kind,
        coords = vec3(machine.coords.x, machine.coords.y, machine.coords.z),
        machine = L(CxAtmRob.Machines[machine.model].label),
    }
    local ok, problem = pcall(Config.Police.send, source, data)
    if not ok then print(('^3[cortex-atmrobbery]^7 Config.Police.send failed: %s'):format(problem)) end
    Robbery.audit(source, kind == 'alarm' and 'alarm' or 'witness report', machine)
end
