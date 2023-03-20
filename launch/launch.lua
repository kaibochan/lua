local t_hIter = 5
local v_y0Iter = 5

local v_y0Final
local v_x0Final
local t_hFinal

function v_y(t, v_y0)
    return v_y0 * math.pow(c_dy, t) - g * c_dy * t
end

function a_y(t, v_y0)
    return v_y0 * lnc_dy * math.pow(c_dy, t) - g * c_dy
end

function t_hNext(t_h, v_y0)
    return t_h - v_y(t_h, v_y0) / a_y(t_h, v_y0)
end

function find_t_h(v_y0, iter)
    local t_h = 0
    
    for i=1, iter, 1 do
        t_h = t_hNext(t_h, v_y0)
    end
    
    return t_h
end

function v_y0Next(h, t_h)
    return lnc_dy * ((h + 0.5 * g * c_dy * t_h * t_h) / (math.pow(c_dy, t_h) - 1))
end

function find_v_y0(h, iter)
    local v_y0 = v_y00
    local t_h
    
    for i=1, iter, 1 do
        t_h = find_t_h(v_y0, t_hIter)
        v_y0 = v_y0Next(h, t_h)
    end
    
    t_hFinal = find_t_h(v_y0, t_hIter)
    
    return v_y0
end

function find_v_x0(d, t_h)
    return (d * lnc_dx) / (math.pow(c_dx, t_h) - 1)
end

function find_v(d, h)
    v_y0Final = find_v_y0(h, v_y0Iter)
    v_x0Final = find_v_x0(d, t_hFinal)
    
    return v_x0Final, v_y0Final
end

find_v(arg[1], arg[2])
print("Velocity x and y in blocks per game tick:\n"..v_x0Final..", "..v_y0Final)
print("in blocks per second:\n"..(v_x0Final * 20)..", "..(v_y0Final * 20))