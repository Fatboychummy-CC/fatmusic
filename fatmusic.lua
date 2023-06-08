--- The main program for fatmusic. This will setup as either a server or remote.
--- This will also DOWNLOAD any required libraries.

local file_helper = require "libs.file_helper"
local display_utils = require "libs.display_utils"
local button = require "libs.button"

local FILES = {
  CONFIG = "config.lson"
}

local config = file_helper.unserialize(FILES.CONFIG, {})

local function setup_complete()
  print("Done. Writing config.")
  file_helper.serialize(FILES.CONFIG, config)
  print("Done. You can relaunch this program now.")
  error("", 0)
end

local function setup_client()
  -- setup configurations
  config.type = "client"
  config.default_server = "None"
  config.server_key = ""
  config.keepalive_timeout = 12

  setup_complete()
end

local function setup_server()
  -- warn user of startup overwrite.

  -- setup configurations
  config.type = "server"
  config.server_name = "New FatMusic Server"
  config.server_key = ""
  config.max_history = 20
  config.max_playlist = 100
  config.broadcast_radio = false
  config.keepalive_ping_every = 5
  config.broadcast_song_info_every = 5

  setup_complete()
end


local function replace_char_at(str, x, new)
  if x <= 1 then
    return new .. str:sub(2)
  elseif x == #str then
    return str:sub(1, -2) .. new
  elseif x > #str then
    return str
  end
  return str:sub(1, x - 1) .. new .. str:sub(x + 1)
end

local function get_keys(message, ...)
  local descriptions = table.pack(...)
  local _keys = {}
  print(message)print()

  for i, description in ipairs(descriptions) do
    description = "  " .. description
    local p1, p2 = description:find("%[.%]")
    local bg = ('f'):rep(#description)
    local fg = ('0'):rep(#description)
    for j = p1, p2 do
      fg = replace_char_at(fg, j, '1')
    end

    term.blit(description, fg, bg)
    print()
    _keys[i] = keys[description:match("%[(.)%]"):lower()]
  end

  term.blit("> ", '44', 'ff')
  term.setCursorBlink(true)

  while true do
    local _, key_pressed = os.pullEvent("key")
    for _, _key in ipairs(_keys) do
      if key_pressed == _key then
        print(keys.getName(key_pressed))
        term.setCursorBlink(false)
        sleep(0.1) -- prevent weirdness with key_up events.
        return key_pressed
      end
    end
  end
end

if not config.type then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  print("First launch setup...")

  if pocket then
    print("Pocket computer detected, setting up as a client.")
    setup_client()
    return
  else
    print()
    local key = get_keys(
      "Would you like to set this computer up as a client or server?",
      "[c]lient",
      "[s]erver",
      "[e]xit"
    )
    if key == keys.e then
      error("Setup cancelled.", -1)
    elseif key == keys.c then
      setup_client()
      return
    elseif key == keys.s then
      setup_server()
      return
    end
  end
end