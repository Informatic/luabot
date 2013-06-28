local luabot = require('core')

local bot = luabot.IrcConnection.new('lubot', 'chat.freenode.net', 6667)

bot:register_handler("irc.PING", function (bot, event)
    bot:raw_send("PONG :" .. event.message)
end)

bot:register_handler("irc.001", function (bot, event)
    bot:raw_send("JOIN #testchannel")
end)

bot:register_handler("irc.PRIVMSG", function (bot, event)
    if event.is_pubmsg and event.username:lower() == "inf" then
        bot:privmsg(event.channel, ("%s: zrób internety ;-;"):format(event.username))
    end
end)

bot:start()
