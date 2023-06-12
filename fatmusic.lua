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

---@type server_info
local server_info = {
  connected_server = nil,
  song_info = nil,
  playlist = {
    list = {},
    current = 0
  },
}

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
  print(message)
  print()
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
        sleep()
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
    callback = function() end -- do nothing!
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

  -- percent bar.
  local percent_played = display_utils.high_fidelity_percent_bar {
    x = 7,
    y = 6,
    w = 14,
    h = 1,
    background = colors.black,
    filled = colors.blue,
    current = colors.cyan,
    allow_overflow = false,
  }

  local draw_data = {
    displaying_artist = false,
    song_name_offset = {
      offset = 0,
      offset_hold = 0,
    },
    server_name_offset = {
      offset = 0,
      offset_hold = 0
    },
    genre_or_artist_offset = {
      offset = 0,
      offset_hold = 0
    },
    blink_server = false,
    next_tick = os.epoch "utc" + 500
  }

  local function do_offset_text(text, len, data)
    -- If song name is at start. Hold for a short time.
    if data.offset == 0 then
      if data.offset_hold < 5 then
        data.offset_hold = data.offset_hold + 1
      elseif #text <= len then
        -- Text is short, don't offset increase.
        data.offset = 0
        data.offset_hold = 0
        return true
      else
        -- stop hold.
        data.offset_hold = 0
        data.offset = 1
      end
    else
      -- if not holding, offset increase by 1 more.
      data.offset = data.offset + 1

      -- Then check if we're at the end.
      if data.offset > #text - 9 then
        -- If so, stop overflow.
        data.offset = #text - 9

        -- and increment hold.
        data.offset_hold = data.offset_hold + 1

        -- if we go above max hold time
        if data.offset_hold >= 5 then
          -- reset to start of song name.
          data.offset = 0
          data.offset_hold = 0
          return true -- it toggled back.
        end
      end
    end

    return false
  end

  --- Return a timestamp in the "xx:xx" format.
  ---@param seconds integer The amount of seconds to display.
  local function time_stamp(seconds)
    if seconds == -1 then
      return "--:--"
    end

    return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
  end

  local function draw_client()
    local tick_up = os.epoch "utc" >= draw_data.next_tick

    -- If the system has ticked (half second)
    if tick_up then
      -- set the next tick time.
      draw_data.next_tick = os.epoch "utc" + 500

      if server_info.connected_server then
        draw_data.blink_server = false
        do_offset_text(server_info.connected_server, 9, draw_data.server_name_offset)

        -- if a song is selected
        if server_info.song_info then
          server_info.song_info.current_position = server_info.song_info.current_position + 0.5
          -- offset the song info.
          do_offset_text(server_info.song_info.name, 9, draw_data.song_name_offset)

          -- offset the artist or genre.
          if draw_data.displaying_artist then
            if do_offset_text(server_info.song_info.artist, 9, draw_data.genre_or_artist_offset) then
              draw_data.displaying_artist = false
            end
          else
            if do_offset_text(server_info.song_info.genre, 9, draw_data.genre_or_artist_offset) then
              draw_data.displaying_artist = true
            end
          end
        end
      else
        server_button.bar_color = server_button.bar_color == colors.red and colors.gray or colors.red
      end
    end

    set.draw()

    -- server info box
    display_utils.fast_box(8, 2, 9, 3, colors.lightBlue)

    -- song fill bar
    display_utils.fast_box(2, 6, w - 2, 1, colors.gray)

    -- top of song fill bar
    display_utils.fast_box(2, 5, w - 2, 1, colors.gray, '\x8f', colors.black)

    -- bottom of song fill bar
    display_utils.fast_box(2, 7, w - 2, 1, colors.black, '\x83', colors.gray)

    -- empty spot in song fill bar
    display_utils.fast_box(7, 6, 14, 1, colors.black)

    -- write server name
    term.setBackgroundColor(colors.lightBlue)
    if server_info.connected_server then
      term.setTextColor(colors.blue)
      term.setCursorPos(8, 2)

      term.write(server_info.connected_server:sub(
        draw_data.server_name_offset.offset + 1,
        draw_data.server_name_offset.offset + 9
      ))

      term.setTextColor(colors.black)
      -- write song name and whatnot
      if server_info.song_info then
        term.setCursorPos(8, 3)
        term.write(server_info.song_info.name:sub(
          draw_data.song_name_offset.offset + 1,
          draw_data.song_name_offset.offset + 9
        ))

        term.setTextColor(colors.cyan)
        -- write genre or artist
        term.setCursorPos(8, 4)
        if draw_data.displaying_artist then
          term.write(server_info.song_info.artist:sub(
            draw_data.genre_or_artist_offset.offset + 1,
            draw_data.genre_or_artist_offset.offset + 9
          ))
        else
          term.write(server_info.song_info.genre:sub(
            draw_data.genre_or_artist_offset.offset + 1,
            draw_data.genre_or_artist_offset.offset + 9
          ))
        end

        -- if server is running a playlist...
        if server_info.playlist.current ~= 0 then
          local previous_song_info = server_info.playlist.list[server_info.playlist.current - 1]
          local next_song_info = server_info.playlist.list[server_info.playlist.current + 1]
          local next_2_song_info = server_info.playlist.list[server_info.playlist.current + 2]

          -- write previous song
          if previous_song_info then
            song_previous.text = previous_song_info.name:sub(1, w - 4)
          else
            song_previous.text = "---"
          end

          -- next song
          if next_song_info then
            song_next.text = next_song_info.name:sub(1, w - 4)
          else
            song_next.text = "---"
          end

          -- next 2 song
          if next_2_song_info then
            song_next2.text = next_2_song_info.name:sub(1, w - 4)
          else
            song_next2.text = "---"
          end
        end
        -- current song
        song_current.text = server_info.song_info.name:sub(1, w - 4)

        if server_info.song_info.playing then
          pp_button.text = '\x13'
        else
          pp_button.text = '\x10'
        end

        -- Display the current song times.
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)

        -- Current position
        term.setCursorPos(2, 6)
        term.write(time_stamp(server_info.song_info.current_position))

        -- total time
        term.setCursorPos(21, 6)
        term.write(time_stamp(server_info.song_info.length))

        -- percent played
        percent_played.percent = server_info.song_info.current_position / server_info.song_info.length
      end
    else
      term.setTextColor(colors.red)
      term.setCursorPos(8, 2)
      term.write("No server")
    end

    percent_played.draw()
  end

  term.setBackgroundColor(colors.black)
  term.clear()
  draw_client()

  local draw_timer = os.startTimer(0.1)
  while true do
    local event = table.pack(os.pullEvent())

    if event[1] == "timer" and event[2] == draw_timer then
      draw_client()
      draw_timer = os.startTimer(0.1)
    else
      set.event(table.unpack(event, 1, event.n))
      draw_client()
    end
  end
