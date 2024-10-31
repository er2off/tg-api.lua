return {
	name = 'er2off/tg-api',
	version = '0.1.1',
	description = 'Telegram API for Luvit',
	tags = { 'lua', 'luvit', 'telegram', 'bot' },
	license = 'Zlib',
	author = { name = 'Er2', email = 'er2@dismail.de' },
	homepage = 'https://github.com/er2off/tg-api.lua',
	dependencies = {
		'creationix/coro-fs@v2.2.5',
		'creationix/coro-http@v3.2.3',
		'er2off/class@v1.0.0',
		'er2off/events@v1.0.0',
		'er2off/multipart@v1.0.0',
		'luvit/json@v2.5.2',
		'luvit/require@v2.2.4',
		'luvit/secure-socket@v1.2.4',
	},
	files = {
		'*.lua',
		'!test*'
	}
}
