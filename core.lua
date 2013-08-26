--[[
    
    infu demo lua project - simple IRC bot

    Prerequisites:
        * lua
        * lua-socket
        * lua-rex-pcre

    TODO:
        * plugins API
        * multithreading through lua-lanes (no ubuntu/debian package available)
          or coroutines
        * graceful error handling

]]--

local socket = require("socket")
local rex    = require("rex_pcre")

-- Stolen from python-irclib
local _rfc_1459_command_regexp = "^(:(?P<prefix>[^ ]+) +)?(?P<command>[^ ]+)( *(?P<argument>.+))?"

local IrcConnection = {}
IrcConnection.__index = IrcConnection

function IrcConnection.new(nn, sa, sp)
    local self = setmetatable({}, IrcConnection)
    self.nickname = nn
    self.server_address = sa
    self.server_port = sp
    self.handlers = {}
    self.trigger_char = '%'
    return self
end

function IrcConnection.connect(self)
    if self.connected then return end
    print('Connecting to ' .. self.server_address .. ':' .. self.server_port)
    self.socket = socket.connect(self.server_address, self.server_port)
    self.connected = true
end

function IrcConnection.start(self)
    self:connect()
    self:authorize()
    while true do
        local s, errmsg = pcall(self.process, self)
        if s == false then
            print(" [!] Process failed:",errmsg)
        end
    end
end

function IrcConnection.authorize(self)
    self.nickname = self.nickname or 'luabot123'
    self.username = self.username or self.nickname
    self.realname = self.realname or self.nickname

    self:raw_send("NICK " .. self.nickname)
    self:raw_send("USER " .. self.username .. " 0 * :" .. self.realname)
end

function IrcConnection.raw_send(self, data)
    if self.socket == nil then
        print(" [!] Not connected.")
        return
    end
    print(" -> " .. data)
    self.socket:send(data .. "\n")
end

function IrcConnection.read_line(self)
    local line, err = self.socket:receive()
    -- TODO: graceful error handling
    if err then print("Error occured: " .. err .. " [" .. (line or "") .. "]") end

    print(" <- " .. line)
    return line
end

function IrcConnection.process(self)
    local line = self:read_line()
    local prefix, command, arguments = self:parse_line(line)
    print("{"..arguments.."}")
    local event = {
        ["prefix"] = prefix,
        ["command"] = command,
        ["arguments"] = arguments,

        ["is_pubmsg"] = (command:upper() == "PRIVMSG") and arguments:find('^#'),
        ["message"] = arguments:match(":(.*)"),
        ["channel"] = arguments:match("^(#[^ ]*)"), -- we are generic, yo.
        ["username"] = prefix:match("([^!]*)!"),
        ["source"] = prefix,
    }

    if command:upper() == "PRIVMSG" then
        if event.is_pubmsg then
            event["respond"] = function(ev_self, msg)
                self:privmsg(event.channel, msg)
            end
        else
            event["respond"] = function(ev_self, msg)
                self:privmsg(event.username, msg)
            end
        end
    end

    self:fire_event("irc." .. command, event)
    
    event.trigger_name = self:get_trigger_name(event.message)
    
    if command:upper() == "PRIVMSG" and event.trigger_name then
        event.trigger_arguments = self:get_trigger_arguments(event.message)
        self:fire_event("trigger." .. event.trigger_name, event)
    end
end

function IrcConnection.get_trigger_name(self, message)
    if message ~= nil and self.trigger_char ~= nil and
        message:sub(1, self.trigger_char:len()) == self.trigger_char then
        -- that is so fucking dirty...
        return message:sub(self.trigger_char:len()+1,
            (message:find(" ", self.trigger_char:len()+1, true) or message:len()+1)-1)
    end
end

function IrcConnection.get_trigger_arguments(self, message)
    if message ~= nil and self.trigger_char ~= nil and
        message:sub(1, self.trigger_char:len()) == self.trigger_char and
        message:find(" ", self.trigger_char:len()+1, true) then
        return message:sub(message:find(" ", self.trigger_char:len()+1, true)+1)
    else
        return ""
    end
end

function IrcConnection.parse_line(self, line)
    -- Not enough lua-fu yet to do it correctly. *yet*.
    local _, prefix, command, _, arguments = rex.match(line, _rfc_1459_command_regexp)

    prefix = prefix or ""
    command = command or ""
    arguments = arguments or ""

    return prefix, command, arguments
end

function IrcConnection.register_handler(self, event, handler)
    if self.handlers[event] == nil then
        self.handlers[event] = {}
    end

    self.handlers[event][#self.handlers[event]+1] = handler
end

function IrcConnection.fire_event(self, event, args)
    print(" ~ Firing event", event)
    if self.handlers[event] ~= nil then
        -- shall we just use numeric for?
        for i, v in ipairs(self.handlers[event]) do
            local status, msg = pcall(v, self, args)
            if status == false then
                print("[!] Error handler failed in "..msg)
            end
        end
    end
end

function IrcConnection.privmsg(self, target, message)
    self:raw_send(("PRIVMSG %s :%s"):format(target, message))
end

return {["IrcConnection"] = IrcConnection}
