--- Telegram bot API client library
--
-- @author Er2 <er2@dismail.de>
-- @copyright 2022-2025
-- @license Zlib
-- @classmod TGClient

require 'class'
require 'events'
require './tools'
require './inline'
require './markup'

class 'TGClient' : inherits 'EventsThis' {
	--- Client initialization options.
	-- @table Options
	-- @tfield string token Bot token.
	-- @tfield[opt] string url Custom Telegram API endpoint.
	-- @tfield[opt=false] boolean noRun Disables run() after successful login(),
	-- you need to do this manually.
	-- @tfield[opt=false] boolean noGlobal Disables requirement for commands to
	-- add @usernameBot to start, e.g. it can act with /cmd in groups.
	-- @tfield[opt=120] number timeout Command receive timeout, prevents bot from
	-- answering old commands if it was stopped by mistake.
	-- @tfield[opt] table[string] allowedUpdates Array of allowed updates.
	--
	-- @tparam[opt=1] number limit Limit of updates count for long polling.
	-- @tparam[opt=60] number timeout Timeout in seconds for long polling.
	-- 0 should be used <b>only for testing purposes!</b>

	--- Additional tools.
	-- @table tools

	--- Functions for inline queries.
	-- @table inline

	--- Initialization and updates
	-- @section Updates

	--- Initializes client.
	-- @function init
	-- @tparam Options opts Options.
	-- @usage
	-- local client = new 'TGClient' {
	--   token = 'private',
	-- }
	function(this, opts)
		this:super()
		this.tools = new 'TGTools' ()
		this.tools:init(opts)
		this.inline = new 'TGInline' (this)

		this.request = this.tools.request
		this.parseArgs = this.tools.parseArgs
		this.escMarkdown = this.tools.escMarkdown

		if opts.noRun
		then this.noRun = true
		end
		if opts.noGlobal
		then this.noGlobal = true
		end
		this.timeout = tonumber(opts.timeout or 120)
		if opts.allowedUpdates then
			assert(type(opts.allowedTypes) == 'table', 'Invalid allowedUpdates')
			-- check values too?
			this.allowedUpdates = opts.allowedUpdates
		end
		this.limit = tonumber(opts.limit) or 10
		this.timeout = tonumber(opts.timeout) or 60
	end,

	--- Logs into Telegram.
	-- @tparam TGClient this
	-- @tparam[opt] function cb Callback.
	-- @usage
	-- api:login(function()
	--   print('Logged on as @'.. api.info.username)
	-- end)
	login = function(this, cb)
		coroutine.wrap(function()
			repeat local res, ok = this:getMe()
				if ok and res
				then this.info = res.result
				elseif not ok
				then error(res.description)
				end
			until this.info
			this.info.name = this.info.first_name

			if type(cb) == 'function'
			then cb(this) end

			if not this.noRun
			then this:run() end
		end)()
	end,

	--- Starts event loop.
	-- @tparam TGClient this
	run = function(this)
		this.runs = true
		this:emit 'ready'
		coroutine.wrap(function()
			local offset = 0
			while this.runs do
				local ok, res = xpcall(this.recvUpdate, debug.traceback, this, offset)
				if ok
				then offset = res
				else print(res)
				end
			end
		end)()
	end,

	--- Stops event loop.
	-- @tparam TGClient this
	-- @see run
	destroy = function(this)
		this.runs = false
	end,

	--- Handle updates.
	--
	-- <h2>Shouldn't be used if run() was used!</h2>
	--
	-- @tparam TGClient this
	-- @tparam number offset Offset of first update to be returned.
	-- @treturn number Offset of next update, for loop pass it next time.
	-- @usage
	-- local offset = 0
	-- while runs do
	--   offset = api:recvUpdate(offset)
	-- end
	recvUpdate = function(this, offset)
		local updates, ok = this:getUpdates(offset)
		if not ok then
			print('Error! '.. updates.description)
			return offset + 1
		end
		for _, upd in pairs(updates.result) do
			offset = upd.update_id + 1
			this:receiveUpdate(upd)
		end
		return offset
	end,

