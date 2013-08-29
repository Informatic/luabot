-- 
-- Copyright (c) 2013, Piotr 'inf' Dobrowolski <sandboxes@tastycode.pl>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
--  * Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
--  * Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--

--
-- This library may not be considered safe. Just keep that in mind.
--

module(..., package.seeall)

local debug_sethook, os_clock, error, string_gmatch, pairs, loadstring, setfenv, pcall, unpack =
      debug.sethook, os.clock, error, string.gmatch, pairs, loadstring, setfenv, pcall, unpack

sandboxes = {}

local function multicopy(base, fields)
    local t = {}

    for i,f in pairs(fields) do
        local p = t
        local v = base
        for w, d in string_gmatch(f, "([%w_]+)(.?)") do
            if d == "." then
                if p[w] == nil then
                    p[w] = {}
                end
                p = p[w]
                v = v[w]
            else
                p[w] = v[w]
            end
        end
    end

    return t
end

local function prepare_environment(sandbox_id)
    -- Fetched from http://lua-users.org/wiki/SandBoxes
    -- @TODO: complete list
    -- @TODO: wrappers on potentially vulnerable functions
    return multicopy(_G, {"assert", "error", "ipairs", "next", "pairs", "pcall",
    "print", "select", "tonumber", "tostring", "type", "unpack", "_VERSION", 
    "xpcall", "coroutine.create", "coroutine.resume", "coroutine.running",
    "coroutine.status", "coroutine.wrap", "coroutine.yield", "string.byte", 
    "string.char", "string.find", "string.format", "string.gmatch", "string.gsub", 
    "string.len", "string.lower", "string.match", "string.rep", "string.reverse",
    "string.sub", "string.upper", "table.insert", "table.maxn", "table.remove", 
    "table.sort", "table.concat", "math.abs", "math.acos", "math.asin", 
    "math.atan", "math.atan2", "math.ceil", "math.cos", "math.cosh", "math.deg", 
    "math.exp", "math.floor", "math.fmod", "math.frexp", "math.huge", 
    "math.ldexp", "math.log", "math.log10", "math.max", "math.min", "math.modf",
    "math.pi", "math.pow", "math.rad", "math.random", "math.sin", "math.sinh",
    "math.sqrt", "math.tan", "math.tanh", "io.read", "io.write", "io.flush", 
    "io.type", "os.clock", "os.difftime", "os.time"})
end

-- Based on http://stackoverflow.com/a/3400896
function set_quota(secs)
    local st = os_clock()

    local function check()
        if os_clock()-st > secs then
            debug_sethook() -- disable hooks
            error("time quota exceeded")
        end
    end
    debug_sethook(check,"",100000);
end

function clear_quota()
    debug_sethook()
end

function run(sandbox_id, untrusted_code, quota)
    -- print("→ Running code in sandbox "..sandbox_id)
    if not sandboxes[sandbox_id] then
        sandboxes[sandbox_id] = prepare_environment(sandbox_id)
    end

    if quota then
        set_quota(quota)
    end

    if untrusted_code:byte(1) == 27 then return nil, "binary bytecode prohibited" end
    local untrusted_function, message = loadstring(untrusted_code)
    if not untrusted_function then return nil, message end
    setfenv(untrusted_function, sandboxes[sandbox_id])
    local response = {pcall(untrusted_function)}

    clear_quota()

    return unpack(response)
end
