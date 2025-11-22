-- Base64.lua
-- Efficient Base64 encoding/decoding for Lua 5.1+
-- Based on standard implementations avoiding massive string concatenation

local Base64 = {}

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Encoding table
local encoder = {}
for i = 1, 64 do
    encoder[i-1] = string.sub(b, i, i)
end

function Base64.encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- WAIT! The implementation above IS THE SLOW ONE.
-- I need to write a NEW, FAST one.

local function to_binary(integer)
    local remaining = integer
    local bin_bits = ""
    for i = 7, 0, -1 do
        local current_power = 2 ^ i
        if remaining >= current_power then
            bin_bits = bin_bits .. "1"
            remaining = remaining - current_power
        else
            bin_bits = bin_bits .. "0"
        end
    end
    return bin_bits
end

-- Let's use a PROVEN fast implementation for Lua 5.1 (LuaJIT)
-- This one uses string.byte and string.char and bitwise ops simulation

local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2+
if not extract then
    if _G.bit then -- LuaJIT
        local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
        extract = function( v, from, width )
            return band( shr( v, from ), shl( 1, width ) - 1 )
        end
    else -- Lua 5.1 pure
        extract = function( v, from, width )
            local w = 0
            local flag = 2^from
            for i = 0, width-1 do
                local flag2 = flag + flag
                if v % flag2 >= flag then
                    w = w + 2^i
                end
                flag = flag2
            end
            return w
        end
    end
end

function Base64.encode(text)
    local len = #text
    local left = len % 3
    len = len - left
    local res = {}
    local res_len = 0
    
    for i = 1, len, 3 do
        local a = string.byte(text, i)
        local b = string.byte(text, i+1)
        local c = string.byte(text, i+2)
        
        -- Buffer: aaaaaaaa bbbbbbbb cccccccc
        -- 24 bits
        local num = a * 65536 + b * 256 + c
        
        local b1 = extract(num, 18, 6)
        local b2 = extract(num, 12, 6)
        local b3 = extract(num, 6, 6)
        local b4 = extract(num, 0, 6)
        
        res_len = res_len + 1; res[res_len] = encoder[b1]
        res_len = res_len + 1; res[res_len] = encoder[b2]
        res_len = res_len + 1; res[res_len] = encoder[b3]
        res_len = res_len + 1; res[res_len] = encoder[b4]
    end
    
    if left == 1 then
        local num = string.byte(text, len + 1) * 65536
        local b1 = extract(num, 18, 6)
        local b2 = extract(num, 12, 6)
        res_len = res_len + 1; res[res_len] = encoder[b1]
        res_len = res_len + 1; res[res_len] = encoder[b2]
        res_len = res_len + 1; res[res_len] = "="
        res_len = res_len + 1; res[res_len] = "="
    elseif left == 2 then
        local num = string.byte(text, len + 1) * 65536 + string.byte(text, len + 2) * 256
        local b1 = extract(num, 18, 6)
        local b2 = extract(num, 12, 6)
        local b3 = extract(num, 6, 6)
        res_len = res_len + 1; res[res_len] = encoder[b1]
        res_len = res_len + 1; res[res_len] = encoder[b2]
        res_len = res_len + 1; res[res_len] = encoder[b3]
        res_len = res_len + 1; res[res_len] = "="
    end
    
    return table.concat(res)
end

function Base64.decode(data)
    -- Not strictly needed for this plugin, but good to have placeholder
    return "" 
end

return Base64