	--- Receives update.
	--
	-- <h2>You shouldn't call it directly!</h2>
	--
	-- Simply emits events on needed type.
	--
	-- @tparam TGClient this
	-- @tparam Update upd Raw update from Telegram.
	receiveUpdate = function(this, upd)
		this:emit('update', upd)
		if upd.message then
			local msg = upd.message
			local cmd, to = this.tools.fetchCmd(msg.text or '')
			if cmd then
				-- Command is not for us
				if (to and to ~= this.info.username)
				-- Timeout
				or (this.timeout > 0 and os.time() - msg.date > this.timeout)
				-- /cmd@bot in groups
				or (this.noGlobal and (not to and (msg.chat.type == 'group' or msg.chat.type == 'supergroup')))
				then return end
				-- Strip command
				local toLen = to and (#to + 1) or 0
				-- 2 = / + "lua starts everything from 1"
				msg.text = msg.text:sub(#cmd + toLen + 2)

				msg.cmd = cmd
				this:emit('command', msg)
			else this:emit('message', msg)
			end
		elseif upd.edited_message
		then this:emit('messageEdit', upd.edited_message)

		elseif upd.channel_post
		then this:emit('channelPost', upd.channel_post)
		elseif upd.edited_channel_post
		then this:emit('channelPostEdit', upd.edited_channel_post)

		elseif upd.poll
		then this:emit('poll', upd.poll)
		elseif upd.poll_answer
		then this:emit('pollAnswer', upd.poll_answer)

		elseif upd.business_connection
		then this:emit('businessConniction', upd.business_connection)
		-- FIXME: Handle it too?
		elseif upd.business_message
		then this:emit('messageBusiness', upd.business_message)
		elseif upd.business_edited_message
		then this:emit('messageEditBusiness', upd.business_edited_message)
		elseif upd.deleted_business_messages
		then this:emit('messagesDeletedBusiness', upd.deleted_business_messages)

		elseif upd.message_reaction
		then this:emit('messageReaction', upd.message_reaction)
		elseif upd.message_reaction_count
		then this:emit('messageReactionCount', upd.message_reaction_count)

		elseif upd.inline_query
		then this:emit('inlineQuery', upd.inline_query)
		elseif upd.chosen_inline_result
		then this:emit('inlineChosenResult', upd.chosen_inline_result)
		elseif upd.callback_query
		then this:emit('callbackQuery', upd.callback_query)

		elseif upd.shipping_query
		then this:emit('shippingQuery', upd.shipping_query)
		elseif upd.pre_checkout_query
		then this:emit('preCheckoutQuery', upd.pre_checkout_query)
		elseif upd.purchased_paid_media
		then this:emit('paidMediaPurchase', upd.purchased_paid_media)

		elseif upd.poll
		then this:emit('poll', upd.poll)
		elseif upd.poll_answer
		then this:emit('pollAnswer', upd.poll_answer)

		elseif upd.my_chat_member
		then this:emit('chatMemberUpdateMe', upd.my_chat_member)
		elseif upd.chat_member
		then this:emit('chatMemberUpdate', upd.chat_member)

		elseif upd.chat_join_request
		then this:emit('joinRequest', upd.chat_join_request)
		elseif upd.chat_boost
		then this:emit('boost', upd.chat_boost)
		elseif upd.removed_chat_boost
		then this:emit('boostRemoved', upd.removed_chat_boost)

		end
	end,

	--- Get API
	-- @section Get

	--- Gets information about me.
	-- @tparam TGClient this
	-- @treturn User Information about bot: its name, username and so on.
	getMe = function(this) return this:request 'getMe' end,
	--- Gets information about commands.
	-- @tparam TGClient this
	-- @treturn table Information about available commands.
	getMyCommands = function(this) return this:request 'getMyCommands' end,

	--- Returns information about chat.
	-- @tparam TGClient this
	-- @tparam number|string chatID Identifier of chat, can be @username or 64-bit number since 2021.
	-- @treturn table Information about chat.
	getChat = function(this, chatID)
		return this:request('getChat', {chat_id = this.toChat(chatID)})
	end,

	--- Returns information about chat member.
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam number userID Identifier of user which should be in this chat.
	-- @treturn ChatMember Information about chat member on success.
	getChatMember = function(this, chatID, userID)
		return this:request('getChatMember', {
			chat_id = this.toChat(chatID),
			user_id = userID,
		})
	end,

	--- Returns available updates.
	--
	-- <h2>Shouldn't be used if run() was used!</h2>
	--
	-- @tparam TGClient this
	-- @tparam number offset Offset of first update to be returned.
	-- @treturn table[Update] Updates.
	getUpdates = function(this, offset)
		return this:request('getUpdates', {
			offset = offset,
			limit = this.limit,
			timeout = this.timeout,
			allowed_updates = this.allowedUpdates,
		})
	end,

	--- Send content
	-- @section Send

	--- Sends message to chat.
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam string text Text of message to be sent.
	--
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam string opts.parseMode Message parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Message entities, may be used instead of parseMode.
	-- @tparam LinkPreviewOptions opts.linkPreview Link preview generation options.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @tparam boolean opts.isPaidBroadcast Ignores broadcasting limits but paid (0.1 stars per message).
	-- @tparam string opts.effectID Message effect (?), private chats only.
	-- @tparam ReplyParameters opts.replyParams Description of the message to reply to.
	-- @tparam InlineKeyboardMarkup|ReplyKeyboardMarkup|ReplyKeyboardRemove|ForceReply
	-- opts.markup Additional interface options.
	--
	-- @treturn Message
	-- @usage
	-- api:send('@durov', 'Hello, world!')
	send = function(this, chatID, text, opts)
		opts = opts or {}
		return this:request('sendMessage', {
			chat_id = this.toChat(chatID),
			text = tostring(text),
			business_connection_id = opts.businessID,
			message_thread_id = opts.threadID,
			parse_mode = opts.parseMode,
			entities = opts.entities,
			link_preview_options = opts.linkPreview,
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			allow_paid_broadcast = opts.isPaidBroadcast,
			message_effect_id = opts.effectID,
			reply_parameters = opts.replyParams,
			reply_markup = opts.markup,
		})
	end,

	--- Replies to message in chat.
	-- @tparam TGClient this
	-- @tparam Message message Message to reply to.
	-- @tparam string text Text of message to be sent.
	-- @tparam[opt] table opts Additional options. (see send)
	-- @treturn Message
	-- @see send, makeReply
	reply = function(this, message, text, opts)
		opts = opts or {}
		opts.replyParams = this.makeReply(message)
		return this:send(message.chat.id, text, opts)
	end,

	--- Forwards message to another chat.
	-- @tparam TGClient this
	-- @tparam Message message Message to be forwarded.
	-- @tparam number|string chatID Destination chat.
	-- @tparam[opt] table opts Additional options.
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @treturn Message
	forward = function(this, message, chatID, opts)
		opts = opts or {}
		return this:request('forwardMessage', {
			chat_id = this.toChat(chatID),
			message_thread_id = opts.threadID,
			from_chat_id = message.chat.id,
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			message_id = message.message_id,
		})
	end,

	--- Sends sticker (webp, tgs, webm).
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam InputFile|string sticker Sticker to be sent.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam string opts.emoji Associated emoji.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @tparam string opts.effectID Message effect (?), private chats only.
	-- @tparam boolean opts.isPaidBroadcast Ignores broadcasting limits but paid (0.1 stars per message).
	-- @tparam ReplyParameters opts.replyParams Description of the message to reply to.
	-- @tparam InlineKeyboardMarkup|ReplyKeyboardMarkup|ReplyKeyboardRemove|ForceReply
	-- opts.markup Additional interface options.
	-- @treturn Message
	sendSticker = function(this, chatID, sticker, opts)
		opts = opts or {}
		return this:request('sendSticker', {
			business_connection_id = opts.businessID,
			chat_id = this.toChat(chatID),
			message_thread_id = opts.threadID,
			emoji = opts.emoji,
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			allow_paid_broadcast = opts.isPaidBroadcast,
			message_effect_id = opts.effectID,
			reply_parameters = opts.replyParams,
			reply_markup = opts.markup,
		}, {sticker = sticker})
	end,

	--- Sends photo.
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam InputFile|string photo Photo to be sent.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam string opts.caption Proto caption.
	-- @tparam string opts.parseMode Caption parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Caption entities, may be used instead of parseMode.
	-- @tparam boolean opts.isCaptionAbove Shows caption above image (default is below).
	-- @tparam boolean opts.isSpoiler Adds spoiler animation for clients.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @tparam boolean opts.isPaidBroadcast Ignores broadcasting limits but paid (0.1 stars per message).
	-- @tparam string opts.effectID Message effect (?), private chats only.
	-- @tparam ReplyParameters opts.replyParams Description of the message to reply to.
	-- @tparam InlineKeyboardMarkup|ReplyKeyboardMarkup|ReplyKeyboardRemove|ForceReply
	-- opts.markup Additional interface options.
	-- @treturn Message
	sendPhoto = function(this, chatID, photo, opts)
		opts = opts or {}
		return this:request('sendPhoto', {
			business_connection_id = opts.businessID,
			chat_id = this.toChat(chatID),
			message_thread_id = opts.threadID,
			caption = opts.caption,
			parse_mode = opts.parseMode,
			caption_entities = opts.entities,
			show_caption_above_media = opts.isCaptionAbove,
			has_spoiler = opts.isSpoiler,
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			allow_paid_broadcast = opts.isPaidBroadcast,
			message_effect_id = opts.effectID,
			reply_parameters = opts.replyParams,
			reply_markup = opts.markup,
		}, {sticker = sticker})
	end,

	--- Sends document.
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam InputFile|string document Document to be sent.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam InputFile|string opts.thumbnail Custom thumbnail. Should be JPEG.
	-- @tparam string opts.caption Document caption.
	-- @tparam string opts.parseMode Caption parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Caption entities, may be used instead of parseMode.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @tparam boolean opts.isPaidBroadcast Ignores broadcasting limits but paid (0.1 stars per message).
	-- @tparam string opts.effectID Message effect (?), private chats only.
	-- @tparam ReplyParameters opts.replyParams Description of the message to reply to.
	-- @tparam InlineKeyboardMarkup|ReplyKeyboardMarkup|ReplyKeyboardRemove|ForceReply
	-- opts.markup Additional interface options.
	-- @treturn Message
	sendDocument = function(this, chatID, document, opts)
		opts = opts or {}
		return this:request('sendDocument', {
			business_connection_id = opts.businessID,
			chat_id = this.toChat(chatID),
			message_thread_id = opts.threadID,
			caption = opts.caption,
			parse_mode = opts.parseMode,
			caption_entities = opts.entities,
			-- disable_content_type_detection
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			allow_paid_broadcast = opts.isPaidBroadcast,
			message_effect_id = opts.effectID,
			reply_parameters = opts.replyParams,
			reply_markup = opts.markup,
		}, {document = document, thumbnail = opts.thumbnail})
	end,

	--- Sends native Telegram poll.
	-- @tparam TGClient this
	-- @tparam number|string chatID Unique chat, channel or user ID or @username.
	-- @tparam string question Poll question (up to 300 characters).
	-- @tparam table[InputPollOption] options Poll options.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam number opts.threadID Thread (Topic) ID for forum supergroups.
	-- @tparam string opts.parseMode Question parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Question entities, may be used instead of parseMode.
	-- @tparam[opt=true] boolean opts.isAnonymous Makes poll anonymous.
	-- @tparam[opt='regular'] boolean opts.type Poll type, 'quiz' or 'regular'.
	-- @tparam boolean opts.isMultiple Allows to select multiple options at once, ignored in quiz mode.
	-- @tparam number opts.correctOption Correct option for quiz.
	-- @tparam string opts.explanation Explanation of quiz choice, up to 200 characters with 2 lines.
	-- @tparam string opts.explanationParseMode Explanation parsing mode.
	-- @tparam table[MessageEntity] opts.explanationEntities Explanation entities.
	-- @tparam number opts.opened Time in seconds (5-600) when this poll is opened. Can't be used with opts.closesAt.
	-- @tparam number opts.closesAt Unix timestamp when poll closes. Can't be used with opts.opened.
	-- @tparam boolean opts.isSilent Disables message notification.
	-- @tparam boolean opts.isProtected Protects message from forwarding and saving.
	-- @tparam boolean opts.isPaidBroadcast Ignores broadcasting limits but paid (0.1 stars per message).
	-- @tparam string opts.effectID Message effect (?), private chats only.
	-- @tparam ReplyParameters opts.replyParams Description of the message to reply to.
	-- @tparam InlineKeyboardMarkup|ReplyKeyboardMarkup|ReplyKeyboardRemove|ForceReply
	-- opts.markup Additional interface options.
	-- @treturn Message
	sendPoll = function(this, chatID, question, options, opts)
		opts = opts or {}
		return this:request('sendPoll', {
			business_connection_id = opts.businessID,
			chat_id = this.toChat(chatID),
			message_thread_id = opts.threadID,
			question = question,
			question_parse_mode = opts.parseMode,
			question_entities = opts.entities,
			options = options,
			is_anonymous = opts.isAnonymous,
			type = opts.type,
			allows_multiple_answers = opts.isMultiple,
			correct_option_id = opts.correctOption and opts.correctOption - 1,
			explanation = opts.explanation,
			explanation_parse_mode = opts.explanationParseMode,
			explanation_entities = opts.explanationEntities,
			open_period = opts.opened,
			close_date = opts.closesAt,
			-- is_closed -- useless
			disable_notification = opts.isSilent,
			protect_content = opts.isProtected,
			allow_paid_broadcast = opts.isPaidBroadcast,
			message_effect_id = opts.effectID,
			reply_parameters = opts.replyParams,
			reply_markup = opts.markup,
		})
	end,

	--- Updating messages
	-- @section Update

	--- Changes message text.
	-- @tparam TGClient this
	-- @tparam string text New message text.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam Message opts.message Old message, required if not inline message is to be edited.
	-- @tparam string opts.inlineID Inline message identifier, use this instead of opts.message only for inline messages.
	-- @tparam string opts.parseMode Message parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Message entities, may be used instead of parseMode.
	-- @tparam LinkPreviewOptions opts.linkPreview Link preview generation options.
	-- @tparam InlineKeyboardMarkup opts.markup Inline keyboard. (NOTE, it have less types than with sendMessage)
	-- @treturn Message|boolean Boolean for inline messages, Message otherwise but only on success.
	editText = function(this, text, opts)
		opts = opts or {}
		return this:request('editMessageText', {
			business_connection_id = opts.businessID,
			chat_id = opts.message and this.toChat(opts.message),
			message_id = opts.message and opts.message.message_id,
			inline_message_id = opts.inlineID,
			text = tostring(text),
			parse_mode = opts.parseMode,
			entities = opts.entities,
			link_preview_options = opts.linkPreview,
			reply_markup = opts.markup,
		})
	end,

	--- Changes message caption.
	-- @tparam TGClient this
	-- @tparam[opt] string caption New message caption, can be nil to remove caption.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam Message opts.message Old message, required if not inline message is to be edited.
	-- @tparam string opts.inlineID Inline message identifier, use this instead of opts.message only for inline messages.
	-- @tparam string opts.parseMode Caption parsing mode. (see Telegram docs for more information)
	-- @tparam table[MessageEntity] opts.entities Caption entities, may be used instead of parseMode.
	-- @tparam boolean opts.isCaptionAbove Shows caption above image (default is below).
	-- @tparam InlineKeyboardMarkup opts.markup Inline keyboard. (NOTE, it have less types than with sendPhoto)
	-- @treturn Message|boolean Boolean for inline messages, Message otherwise but only on success.
	editCaption = function(this, caption, opts)
		opts = opts or {}
		return this:request('editMessageCaption', {
			business_connection_id = opts.businessID,
			chat_id = opts.message and this.toChat(opts.message),
			message_id = opts.message and opts.message.message_id,
			inline_message_id = opts.inlineID,
			caption = caption,
			parse_mode = opts.parseMode,
			caption_entities = opts.entities,
			show_caption_above_media = opts.isCaptionAbove,
			reply_markup = opts.markup,
		})
	end,

	--- Changes message inline keyboard markup.
	-- @tparam TGClient this
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam Message opts.message Old message, required if not inline message is to be edited.
	-- @tparam string opts.inlineID Inline message identifier, use this instead of opts.message only for inline messages.
	-- @tparam InlineKeyboardMarkup opts.markup Inline keyboard. (REQUIRED)
	-- @treturn Message|boolean Boolean for inline messages, Message otherwise but only on success.
	-- @raise If opts.markup is not defined.
	editMarkup = function(this, opts)
		if not opts or not opts.markup
		then error 'Markup is not defined'
		end
		return this:request('editMessageReplyMarkup', {
			business_connection_id = opts.businessID,
			chat_id = opts.message and this.toChat(opts.message),
			message_id = opts.message and opts.message.message_id,
			inline_message_id = opts.inlineID,
			reply_markup = opts.markup,
		})
	end,

	--- Stops polls started by bot.
	-- @tparam TGClient this
	-- @tparam Message message Message with started poll.
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam number opts.businessID Business connection ID. (explain?)
	-- @tparam InlineKeyboardMarkup opts.markup Inline keyboard.
	-- @treturn ?Poll Poll on success.
	stopPoll = function(this, message, opts)
		opts = opts or {}
		return this:request('stopPoll', {
			business_connection_id = opts.businessID,
			chat_id = this.toChat(message),
			message_id = message.message_id,
			reply_markup = opts.markup,
		})
	end,

	--- Deletes message.
	-- @tparam TGClient this
	-- @tparam Message message Message to be deleted.
	-- @treturn boolean True on success.
	delete = function(this, message)
		return this:request('deleteMessage', {chat_id = this.toChat(message), message_id = message.message_id})
	end,

	--- Deletes multiple messages.
	--
	-- This implementation automatically sends multiple requests if messages are > 100
	--
	-- @tparam TGClient this
	-- @tparam table[Message] messages Messages to be deleted, should be in same chat.
	-- @treturn boolean True on success.
	-- @raise If messages is not array of Message, or if message is not from this chat.
	deleteMulti = function(this, messages)
		if type(messages) ~= 'table'
		or type(messages[1]) ~= 'table'
		then error 'deleteMulti should have array of messages'
		end
		local chat = this.toChat(messages[1])
		local ids = {}
		for i = 1, #messages do
			local v = messages[i]
			if this.toChat(v) ~= chat
			then error 'Message is not from this chat, preventing deletion'
			end
			table.insert(ids, v.message_id)
			if i % 100 == 0 then
				-- deletion itself
				local res, ok = this:request('deleteMessages', {chat_id = chat, message_ids = ids})
				if not ok
				then return res, false
				end
				ids = {}
			end
		end
		return true
	end,

	--- API methods
	-- @section API

	--- Answers callback query from inline keyboards.
	-- @tparam TGClient this
	-- @tparam number id Identifier of query.
	-- @tparam[opt] string text Text of the notification, up to 200 characters.
	-- @tparam[opt=false] boolean isAlert Shows alert instead of notification at top.
	-- @tparam[opt] string url URL of game or `t.me/your_bot?start=XXXX` links.
	-- @tparam[opt] number caches Seconds of callback result cache, client-side.
	-- @treturn boolean Success
	answerCallback = function(this, id, text, isAlert, url, caches)
		return this:request('answerCallbackQuery', {
			callback_query_id = id,
			text = text,
			show_alert = isAlert,
			url = url,
			cache_time = caches,
		})
	end,

	--- Changes bot commands.
	-- @tparam TGClient this
	-- @tparam table[BotCommand] commands All bot commands for given scope.
	-- @tparam[opt] string language ISO639-1 2-letter language code.
	-- @tparam[opt] BotCommandScope scope Scope where these commands are applied.
	-- @treturn boolean Success
	setMyCommands = function(this, commands, language, scope)
		return this:request('setMyCommands', {
			commands = commands,
			scope = scope,
			language_code = language,
		})
	end,

	--- Utility functions
	-- @section Utility

	--- Makes reply parameters for message
	-- @tparam Message message Message to reply to.
	-- @tparam[opt] {number,number} quote Quoted part of message.
	-- @tparam[opt] boolean allowNoReply Allow message to be sent even if original message wasn't found.
	-- @treturn ReplyParameters Reply parameters.
	-- @raise If quote is invalid parameter.
	-- @see reply
	-- @usage
	-- api:send('@durov', 'Hello, world!', { replyParams = api.makeReply(message) })
	-- api:reply(message, '@durov', 'Hello, world!')
	makeReply = function(message, quote, allowNoReply)
		-- TODO(Er2): Support more for quotes
		local qmsg, qpos
		if quote then
			assert(type(quote) == 'table' and #quote == 2, 'Quoted part should be indexes of begin and end (starting with 1)')
			-- In UTF-16 units? what? message is in UTF-8 units
			qpos = quote[1]
			if qpos < 0
			then qpos = #message.text + qpos - 1
			end
			qmsg = message.text:sub(qpos, quote[2])
		end
		return {
			message_id = message.message_id,
			chat_id = message.chat.id,
			allow_sending_without_reply = allowNoReply,
			quote = qmsg,
			quote_position = qpos,
			-- entities, parse mode?
		}
	end,

	--- Transforms Message (if Message) to chat ID
	-- @tparam Message|string|number message Message or already chat ID.
	-- @treturn number|string Chat ID.
	-- @usage local chat = api.toChat(message)
	toChat = function(message)
		if type(message) == 'table'
		then return message.chat.id end
		return message
	end,

	--- Makes raw request to Telegram API.
	-- @function request
	-- @tparam TGClient this
	-- @tparam string endpoint Endpoint URL.
	-- @tparam ?table param Parameters.
	-- @tparam ?table files Files for upload. (only one supported as for now)
	-- @treturn table,boolean Data, is request OK.
	-- @usage local user, ok = api:request('getMe')

	--- Parses command line arguments from message.
	-- @function parseArgs
	-- @tparam string text Message text after command.
	-- @treturn table Arguments.
	-- @raise If string have invalid quotes location.
	-- @usage
	-- local args = api.parseArgs 'this is "one big arg" unlike \"these \" ones'

	--- Escapes markdown sequences.
	-- @function escMarkdown
	-- @tparam string text Text with markdown characters.
	-- @treturn string Text with escaped markdown characters.
}
