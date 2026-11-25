Fx = {}

local HEAR = 45.0
local ALARM_HEAR = 90.0
local SPARK_ASSET, SPARK_FX = 'core', 'ent_brk_sparking_wires'
local SMOKE_ASSET, SMOKE_FX = 'core', 'exp_grd_grenade_smoke'

Fx.SOUNDS = {
    tick = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    tool = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    locked = { 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    bite = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    creak = { 'tumbler_turn', 'SAFE_CRACK_SOUNDSET' },
    pop = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    clang = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    plate = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    squeak = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    cam = { 'Pin_Bad', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    screwOut = { 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    probe = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    snip = { 'Pin_Centred', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    clip = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    unclip = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    spark = { 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    disarm = { 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    hum = { 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    bolt = { 'Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    grip = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    drawer = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    grab = { 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    dye = { 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    lockdown = { 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    alarm = { 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
}

local alarms = {}
local smokes = {}

local function heard(at, range)
    return #(GetFinalRenderedCamCoord() - at) <= range
end

function Fx.sound(name, at)
    local s = Fx.SOUNDS[name]
    if not s then return end
    if s.ui or not at then
        PlaySoundFrontend(-1, s[1], s[2], true)
        return
    end
    if not heard(at, HEAR) then return end
    PlaySoundFromCoord(-1, s[1], at.x, at.y, at.z, s[2], false, 20, false)
end

function Fx.frontend(name, set)
    PlaySoundFrontend(-1, name, set, true)
end

function Fx.sparks(at, scale)
    if not at or not Rob.loadPtfx(SPARK_ASSET) then return end
    UseParticleFxAsset(SPARK_ASSET)
    StartParticleFxNonLoopedAtCoord(SPARK_FX, at.x, at.y, at.z, 0.0, 0.0, 0.0, (scale or 0.35) + 0.0, false, false, false)
    Fx.sound('spark', at)
end

function Fx.dye(id, at)
    if smokes[id] or not at or not Rob.loadPtfx(SMOKE_ASSET) then return end
    UseParticleFxAsset(SMOKE_ASSET)
    local handle = StartParticleFxLoopedAtCoord(SMOKE_FX, at.x, at.y, at.z, 0.0, 0.0, 0.0, 0.25, false, false, false, false)
    if handle and handle ~= 0 then
        SetParticleFxLoopedColour(handle, 0.32, 0.22, 0.95, false)
        SetParticleFxLoopedAlpha(handle, 0.8)
        smokes[id] = handle
        SetTimeout(9000, function()
            if smokes[id] == handle then
                StopParticleFxLooped(handle, false)
                smokes[id] = nil
            end
        end)
    end
    Fx.sound('dye', at)
end

function Fx.alarm(id, at, seconds)
    if seconds <= 0 then
        alarms[id] = nil
        return
    end
    alarms[id] = { at = at, untilAt = GetGameTimer() + math.floor(seconds * 1000) }
end

function Fx.alarmOn(id)
    local a = alarms[id]
    return a ~= nil and GetGameTimer() < a.untilAt
end

function Fx.alarmLeft(id)
    local a = alarms[id]
    if not a then return 0 end
    return math.max(0, a.untilAt - GetGameTimer())
end

function Fx.forget(id)
    alarms[id] = nil
    if smokes[id] then
        StopParticleFxLooped(smokes[id], false)
        smokes[id] = nil
    end
end

CreateThread(function()
    local s = Fx.SOUNDS.alarm
    while true do
        local now = GetGameTimer()
        local any = false
        for id, a in pairs(alarms) do
            if now >= a.untilAt then
                alarms[id] = nil
            else
                any = true
                if heard(a.at, ALARM_HEAR) then
                    PlaySoundFromCoord(-1, s[1], a.at.x, a.at.y, a.at.z + 0.9, s[2], false, 60, false)
                end
            end
        end
        Wait(any and 420 or 1000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    for _, handle in pairs(smokes) do pcall(StopParticleFxLooped, handle, false) end
end)