end

local function run_server()
  local w, h = term.getSize()
  local set = button.set()

  local config_button = set.new {
    x = 3,
    y = 15,
    w = 8,
    h = 3,
    text = "CONFIG",
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
    callback = server_settings
  }

  local start_stop_button = set.new {
    x = 41,
    y = 4,
    w = 8,
    h = 3,
    text = "STOP",
    bg_color = colors.red,
    txt_color = colors.white,
    highlight_bg_color = colors.orange,
    highlight_txt_color = colors.white,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.yellow,
    highlight_bar_color = colors.white,
    callback = function() end
  }

  local reset_button = set.new {
    x = 42,
    y = 10,
    w = 7,
    h = 3,
    text = "RESET",
    bg_color = colors.red,
    txt_color = colors.white,
    highlight_bg_color = colors.orange,
    highlight_txt_color = colors.white,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.orange,
    highlight_bar_color = colors.yellow,
    callback = function() end
  }

  local function draw_server()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Server status main box
    display_utils.fast_box(3, 3, w - 4, 5, colors.gray)

    -- Server status text box
    display_utils.fast_box(4, 4, w - 25, 3, colors.lightGray)

    -- Server status status box
    display_utils.fast_box(31, 4, 9, 3, colors.green)

    -- Playlist info box
    display_utils.fast_box(3, 9, w - 4, 5, colors.gray)

    -- draw all the buttons.
    set.draw()
  end

  draw_server()
  while true do
    local event = table.pack(os.pullEvent())

    set.event(table.unpack(event, 1, event.n))
    draw_server()
  end
end

if config.type == "client" then
  run_client()
elseif config.type == "server" then
  run_server()
else
  error(("Unknown config type: %s"):format(config.type), 0)
end
