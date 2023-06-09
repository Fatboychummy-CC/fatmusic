--- The main program for fatmusic. This will setup as either a server or remote.
--- This will also DOWNLOAD any required libraries.

local file_helper = require "libs.file_helper"
local display_utils = require "libs.display_utils"
local button = require "libs.button"
local ecc = require "libs.ecc"

local FILES = {
  CONFIG = "config.lson"
}

local config = file_helper.unserialize(FILES.CONFIG, {})

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
  term.setTextColor(colors.white)

  for i, description in ipairs(descriptions) do
    local positive = description:match(":(.)$"):lower() == 'y'
    description = "  " .. description:match("^(.+):")
    local p1, p2 = description:find("%[.%]")
    local bg = ('f'):rep(#description)
    local fg = ('0'):rep(#description)
    for j = p1, p2 do
      fg = replace_char_at(fg, j, positive and 'd' or 'e')
    end

    term.blit(description, fg, bg)
    print()
    _keys[i] = keys[description:match("%[(.)%]"):lower()]
  end

  term.blit("> ", '44', 'ff')
  term.setCursorBlink(true)

  local function flash(color)
    local x, y = term.getCursorPos()
    term.setBackgroundColor(color)
    term.setCursorBlink(false)
    term.write("     ")
    sleep()
    term.setCursorPos(x, y)
    term.setBackgroundColor(colors.black)
    term.setCursorBlink(true)
    term.write("     ")
    term.setCursorPos(x, y)
  end

  while true do
    local _, key_pressed = os.pullEvent("key")

    for _, _key in ipairs(_keys) do
      if key_pressed == _key then
        flash(colors.green)
        print(keys.getName(key_pressed))
        term.setCursorBlink(false)
        sleep(0.1) -- prevent weirdness with key_up events.
        return key_pressed
      end
    end

    flash(colors.red)
  end
end

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
  config.server_enc_key = ""
  config.keepalive_timeout = 12

  setup_complete()
end

local function setup_server()
  -- warn user of startup overwrite.
  term.setTextColor(colors.orange)
  local key = get_keys(
    "Warning: Setting up the server will overwrite /startup.lua! Are you sure you want to do this?",
      "[y]es:y",
      "[n]o:n"
  )

  if key == keys.n then
    error("Setup cancelled.", -1)
  end

  -- setup configurations
  config.type = "server"
  config.server_name = "New FatMusic Server"
  config.server_enc_key = ""
  config.max_history = 20
  config.max_playlist = 100
  config.broadcast_radio = false
  config.keepalive_ping_every = 5
  config.broadcast_song_info_every = 5
  config.server_hidden = false

  setup_complete()
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
      "[c]lient:y",
      "[s]erver:y",
      "[e]xit:n"
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

local function client_settings()

end

local function server_settings()

end

--- Open the "server" menu in the client.
local function client_server_menu(btn)

end

--- Send a server request for the previous song.
local function prev_song(btn, force)

end

--- Send a server request to play or pause.
local function play_pause(btn)

end

local function next_song(btn, two)

end

local function playlist_select(btn)

end

--- Run the client system.
local function run_client()
  local w, h = term.getSize()
  local set = button.set()

  local server_button = set.new {
    x = 2,
    y = 2,
    w = 6,
    h = 3,
    text = "SRVR",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = client_server_menu
  }

  --- Previous button, one press will restart the song, double press (or if song is at 00:00 to 00:02) will go to the previous song.
  local prev_button = set.new {
    x = 17,
    y = 2,
    w = 3,
    h = 3,
    text = "<",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = prev_song
  }

  --- Play/pause button.
  local pp_button = set.new {
    x = 20,
    y = 2,
    w = 3,
    h = 3,
    text = "\x10", -- toggle to \x13 when song is playing.
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = play_pause
  }

  --- Next song button.
  local next_button = set.new {
    x = 23,
    y = 2,
    w = 3,
    h = 3,
    text = ">",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = next_song
  }

  --- Jump to the previous song in the queue.
  local song_previous = set.new {
    x = 2,
    y = 8,
    w = w - 2,
    h = 2,
    text = "No data",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = false,
    text_offset_x = 1,
    text_offset_y = 0,
    bottom_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = function(btn)
      prev_song(btn, true)
    end
  }

  local song_current = set.new {
    x = 2,
    y = 10,
    w = w - 2,
    h = 2,
    text = "No data",
    bg_color = colors.lime,
    txt_color = colors.black,
    highlight_bg_color = colors.lime,
    highlight_txt_color = colors.black,
    text_centered = false,
    text_offset_x = 1,
    text_offset_y = 0,
    bottom_bar = true,
    bar_color = colors.green,
    highlight_bar_color = colors.green,
    callback = function()end -- do nothing!
  }

  local song_next = set.new {
    x = 2,
    y = 12,
    w = w - 2,
    h = 2,
    text = "No data",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = false,
    text_offset_x = 1,
    text_offset_y = 0,
    bottom_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = next_song
  }

  local song_next2 = set.new {
    x = 2,
    y = 14,
    w = w - 2,
    h = 2,
    text = "No data",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = false,
    text_offset_x = 1,
    text_offset_y = 0,
    bottom_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = function(btn)
      next_song(btn, true)
    end
  }

  local playlist_select_button = set.new {
    x = 2,
    y = 17,
    w = 11,
    h = 3,
    text = "Playlists",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = playlist_select
  }

  local songs_button = set.new {
    x = 19,
    y = 17,
    w = 7,
    h = 3,
    text = "Songs",
    bg_color = colors.lightGray,
    txt_color = colors.black,
    highlight_bg_color = colors.white,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = playlist_select
  }


  local function draw()
    set.draw()
    display_utils.fast_box(8, 2, 9, 3, colors.lightBlue)
    display_utils.fast_box(2, 6, w - 2, 1, colors.gray)
    display_utils.fast_box(2, 5, w - 2, 1, colors.gray, '\x8f', colors.black)
    display_utils.fast_box(2, 7, w - 2, 1, colors.black, '\x83', colors.gray)
    display_utils.fast_box(7, 6, 14, 1, colors.black)

  end

  term.setBackgroundColor(colors.black)
  term.clear()
  draw()
  while true do
    set.event(os.pullEvent())
    draw()
  end
end

local function run_server()

end

if config.type == "client" then
  run_client()
elseif config.type == "server" then
  run_server()
else
  error(("Unknown config type: %s"):format(config.type), 0)
end