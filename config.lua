Config = {}

Config.Locale = 'en'

Config.Keys = {
    start = 'G',
}

Config.Tools = {
    crowbar = 'WEAPON_CROWBAR',
    kit = 'atm_toolkit',
}

Config.Police = {
    required = 0,
    jobType = 'leo',
    witnessChance = 0.35,
    send = function(source, data)
        if GetResourceState('cortex-dispatch') == 'started' then
            exports['cortex-dispatch']:CustomAlert({
                code = '10-90',
                title = data.kind == 'alarm' and 'ATM alarm' or 'ATM tampering',
                message = data.kind == 'alarm' and ('Tamper alarm from a %s.'):format(data.machine)
                    or ('Someone is prying at a %s.'):format(data.machine),
                priority = data.kind == 'alarm' and 1 or 2,
                coords = data.coords,
                category = 'robbery',
                jobs = { 'leo' },
            })
            return
        end
        TriggerEvent('police:server:policeAlert', data.kind == 'alarm' and 'ATM alarm' or 'ATM tampering', nil, source)
    end,
}

Config.ExtraAtms = {
}

Config.Cooldown = {
    playerMinutes = 20,
    repairMinutes = 30,
    abandonMinutes = 5,
}

Config.Strikes = 3

Config.Pry = {
    zone = { 0.60, 0.82 },
    holdMs = 900,
    slipAt = 0.96,
}

Config.Screws = {
    turns = 2.5,
    maxTurnsPerSecond = 2.6,
}

Config.Wires = {
    jumperLeads = 2,
    shockDamage = 25,
}

Config.Cassette = {
    bundles = { 4, 10 },
    alarmSeconds = 45,
}

Config.Reward = {
    item = 'black_money',
    perBundle = 2000,
    dyedShare = 0.3,
}

Config.Camera = {
    fov = 38.0,
    distance = 0.50,
    workLight = true,
}
