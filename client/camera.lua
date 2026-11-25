Camera = {}

local VIEWS = {
    door = { pos = vector3(0.04, -0.66, 0.10), target = vector3(0.0, 0.0, 0.0) },
    plate = { pos = vector3(0.0, -0.54, 0.07), target = vector3(0.0, 0.01, 0.0) },
    wires = { pos = vector3(-0.015, -0.40, 0.085), target = vector3(-0.02, 0.05, 0.025) },
    cassette = { pos = vector3(0.0, -0.50, 0.20), target = vector3(0.0, -0.10, -0.07) },
    done = { pos = vector3(0.0, -0.62, 0.16), target = vector3(0.0, -0.06, -0.04) },
}
local SWAY = 0.010
local GLIDE_MS = 650

local cam
local rec
local current = { pos = nil, target = nil, fov = nil }
local glide
local sway = { x = 0.0, y = 0.0, gx = 0.0, gy = 0.0 }
local light = true

function Camera.setLight(on) light = on == true end

local function reduced()
    local ok, value = pcall(lib.getSetting, 'reducedMotion')
    return ok and value == true
end

local function viewFor(stage)
    if stage == 'door' or stage == 'plate' or stage == 'wires' or stage == 'cassette' then return VIEWS[stage] end
    return VIEWS.done
end

local function scaled(view)
    local d = Config.Camera.distance / 0.50
    local pos = vector3(view.pos.x, view.target.y + (view.pos.y - view.target.y) * d, view.pos.z)
    return pos, view.target
end

local function worldOf(localPos)
    return World.point(rec, localPos.x, localPos.y, localPos.z)
end

local function apply(pos, target, fov)
    if not cam then return end
    local view = Geo.setView(pos, target, fov)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, view.pitch, 0.0, view.yaw, 2)
    SetCamFov(cam, fov)
end

function Camera.active() return cam ~= nil end

function Camera.enter(r, stage)
    Camera.exit(true)
    rec = r
    local lp, lt = scaled(viewFor(stage))
    local pos, target = worldOf(lp), worldOf(lt)
    local fov = Config.Camera.fov + 0.0
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov, false, 2)
    current = { pos = pos, target = target, fov = fov, localPos = lp, localTarget = lt }
    apply(pos, target, fov)
    SetCamActive(cam, true)
    local ease = not reduced()
    RenderScriptCams(true, ease, ease and 700 or 0, true, false)
    Camera.readyAt = GetGameTimer() + (ease and 760 or 60)
    Camera.loop()
end

function Camera.stage(stage)
    if not cam then return end
    local lp, lt = scaled(viewFor(stage))
    glide = { started = GetGameTimer(), ms = reduced() and 0 or GLIDE_MS, fromPos = current.localPos, fromTarget = current.localTarget, toPos = lp, toTarget = lt }
end

function Camera.focus(localPos, localTarget, ms)
    if not cam then return end
    glide = { started = GetGameTimer(), ms = reduced() and 0 or (ms or GLIDE_MS), fromPos = current.localPos, fromTarget = current.localTarget,
        toPos = localPos, toTarget = localTarget }
end

function Camera.moving() return glide ~= nil end

function Camera.sway(nx, ny)
    sway.gx = Geo.clamp((nx - 0.5) * 2.0, -1.0, 1.0)
    sway.gy = Geo.clamp((ny - 0.5) * 2.0, -1.0, 1.0)
end

function Camera.shake(kind, amount)
    if cam then ShakeCam(cam, kind or 'SMALL_EXPLOSION_SHAKE', (amount or 0.08) + 0.0) end
end

function Camera.loop()
    local mine = cam
    CreateThread(function()
        while cam == mine do
            local lp, lt = current.localPos, current.localTarget
            if glide then
                local t = glide.ms > 0 and Geo.clamp((GetGameTimer() - glide.started) / glide.ms, 0.0, 1.0) or 1.0
                local k = Geo.ease(t)
                lp = glide.fromPos + (glide.toPos - glide.fromPos) * k
                lt = glide.fromTarget + (glide.toTarget - glide.fromTarget) * k
                if t >= 1.0 then glide = nil end
                current.localPos, current.localTarget = lp, lt
            end
            local k = 1.0 - math.exp(-6.0 * GetFrameTime())
            sway.x = sway.x + (sway.gx - sway.x) * k
            sway.y = sway.y + (sway.gy - sway.y) * k
            local offset = reduced() and vector3(0.0, 0.0, 0.0) or vector3(sway.x * SWAY, 0.0, -sway.y * SWAY * 0.6)
            local pos, target = worldOf(lp + offset), worldOf(lt + offset * 0.35)
            current.pos, current.target = pos, target
            apply(pos, target, current.fov)
            SetEntityLocallyInvisible(PlayerPedId())
            HideHudAndRadarThisFrame()
            if light and Config.Camera.workLight then
                local above = pos + vector3(0.0, 0.0, 0.06)
                DrawLightWithRange(above.x, above.y, above.z, 255, 241, 224, 1.1, 1.6)
            end
            Wait(0)
        end
    end)
end

function Camera.exit(instant)
    if not cam then return end
    local old = cam
    cam, rec, glide = nil, nil, nil
    Geo.view = nil
    local ease = not instant and not reduced()
    RenderScriptCams(false, ease, ease and 600 or 0, true, false)
    if ease then
        SetTimeout(650, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    else
        DestroyCam(old, false)
    end
end

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource or not cam then return end
    pcall(RenderScriptCams, false, false, 0, true, false)
    pcall(DestroyCam, cam, false)
end)
