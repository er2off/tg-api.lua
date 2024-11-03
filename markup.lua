--- Telegram keyboard markups
--
-- @author Er2 <er2@dismail.de>
-- @copyright 2022-2025
-- @license Zlib
-- @module Markup

--- TGInlineKeyboardButton data holder.
-- @type TGInlineKeyboardButton
class 'TGInlineKeyboardButton' {
	--- Creates new InlineKeyboardButton.
	-- @function init
	-- @tparam TGInlineKeyboardButton this
	-- @tparam string text Text of button
	-- @tparam table opts Additional options. (optional)
	-- @treturn TGInlineKeyboardButton this
	function(this, text, opts)
		opts = opts or {}
		this.text = text
		this.url = opts.url
		this.callback_data = opts.cbData
		if opts.webAppURL
		then this.web_app = {url = opts.webAppURL}
		end
		-- TODO: Automatic table generation
		if opts.loginURL
		then this.login_url = opts.loginURL
		end
		this.switch_inline_query = opts.querySwitch
		this.switch_inline_query_current_chat = opts.querySwitchCurrentChat
		this.switch_inline_query_chosen_chat = opts.querySwitchChat
		if opts.copyText
		then this.copy_text {text = opts.copyText}
		end
		this.callback_game = opts.cbGame
		this.pay_button = opts.isPay
	end,
}

--- TGKeyboardButton data holder.
-- @type TGKeyboardButton
class 'TGKeyboardButton' {
	--- Creates new KeyboardButton.
	-- @function init
	-- @tparam TGKeyboardButton this
	-- @tparam string text Text of button, can be fallback.
	-- @tparam table opts Additional options. (optional)
	-- @tparam KeyboardButtonRequestUsers opts.users Users selection.
	-- @tparam KeyboardButtonRequestChat opts.chat Chat selection.
	-- @tparam boolean opts.isContact Contact selection.
	-- @tparam boolean opts.isLocation Location selection.
	-- @tparam string opts.poll Creates new poll. (types: quiz, regular)
	-- @tparam string opts.webAppURL Opens web app by URL.
	-- @treturn TGKeyboardButton this
	function(this, text, opts)
		opts = opts or {}
		this.text = text
		this.request_users = this.toUsers(opts.users)
		this.request_chat = this.toChat(opts.chat)
		this.request_contact = opts.isContact
		this.request_location = opts.isLocation
		if opts.poll
		then this.request_poll = {type = opts.poll}
		end
		if opts.webAppURL
		then this.web_app = {url = opts.webAppURL}
		end
	end,

	--- Users request filter.
	--
	-- All fields are optional, use of false will make correct action.
	-- @type KeyboardButtonRequestUsers
	-- @tfield number id Identifier of request. (required)
	-- @tfield boolean isBot Filter by bots.
	-- @tfield boolean isPremium Filter by Premium users.
	-- @tfield[opt=1] number max Maximum users to be selected.
	-- @tfield boolean addName Adds users' first and last name to answer.
	-- @tfield boolean addUsername Adds users' username to answer.
	-- @tfield boolean addPhoto Adds users' photos to answer. (???, maybe profile pictures? why photo?)

	toUsers = function(users)
		return {
			request_id = users.id,
			user_is_bot = users.isBot,
			user_is_premium = users.isPremium,
			max_quantity = users.max,
			request_name = users.addName,
			request_username = users.addUsername,
			request_photo = users.addPhoto,
		}
	end,

