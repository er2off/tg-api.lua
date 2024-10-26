--- Inline query library
--
-- @author Er2 <er2@dismail.de>
-- @copyright 2022-2025
-- @license Zlib
-- @module Inline

local unpack = table.unpack or unpack

--- TGInlineQuery data holder.
-- @type TGInlineQuery
class 'TGInlineQuery' {
	--- Constructor.
	-- @function init
	-- @tparam string id Identifier of this query.
	-- @tparam User from Sender of this query.
	-- @tparam string query Text of this query up to 256 characters.
	-- @tparam string offset Offsets of the results to be returned, can be controlled.
	-- @tparam[opt] string chatType Type of chat where this query was sent.
	-- Secret chats don't have it.
	-- @tparam[opt] Location location Sender location, only if bot is allowed to access user location.
	function(this, id, from, query, offset, chatType, location)
		this.id = id
		this.from = from
		this.query = query
		this.offset = offset
		this.chatType = chatType
		this.location = location
	end
}

--- TGInline class
-- @type TGInline
class 'TGInline' {
	--- Makes raw request to Telegram API.
	-- @function request
	-- @tparam TGInline this
	-- @tparam string endpoint Endpoint URL.
	-- @tparam ?table param Parameters.
	-- @tparam ?table files Files for upload. (only one supported as for now)
	-- @treturn table,boolean Data, is request OK.
	-- @usage local user, ok = inline:request('getMe')
	-- @local

	function(this, api)
		function this.request(this, ...)
			return api:request(...)
		end
	end,

	--- Creates InlineResult.
	-- @tparam string type Type of result. (see Telegram docs)
	-- @tparam string id Identifier of result.
	-- @param ... Various arguments, depends on type. (to be documented)
	-- @treturn TGInlineResult Result.
	result = function(type, id, ...)
		type = tostring(type)
		local t = new 'TGInlineResult' {
			type = type,
			id = id,
		}
		local a = {...}
		if t.type == 'article' then t.title, t.url, t.hide_url, t.description = unpack(a)

		elseif t.type == 'photo' then
			t.photo_url, t.photo_width, t.photo_height, t.title, t.description,
			t.caption, t.parse_mode, t.caption_entities
				= unpack(a)

		elseif t.type == 'gif' or t.type == 'mpeg4_gif' then
			local url, width, height, duration
			url, width, height, duration, t.title, t.caption, t.parse_mode, t.caption_entities
				= unpack(a)

			if t.type == 'gif' then
				t.gif_url, t.gif_width, t.gif_height, t.gif_duration
					= url, width, height, duration
			else
				t.mpeg4_url, t.mpeg4_width, t.mpeg4_height, t.mpeg4_duration
					= url, width, height, duration
			end

		elseif t.type == 'video' then
			t.video_url, t.mime_type, t.title, t.caption, t.parse_mode,
			t.caption_entities, t.video_width, t.video_height, t.video_duration, t.description
				= unpack(a)

		elseif t.type == 'audio' or t.type == 'voice' then
			t.title, t.caption, t.parse_mode, t.caption_entities = unpack(a, 2)

			if t.type == 'audio'
			then t.audio_url, t.performer, t.audio_duration = a[1], a[6], a[7]
			else t.voice_url, t.voice_duration = a[1], a[6]
			end

		elseif t.type == 'document' then
			t.title, t.caption, t.parse_mode, t.caption_entities, t.document_url,
			t.mime_type, t.description = unpack(a)

		elseif t.type == 'location' or t.type == 'venue' then
			t.latitude, t.longitude, t.title = unpack(a, 1, 3)

			if t.type == 'venue'
			then t.address, t.foursquare_id, t.foursquare_type, t.google_place_id, t.google_place_type
				= unpack(a, 4, 8)
			else t.horizontal_accurancy, t.live_period, t.heading, t.proximity_alert_radius
				= unpack(a, 4, 7)
			end

		elseif t.type == 'contact' then
			t.phone_number, t.first_name, t.last_name, t.vcard,
			t.reply_markup, t.input_message_content
				= unpack(a)

		elseif t.type == 'game'
		then t.game_short_name = a[1]
		end

		return t
	end,

	--- Answers inline query.
	-- @tparam TGInline this
	-- @tparam string id Identifier for the answered query.
	-- @tparam table[InlineQueryResult] results Array of query results.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam[opt=300] number opts.caches Time of result cache, server-side.
	-- @tparam[opt=false] boolean opts.isPersonal Allow server to cache results
	-- for one user or everyone else too.
	-- @tparam string opts.nextOffset Set next offset of query, can't be more than 64 bytes.
	-- @tparam InlineQueryResultsButton opts.button Button above inline query results.
	-- @treturn boolean Success.
	answer = function(this, id, results, opts)
		opts = opts or {}
		if results.id
		then results = {results} -- single
		end
		return this:request('answerInlineQuery', {
			inline_query_id = id,
			results = results,
			cache_time = opts.caches,
			is_personal = opts.isPersonal,
			next_offset = opts.nextOffset,
			button = opts.button,
		})
	end,
}

--- TGInlineResult data holder.
-- Undocumented fields are filled in result()
-- @type TGInlineResult
-- @tfield string type Type of result.
-- @tfield string id Identifier of result, should be 1-64 bytes.
-- @see result
class 'TGInlineResult' {
	function(this, opts)
		this.type = opts.type
		this.id = tostring(opts.id) or '1'
	end,

	--- Changes result thumbail.
	-- @tparam TGInlineResult this
	-- @tparam string url URL of thumbnail.
	-- @tparam number width Width of thumbnail.
	-- @tparam number height Height of thumbnail.
	-- @tparam string mime MIME type of thumbnail.
	-- @treturn TGInlineResult this, can use as chain.
	thumb = function(this, url, width, height, mime)
		if this.type == 'audio'
		or this.type == 'voice'
		or this.type == 'game'
		then return this end -- cannot do that

		this.thumbnail_url = tostring(url)

		if width and height and (
			this.type == 'article'
			or this.type == 'document'
			or this.type == 'contact'
			or this.type == 'location'
			or this.type == 'venue'
		) then
			this.thumbnail_width  = tonumber(width)
			this.thumbnail_height = tonumber(height)
		end

		if mime and (
			this.type == 'gif' or this.type == 'mpeg4_gif'
		) then this.thumbnail_mime_type = mime end

		return this
	end,

	--- Sets input keyboard
	-- @tparam TGInlineResult this
	-- @param ... Keys (to be documented)
	-- @treturn TGInlineResult this, can use as chain.
	keyboard = function(this, ...)
		if not this.type
		then return this end

		local k = {}
		for _, v in pairs {...} do
			if type(v) == 'table' then
				table.insert(k, v)
			end
		end
		this.reply_markup = k

		return this
	end,

	--- Sets input message content.
	-- @tparam TGInlineResult this
	-- @tparam InlineMessageContent content Content of message.
	-- @treturn TGInlineResult this, can use as chain.
	messageContent = function(this, content)
		if this.type == 'game'
		or this.type == 'article'
		then this.input_message_content = content
		end
		return this
	end,
}
