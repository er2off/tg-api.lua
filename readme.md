# Telegram API

This is the bindings of Telegram API written in Lua, part of [my bot](https://github.com/er2off/comp-tg).

Currently they don't have so much bindings as you may want
but it's extendable. If you want to help with this project, send Pull Requests!

# Installation

This version is rewrite of older version (based on LuaSec) and tested only with luvi!

You can install this module through lit:
```sh
$ lit install er2off/tg-api
```

# Example

This API is Object-Oriented and it's very simple to use it with your bot:
```lua
require 'telegram'
local client = new 'TGClient' {
	token = 'private',
}
-- Can be placed anywhere because it's async.
client:login(function()
	print('Logged on as @'.. client.info.username)
end)

client:on('command', function(client, msg)
	if msg.cmd == 'start'
	then client:reply(msg, 'Hello, world!')
	end
end)
```

For more information, generate documentation using LDoc.
