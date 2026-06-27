local kind = require("lib.ui.layout.kind")

local M = {}

M.Curve = {
    Linear  = kind.Set({ name = "Linear"  }, "TweenCurve"),
    Quad    = kind.Set({ name = "Quad"    }, "TweenCurve"),
    Cubic   = kind.Set({ name = "Cubic"   }, "TweenCurve"),
    Sine    = kind.Set({ name = "Sine"    }, "TweenCurve"),
    Expo    = kind.Set({ name = "Expo"    }, "TweenCurve"),
    Back    = kind.Set({ name = "Back"    }, "TweenCurve"),
    Elastic = kind.Set({ name = "Elastic" }, "TweenCurve"),
    Bounce  = kind.Set({ name = "Bounce"  }, "TweenCurve"),
}

M.Mode = {
    In    = kind.Set({ name = "In"    }, "TweenMode"),
    Out   = kind.Set({ name = "Out"   }, "TweenMode"),
    InOut = kind.Set({ name = "InOut" }, "TweenMode"),
    OutIn = kind.Set({ name = "OutIn" }, "TweenMode"),
}

local function bounce_out(t)
    local d1, r = 2.75, 7.5625
    if t < 1 / d1 then
        return r * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return r * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return r * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return r * t * t + 0.984375
    end
end

local bases = {
    Linear  = function(t) return t end,
    Quad    = function(t) return t * t end,
    Cubic   = function(t) return t * t * t end,
    Sine    = function(t) return 1 - math.cos(t * math.pi / 2) end,
    Expo    = function(t)
        if t == 0 then return 0 end
        return 2 ^ (10 * (t - 1))
    end,
    Back    = function(t)
        local c = 1.70158
        return t * t * ((c + 1) * t - c)
    end,
    Elastic = function(t)
        if t == 0 then return 0 end
        if t == 1 then return 1 end
        return -(2 ^ (10 * (t - 1))) * math.sin((t - 1.1) * (2 * math.pi / 0.4))
    end,
    Bounce  = function(t) return 1 - bounce_out(1 - t) end,
}

local function apply_mode(f, mode)
    if mode == "In" then
        return f
    elseif mode == "Out" then
        return function(t) return 1 - f(1 - t) end
    elseif mode == "InOut" then
        return function(t)
            if t < 0.5 then return f(2 * t) / 2
            else return 1 - f(2 - 2 * t) / 2 end
        end
    elseif mode == "OutIn" then
        return function(t)
            if t < 0.5 then return (1 - f(1 - 2 * t)) / 2
            else return (f(2 * t - 1) + 1) / 2 end
        end
    end
end

function M.new(curve, mode)
    kind.Check(curve, "TweenCurve")
    kind.Check(mode, "TweenMode")
    local f = apply_mode(bases[curve.name], mode.name)
    return function(from, to, duration, current)
        local t = math.max(0, math.min(current, duration)) / duration
        if t <= 0 then return from end
        if t >= 1 then return to end
        return from + (to - from) * f(t)
    end
end

return M
