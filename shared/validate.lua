local function want(path, value, expected, default)
    if type(value) == expected then return value end
    print(('^3[cortex-atmrobbery]^7 config.lua: %s expected %s, got %s; using %s'):format(path, expected, type(value), tostring(default)))
    return default
end

local function section(name)
    if type(Config[name]) ~= 'table' then
        if Config[name] ~= nil then
            print(('^3[cortex-atmrobbery]^7 config.lua: Config.%s expected table, got %s; using defaults'):format(name, type(Config[name])))
        end
        Config[name] = {}
    end
    return Config[name]
end

local function number(path, tbl, key, default, low, high)
    local value = want(path, tbl[key], 'number', default)
    if value < low or value > high then
        print(('^3[cortex-atmrobbery]^7 config.lua: %s must be %s to %s, got %s; using %s'):format(path, low, high, value, default))
        value = default
    end
    tbl[key] = value
end

local function itemName(path, tbl, key, default)
    if tbl[key] == false then return end
    tbl[key] = want(path, tbl[key], 'string', default)
end

Config.Locale = want('Config.Locale', Config.Locale, 'string', 'en')
Config.Strikes = want('Config.Strikes', Config.Strikes, 'number', 3)
if Config.Strikes < 1 or Config.Strikes > 6 or Config.Strikes ~= math.floor(Config.Strikes) then
    print(('^3[cortex-atmrobbery]^7 config.lua: Config.Strikes must be a whole number from 1 to 6, got %s; using 3'):format(Config.Strikes))
    Config.Strikes = 3
end

local keys = section('Keys')
keys.start = want('Config.Keys.start', keys.start, 'string', 'G')

local tools = section('Tools')
itemName('Config.Tools.crowbar', tools, 'crowbar', 'WEAPON_CROWBAR')
itemName('Config.Tools.kit', tools, 'kit', 'atm_toolkit')

local police = section('Police')
number('Config.Police.required', police, 'required', 0, 0, 64)
police.jobType = want('Config.Police.jobType', police.jobType, 'string', 'leo')
number('Config.Police.witnessChance', police, 'witnessChance', 0.35, 0, 1)
police.send = want('Config.Police.send', police.send, 'function', function() end)

local cooldown = section('Cooldown')
number('Config.Cooldown.playerMinutes', cooldown, 'playerMinutes', 20, 0, 1440)
number('Config.Cooldown.repairMinutes', cooldown, 'repairMinutes', 30, 1, 1440)
number('Config.Cooldown.abandonMinutes', cooldown, 'abandonMinutes', 5, 1, 120)

local pry = section('Pry')
if type(pry.zone) ~= 'table' or type(pry.zone[1]) ~= 'number' or type(pry.zone[2]) ~= 'number'
    or pry.zone[1] < 0.2 or pry.zone[2] > 0.92 or pry.zone[2] - pry.zone[1] < 0.08 then
    if pry.zone ~= nil then
        print('^3[cortex-atmrobbery]^7 config.lua: Config.Pry.zone expected { low, high } inside 0.2 to 0.92 and at least 0.08 apart; using { 0.60, 0.82 }')
    end
    pry.zone = { 0.60, 0.82 }
end
number('Config.Pry.holdMs', pry, 'holdMs', 900, 200, 5000)
number('Config.Pry.slipAt', pry, 'slipAt', 0.96, pry.zone[2] + 0.04, 1.0)

local screws = section('Screws')
number('Config.Screws.turns', screws, 'turns', 2.5, 0.5, 12)
number('Config.Screws.maxTurnsPerSecond', screws, 'maxTurnsPerSecond', 2.6, 0.5, 20)

local wires = section('Wires')
number('Config.Wires.jumperLeads', wires, 'jumperLeads', 2, 2, 3)
number('Config.Wires.shockDamage', wires, 'shockDamage', 25, 0, 100)

local cassette = section('Cassette')
if type(cassette.bundles) ~= 'table' or type(cassette.bundles[1]) ~= 'number' or type(cassette.bundles[2]) ~= 'number'
    or cassette.bundles[1] < 1 or cassette.bundles[2] > 18 or cassette.bundles[1] > cassette.bundles[2] then
    if cassette.bundles ~= nil then
        print('^3[cortex-atmrobbery]^7 config.lua: Config.Cassette.bundles expected { min, max } from 1 to 18; using { 4, 10 }')
    end
    cassette.bundles = { 4, 10 }
end
cassette.bundles[1], cassette.bundles[2] = math.floor(cassette.bundles[1]), math.floor(cassette.bundles[2])
number('Config.Cassette.alarmSeconds', cassette, 'alarmSeconds', 45, 5, 600)

local reward = section('Reward')
reward.item = want('Config.Reward.item', reward.item, 'string', 'black_money')
number('Config.Reward.perBundle', reward, 'perBundle', 2000, 1, 10000000)
number('Config.Reward.dyedShare', reward, 'dyedShare', 0.3, 0, 1)

local camera = section('Camera')
number('Config.Camera.fov', camera, 'fov', 38.0, 20, 70)
number('Config.Camera.distance', camera, 'distance', 0.50, 0.35, 0.9)
camera.workLight = want('Config.Camera.workLight', camera.workLight, 'boolean', true)
