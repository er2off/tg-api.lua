--- Additional tools
--
-- @author Er2 <er2@dismail.de>
-- @copyright 2022-2025
-- @license Zlib
-- @classmod TGTools

local json = require 'json'
local mp = require 'multipart'
local fs = require 'coro-fs'
local http = require 'coro-http'
require 'class'

class 'TGTools' {
	--- Telegram bot API endpoint
	url = 'https://api.telegram.org',

	init = function(this, opts)
		assert(type(opts) == 'table', 'Invalid options type')
		assert(type(opts.token) == 'string', 'Invalid token')
		-- this.token = opts.token
		if opts.url then
			assert(type(opts.url) == 'string', 'Invalid url')
			this.url = opts.url
		end

		local req = this.request
		local fakeThis = {
			url = this.url,
			token = opts.token,
			reqPost = this.reqPost,
		}
		--- Hijacks request to pass token into it
		--
		-- If children's request will use more variables then we can't handle in this way.
		-- Variable fakeThis was made to slightly improve performance
		-- but we can't modify it later.
		-- @local
		function this:request(...)
			return req(fakeThis, ...)
		end
	end,

	--- Makes raw POST request.
	-- @tparam string url Endpoint URL.
	-- @tparam ?table param Parameters.
	-- @treturn table,string Headers information, data.
	reqPost = function(url, param)
		param = param or {}
		local body, bound = mp.encode(param)
		local head = {
			{'Content-Type', 'multipart/form-data; boundary=' .. bound}
		}
		return http.request('POST', url, head, body)
	end,

	--- Makes raw API request.
	-- @tparam TGTools this
	-- @tparam string endpoint Endpoint URL.
	-- @tparam ?table param Parameters.
	-- @tparam ?table files Files for upload. (only one supported as for now)
	-- @treturn table,boolean Data, is request OK.
	-- @usage local user, ok = tools:request('getMe')
	request = function(this, endpoint, param, files)
		assert(coroutine.running(), 'Wrap your code into coroutine.wrap')
		assert(this.token, 'Provide token!')
		assert(endpoint, 'Provide endpoint!')
		local url = this.url ..'/bot'.. this.token ..'/'.. endpoint

		local ret, res
		if files and type(files) == 'table' then
			-- POST + form-data
			param = param or {}
			for k, v in pairs(param) do param[k] = tostring(v) end
			for ftype, fname in pairs(files) do
				local data = fs.readFile(fname)
				if data
				then param[ftype] = { filename = fname, data = data }
				else param[ftype] = fname -- raw as-is
				end
			end
			ret, res = this.reqPost(url, param)
		else
			-- GET
			local body = json.encode(param or {})
			local head = {{'Content-Type', 'application/json'}}
			ret, res = http.request('GET', url, head, body)
		end
		local t = json.decode(res or '{}')
		return t, ret.code == 200 and t.ok
	end,

	--- Fetches command and its owner.
	-- @tparam string text Command text.
	-- @treturn string,string Command, to (username without @).
	fetchCmd = function(text)
		return
			text:match '/([%w_]+)',
			text:match '/[%w_]+@([%w_]+)'
	end,

	--- Parses command line arguments from message.
	-- @tparam string text Message text after command.
	-- @treturn table Arguments.
	-- @raise If string have invalid quotes location.
	-- @usage
	-- local args = tools.parseArgs 'this is "one big arg" unlike \"these \" ones'
	parseArgs = function(text)
		local args = {}
		local buf = ''
		local qtype
		local isEsc = false
		for i = 1, #text + 1 do
			local v = text:sub(i, i)

			-- escaping
			if isEsc
			then isEsc, buf = false, buf.. v
			elseif v == '\\'
			then isEsc = true

			-- strings
			elseif v == "'" or v == '"' then
				if qtype and v == qtype
				then table.insert(args, buf)
					buf, qtype = '', nil
				elseif #buf ~= 0
				then error('"'.. buf ..'" have quote, maybe add backslash?')
				else qtype = v
				end

			-- separators
			elseif v == ''
			or (not qtype and
			(  v == ' '
			or v == '\n'
			or v == '\t'
			)) then
				if #buf ~= 0
				then table.insert(args, buf)
				end
				buf = ''

			else buf = buf.. v
			end
		end
		return args
	end,
}