	--- Chat request filter.
	--
	-- All fields are optional, use of false will make correct action.
	-- @type KeyboardButtonRequestChat
	-- @tfield number id Identifier of request. (required)
	-- @tfield boolean isChannel Filter by if it's channel, groups otherwise.
	-- @tfield boolean isForum Filter by forum supergroups.
	-- @tfield boolean hasUsername Filter by chat username existence.
	-- @tfield boolean isOwn Filter by user's own chats (in TG docs it's chat_is_created).
	-- @tfield ChatAdministratorRights userRights Filter by user rights, must be superset of botRights.
	-- @tfield ChatAdministratorRights botRights Filter by bot rights, must be subset of userRights.
	-- @tfield boolean isMember Filter by bot membership.
	-- @tfield boolean addTitle Adds chat's title to answer.
	-- @tfield boolean addUsername Adds chat's username to answer.
	-- @tfield boolean addPhoto Adds chat's photos to answer. (???, maybe profile pictures? why photo?)

	toChat = function(chat)
		return {
			request_id = chat.id,
			chat_is_channel = chat.isChannel,
			chat_is_forum = chat.isForum,
			chat_has_username = chat.hasUsername,
			chat_is_created = chat.isOwn,
			-- TODO(Er2):
			user_administrator_rights = chat.userRights,
			bot_administrator_rights = chat.botRights,
			bot_is_member = chat.isMember,
			request_title = chat.addTitle,
			request_username = chat.addUsername,
			request_photo = chat.addPhoto,
		}
	end,
}

--- Keyboard attached to message, doesn't send extra messages.
--
-- For more information, see
-- [Telegram docs](https://core.telegram.org/bots/features#inline-keyboards)
-- @type TGInlineKeyboard
class 'TGInlineKeyboard' {
	function(this)
		this.inline_keyboard = {}
	end,

	--- Changes button at position.
	-- @tparam TGInlineKeyboard this
	-- @tparam number row Row in keyboard, position.
	-- @tparam number column Column in keyboard, position.
	-- @tparam string text Text of button.
	-- @tparam[opt] table opts Additional options.
	-- @treturn TGInlineKeyboard,TGInlineKeyboardButton this,Constructed button.
	-- @see TGKeyboardButton
	set = function(this, row, column, text, opts)
		local btn = new 'TGInlineKeyboardButton' (text, opts)
		this.inline_keyboard[row] = this.inline_keyboard[row] or {}
		this.inline_keyboard[row][column] = btn
		return this, btn
	end,
}

--- Keyboard with ready answers.
--
-- For more information, see
-- [Telegram docs](https://core.telegram.org/bots/features#keyboards)
-- @type TGReplyKeyboard
class 'TGReplyKeyboard' {
	--- Initializes TGReplyKeyboard.
	-- @function init
	-- @tparam TGReplyKeyboard this
	-- @tparam[opt] table opts Additional options. (optional)
	-- @tparam boolean opts.isPersistent Always show keyboard without possibility to hide.
	-- @tparam boolean opts.isResizable Allows keybiard resize to take less vertical space.
	-- @tparam boolean opts.isOneTime Hides keyboard after reply.
	-- @tparam boolean opts.isSelective Shows keyboard for given specific users. (check Telegram docs)
	-- @tparam string opts.placeholder Text in input field instead of default "Message...", up to 64 characters.
	-- @treturn TGReplyKeyboard Keyboard which is ready to add keys in it.
	-- @usage
	-- api:send('@durov', 'Hello, world!', {
	--   markup = new 'TGReplyKeyboard' {}
	-- })
	function(this, opts)
		opts = opts or {}
		this.keyboard = {}
		this.is_persistent = opts.isPersistent
		this.resize_keyboard = opts.isResizable
		this.one_time_keyboard = opts.isOneTime
		this.selective = opts.isSelective
		this.input_field_placeholder = opts.inputPlaceholder
	end,

	--- Changes button at position.
	-- @tparam TGReplyKeyboard this
	-- @tparam number row Row in keyboard, position.
	-- @tparam number column Column in keyboard, position.
	-- @tparam string text Text of button, can be fallback.
	-- @tparam[opt] table opts Additional options.
	-- @treturn TGReplyKeyboard,TGKeyboardButton this,Constructed button.
	-- @see TGKeyboardButton
	set = function(this, row, column, text, opts)
		local btn = new 'TGKeyboardButton' (text, opts)
		this.keyboard[row] = this.keyboard[row] or {}
		this.keyboard[row][column] = btn
		return this, btn
	end,
}
