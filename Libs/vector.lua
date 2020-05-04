----------------------------------------------------------------------------------------------------------------------
-- Vector Functions
----------------------------------------------------------------------------------------------------------------------

VFS.Include("LuaUI/Widgets/Libs/math.lua")
local sqrt = math.sqrt
local atan2 = math.atan2

function v_add(a, b)
    if type(a) == "number" and type(b) == "table" then
        return {
            a + b[1],
            a + b[2],
            a + b[3],
        }
    elseif type(a) == "table" and type(b) == "number" then
        return {
            a[1] + b,
            a[2] + b,
            a[3] + b,
        }
    elseif type(a) == "table" and type(b) == "table" then
        return {
            a[1] + b[1],
            a[2] + b[2],
            a[3] + b[3],
        }
    else
        return a + b
    end
end

function v_sub(a, b)
    if type(a) == "number" and type(b) == "table" then
        return {
            a - b[1],
            a - b[2],
            a - b[3],
        }
    elseif type(a) == "table" and type(b) == "number" then
        return {
            a[1] - b,
            a[2] - b,
            a[3] - b,
        }
    elseif type(a) == "table" and type(b) == "table" then
        return {
            a[1] - b[1],
            a[2] - b[2],
            a[3] - b[3],
        }
    else
        return a - b
    end
end

function v_mul(a, b)
    if type(a) == "number" and type(b) == "table" then
        return {
            a * b[1],
            a * b[2],
            a * b[3],
        }
    elseif type(a) == "table" and type(b) == "number" then
        return {
            a[1] * b,
            a[2] * b,
            a[3] * b,
        }
    else
        return a * b
    end
end

function v_div(a, b)
    if type(a) == "number" and type(b) == "table" then
        return {
            a / b[1],
            a / b[2],
            a / b[3],
        }
    elseif type(a) == "table" and type(b) == "number" then
        return {
            a[1] / b,
            a[2] / b,
            a[3] / b,
        }
    else
        return a * b
    end
end

function v_pow(a, b)
    if type(a) == "number" and type(b) == "table" then
        return {
            a ^ b[1],
            a ^ b[2],
            a ^ b[3],
        }
    elseif type(a) == "table" and type(b) == "number" then
        return {
            a[1] ^ b,
            a[2] ^ b,
            a[3] ^ b,
        }
    elseif type(a) == "table" and type(b) == "table" then
        return {
            a[1] ^ b[1],
            a[2] ^ b[2],
            a[3] ^ b[3],
        }
    else
        return a ^ b
    end
end

function v_norm(a)
    return sqrt(a[1] ^ 2 + a[2] ^ 2 + a[3] ^ 2)
end

function v_normalize(x)
    return v_div(x, v_norm(x))
end

function v_atan(a, b)
    return atan2((a[1] - b[1]), (a[3] - b[3]))
end

--- Get a normalized orthogonal vector
function v_normed_orth(a)
    --local g = math.sign(a[2])
    --if g == 0 then g = 1 end
    --local h = a[2] + g;
    --return { g - (a[1] ^ 2) / h, -a[1] * a[2] / h, -a[1] }
    local res = { a[3] - a[2], a[1], a[1] }
    if res[1] == 0 and res[2] == 0 and res[3] == 0 then
        res = { a[2], a[2], -a[1] - a[3] }
    end
    res = v_normalize(res)
    return res
end
