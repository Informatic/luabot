require 'utils'
require 'sandboxes'
local luabot = require('core')

local bot = luabot.IrcConnection.new('lubot', 'chat.freenode.net', 6667)

bot:register_handler("irc.PING", function (bot, event)
    bot:raw_send("PONG :" .. event.message)
end)

bot:register_handler("irc.001", function (bot, event)
    bot:raw_send("JOIN #testchannel")
end)

bot:register_handler("trigger.eval", function (bot, event)
    local code = event.trigger_arguments
    if code:sub(1,1) == "=" then
        code = "return " .. code:sub(2)
    end
    
    local response = {sandboxes.run(event.username, code, 5)}
    
    if not response[1] then
        event:respond("-> " .. response[2])
    else
        event:respond("+> " .. table.concat(table.map(tostring, table.tail(response)), ", "))
    end
end)

bot:start()
