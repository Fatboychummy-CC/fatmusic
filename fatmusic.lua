--- The main program for fatmusic. This will setup as either a server or remote.
--- This will also DOWNLOAD any required libraries.

local file_helper = require "libs.file_helper"
local display_utils = require "libs.display_utils"
local button = require "libs.button"
local ecc = require "libs.ecc"
local logging = require "libs.logging"
local aukit = require "libs.aukit"
local communications = require "libs.communication"

local main_context = logging.create_context "Main"
local w, h = term.getSize()

local FILES = {
  CONFIG = "config.lson",
  DUMP_FILE = fs.combine(file_helper.working_directory, ".fatmusic_log_dump")
}

local CHANNELS = {
  DISCOVERY = 12000,
  DATA_PING = 12001, -- + offset
  RADIO     = 13001, -- + offset
  CONTROLS  = 14001, -- + offset
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
  channel_offset = 0
}

local shadigest = ecc.sha256.digest
local function hash_text(s)
  for i = 1, 1500 do
    s = shadigest(s)
  end

  return s:toHex()
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
  main_context.info "Done. Writing config."
  file_helper.serialize(FILES.CONFIG, config)
  main_context.info "Done. You can relaunch this program now."
  error("", 0)
end

local function setup_client()
  -- setup configurations
  main_context.info "Setup as client."

  config.type = "client"
  config.default_server = "None"
  config.server_enc_key = ""
  config.data_timeout = 12
  config.log_level = logging.LOG_LEVEL.DEBUG

  setup_complete()
end

local function setup_server()
  main_context.info "Setup as server."
  -- warn user of startup overwrite.
  term.setTextColor(colors.orange)
  local key = get_keys(
    "Warning: Setting up the server will overwrite /startup.lua! Are you sure you want to do this?",
    "[y]es:y",
    "[n]o:n"
  )

  if key == keys.n then
    main_context.error "Setup cancelled."
    error("Setup cancelled.", -1)
  end

  main_context.info "Setup continues."

  -- setup configurations
  config.type = "server"
  config.server_name = "New FatMusic Server"
  config.server_enc_key = ""
  config.master_password = ""
  config.max_history = 20
  config.max_playlist = 9999
  config.broadcast_radio = false
  config.data_ping_every = 5
  config.server_hidden = false
  config.server_running = false
  config.log_level = logging.LOG_LEVEL.DEBUG
  config.channel_offset = 0

  setup_complete()
end

if not config.type then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
  main_context.info "Running first-time setup."

  if pocket then
    main_context.info "Pocket computer detected, setting up as a client."
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
      main_context.error "Setup cancelled."
      error("Setup cancelled.", -1)
    elseif key == keys.c then
      setup_client()
      return
    elseif key == keys.s then
      setup_server()
      return
    end
  end
else
  -- Read config into server data.
  server_info.channel_offset = config.channel_offset or 0
end

local comms = communications.namespace(
  "fatmusic",
  CHANNELS.DISCOVERY,
  CHANNELS.CONTROLS + config.channel_offset
)
comms.set_modem(peripheral.find("modem", function(_, w) return w.isWireless() end))

local function client_settings()

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

local function get_computer_type()
  local level = "Basic"
  local model = "computer"
  if term.isColor() then
    level = "Advanced"
  end

  if pocket then
    model = "pocket computer"
  elseif turtle then
    model = "turtle"
  end

  return level .. " " .. model
end

local function yn(v, definitely)
  return v and definitely and "Definitely." or v and "Yes." or "No."
end

--- Info collection function for dumping to logs - aids debugging. Only dumped if debug is enabled.
local function collect_info()
  local context = logging.create_context "DEBUG_INFO"

  -- STAGE 1: COLLECT
  local server_root = file_helper.working_directory
  local file_named_fatmusic = shell.getRunningProgram() == fs.combine(file_helper.working_directory, "fatmusic.lua")
  local libs_dir_found = fs.exists(fs.combine(file_helper.working_directory, "libs"))
  local modded = false -- No check yet, I may not even add a system for modding.
  local mods = {}

  local libs = {
    { "button.lua",        "libs.button",        false, false },
    { "display_utils.lua", "libs.display_utils", false, false },
    { "ecc.lua",           "libs.ecc",           false, false },
    { "file_helper.lua",   "libs.file_helper",   false, false },
    { "logging.lua",       "libs.logging",       false, false }
  }
  for i, lib_data in ipairs(libs) do
    lib_data[3] = fs.exists(fs.combine(file_helper.working_directory, "libs", lib_data[1]))
    local err
    lib_data[4], err = pcall(require, lib_data[2])
    if not lib_data[4] then
      lib_data[5] = err
    end
  end

  -- STAGE 2: WRITE
  context.debug("#=====================================#")
  context.debug("|Collecting information for debugging.|")
  context.debug("#=====================================#")
  context.debug("Is modified?", yn(modded, true))
  if #mods > 0 then
    context.debug("Mods:")
    for _, mod in ipairs(mods) do
      context.debug(' ', mod)
    end
  end
  context.debug("Computer information:")
  context.debug("  Computer type       :", get_computer_type())
  context.debug("  _VERSION            :", _VERSION)
  context.debug("  _HOST               :", _HOST)
  context.debug("  _CC_DEFAULT_SETTINGS:", _CC_DEFAULT_SETTINGS)
  context.debug("  On native term      :", yn(term.current() == term.native()))
  context.debug("File system information:")
  context.debug("  Server root:", "/" .. tostring(server_root) .. "/")
  context.debug("  fatmusic.lua:", yn(file_named_fatmusic))
  context.debug("  Found libs directory:", yn(libs_dir_found))

  for _, lib_data in ipairs(libs) do
    context.debug("Library information for", lib_data[1])
    context.debug("  Located :", lib_data[3])
    context.debug("  Required:", lib_data[4], "(", lib_data[2], ")")
    context.debug("  Errored :", lib_data[5] or "No.")
  end

  context.debug("Configuration settings:")
  context.debug("  Type            :", config.type)
  context.debug("  Log level       :", config.log_level)

  if config.type == "client" then
    context.debug("  Default server  :", config.default_server)
    context.debug("  Server encrypted:", yn(config.server_enc_key))
    context.debug("  Data timeout  :", config.data_timeout)
  elseif config.type == "server" then
    context.debug("  Server name     :", config.server_name)
    context.debug("  Server encrypted:", config.server_enc_key == "" and "No." or "Yes.")
    context.debug("  Max history len :", config.max_history)
    context.debug("  Max playlist len:", config.max_playlist)
    context.debug("  Radio on?       :", yn(config.broadcast_radio))
    context.debug("  Data ping rate  :", config.data_ping_every)
    context.debug("  Server hidden?  :", yn(config.server_hidden))
    context.debug("  Server running? :", yn(config.server_running))
  else
    context.warn("Unknown system type selected:", config.type)
  end
end

local function dump_logs()
  if fs.exists(FILES.DUMP_FILE) then
    local set = button.set()

    local continue = false
    local clicked = false
    local no = set.new {
      x = pocket and 18 or 34,
      y = 12,
      w = 4,
      h = 3,
      text = "NO",
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
      callback = function()
        clicked = true
      end
    }

    local yes = set.new {
      x = pocket and 6 or 15,
      y = 12,
      w = 5,
      h = 3,
      text = "YES",
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
      callback = function()
        clicked = true
        continue = true
      end
    }

    local function redraw()
      display_utils.fast_box(
        pocket and 4 or 13,
        4,
        pocket and 20 or 27,
        13,
        colors.gray
      )
      display_utils.fast_box(
        pocket and 5 or 14,
        5,
        pocket and 18 or 25,
        11,
        colors.white
      )
      set.draw()

      if pocket then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
        term.setCursorPos(6, 6)
        term.write("File already")
        term.setCursorPos(6, 7)
        term.write("exists.")

        term.setCursorPos(6, 9)
        term.write("Overwrite?")
      else
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
        term.setCursorPos(15, 6)
        term.write("File already exists.")
        term.setCursorPos(15, 8)
        term.write("Overwrite?")
      end
    end

    while true do
      redraw()
      local event = table.pack(os.pullEvent())
      set.event(table.unpack(event, 1, event.n))

      if clicked then
        if continue then
          main_context.debug("Dumping log to", FILES.DUMP_FILE)
          collect_info()
          logging.dump_log(FILES.DUMP_FILE)
        end
        return
      end
    end
  end
end

local log_win = window.create(term.current(), 1, 1, w, h - 5, false)
logging.set_window(log_win)
logging.set_level(config.log_level)
main_context.debug "Created custom log window."
main_context.debug("Opened the following channels on modem", comms.get_modem_name(), ":", CHANNELS.DISCOVERY,
  CHANNELS.CONTROLS + config.channel_offset)
--- Display the log window.
local function display_logs(err)
  local set = button.set()

  local do_exit = false
  local relaunch = false
  local exit_button = set.new {
    x = w - 7,
    y = pocket and 17 or 16,
    w = 6,
    h = 3,
    text = "EXIT",
    bg_color = colors.yellow,
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
    callback = function()
      do_exit = true
    end
  }

  if type(err) == "string" and not pocket then
    -- relaunch button
    set.new {
      x = w - 18,
      y = 16,
      w = 10,
      h = 3,
      text = "RELAUNCH",
      bg_color = colors.green,
      txt_color = colors.black,
      highlight_bg_color = colors.yellow,
      highlight_txt_color = colors.black,
      text_centered = true,
      top_bar = true,
      bottom_bar = true,
      left_bar = true,
      right_bar = true,
      bar_color = colors.gray,
      highlight_bar_color = colors.lightGray,
      callback = function()
        do_exit = true
        relaunch = true
      end
    }
  end

  local dump_button = set.new {
    x = 2,
    y = pocket and 17 or 16,
    w = 11,
    h = 3,
    text = "DUMP LOGS",
    bg_color = colors.blue,
    txt_color = colors.black,
    highlight_bg_color = colors.cyan,
    highlight_txt_color = colors.black,
    text_centered = true,
    top_bar = true,
    bottom_bar = true,
    left_bar = true,
    right_bar = true,
    bar_color = colors.gray,
    highlight_bar_color = colors.lightGray,
    callback = dump_logs
  }

  local function redraw()
    term.setBackgroundColor(colors.black)
    term.clear()
    log_win.setVisible(true)
    log_win.setVisible(false)
    set.draw()
    display_utils.fast_box(1, pocket and 15 or 14, w, 1, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, pocket and 15 or 14)
    if type(err) == "string" then
      term.write(pocket and "System error, viewing logs" or "System errored, viewing logs.")
    else
      term.write("Viewing logs.")
    end
  end
  redraw()

  while true do
    local event = table.pack(os.pullEvent())

    set.event(table.unpack(event, 1, event.n))
    redraw()

    if do_exit then
      log_win.setVisible(false)
      return relaunch
    end
  end
end

local function save_config()
  file_helper.serialize(FILES.CONFIG, config)
end

--- Run the client system.
local function run_client()
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

--- Run the server settings page.
---@param data table
---@param on_change_callback fun() A callback that is called whenever something changes.
local function server_settings(data, on_change_callback)
  local set = button.set()

  local go_back = false

  local back_button = set.new {
    x = 3,
    y = 15,
    w = 6,
    h = 3,
    text = "BACK",
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
    callback = function()
      go_back = true
    end
  }

  local server_name_button = set.input_box {
    x = 17,
    y = 4,
    w = 15,
    text = config.server_name,
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.server_name = self.result
      self.default_text = self.result
      self.text = self.result
    end,
    verification_callback = function(str)
      return #str <= 16 and str or nil, "Name must be less than 16 characters long."
    end,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the name of the server. Allows clients to differentiate servers.",
    default_text = config.server_name
  }

  local server_hidden_button = set.new {
    x = 48,
    y = 4,
    w = 1,
    h = 1,
    text = config.server_hidden and "Y" or "N",
    bg_color = config.server_hidden and colors.green or colors.red,
    highlight_bg_color = config.server_hidden and colors.yellow or colors.orange,
    txt_color = colors.white,
    highlight_txt_color = colors.white,
    callback = function(self)
      config.server_hidden = not config.server_hidden

      self.text = config.server_hidden and "Y" or "N"
      self.bg_color = config.server_hidden and colors.green or colors.red
      self.highlight_bg_color = config.server_hidden and colors.yellow or colors.orange
    end
  }

  local function verify_password(str)
    if str == "" then return "" end -- allow empty input
    -- Apparently no character class exists that pulls all "special" characters.
    -- Thus, we will test for these and any control characters, punctuation characters, and \0
    -- I do not care if this string overlaps with any of those.
    local specials = ("`~!@#$%^&*()_+-=[]\\;',./{}|:\"<>?")

    local has_specials, has_digits, has_lower, has_upper = false, false, false, false

    if str:match("%p") or str:match("%c") or str:match("%z") or str:match("%s") then
      has_specials = true
    else
      for char in specials:gmatch(".") do
        if str:find(char, 1, true) then
          has_specials = true
          break
        end
      end
    end

    has_digits = str:match("%d") and true or false
    has_lower = str:match("%l") and true or false
    has_upper = str:match("%u") and true or false

    return has_specials and has_digits and has_lower and has_upper and #str >= 8 and str or nil,
        "Requires one special character, digit, lowercase, and uppercase number. Min 8 chars."
  end

  local encryption_button = set.input_box {
    x = 20,
    y = 6,
    w = 10,
    text = config.server_enc_key == "" and "None" or ("\x07"):rep(10),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.server_enc_key = self.result == "" and "" or hash_text(self.result) --ecc.sha256.digest(self.result):toHex()
      self.text = config.server_enc_key == "" and "None" or ("\x07"):rep(10)
    end,
    verification_callback = verify_password,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the encryption key of the server. Leave blank for empty.",
    password_field = true
  }

  local playlist_length_button = set.input_box {
    x = 25,
    y = 8,
    w = 4,
    text = ("%4d"):format(config.max_playlist),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.max_playlist = self.result
      self.text = ("%4d"):format(config.max_playlist)
      self.default_text = tostring(self.result)
    end,
    verification_callback = function(str)
      local v = tonumber(str)
      if v then
        if v >= 1 and v <= 9999 then
          return v
        end

        return nil, "Input must be between 1 and 9999 (inclusive)."
      else
        return nil, "Input must be a number."
      end
    end,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the maximum playlist length of the server.",
    default_text = tostring(config.max_playlist)
  }

  local broadcast_rate_button = set.input_box {
    x = 46,
    y = 8,
    w = 2,
    text = ("%2d"):format(config.data_ping_every),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.data_ping_every = self.result
      self.text = ("%2d"):format(self.result)
      self.default_text = tostring(self.result)
    end,
    verification_callback = function(str)
      local v = tonumber(str)
      if v then
        if v >= 1 and v <= 99 then
          return v
        end

        return nil, "Input must be between 1 and 99 (inclusive)."
      else
        return nil, "Input must be a number."
      end
    end,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the rate at which the server broadcasts song information (seconds/broadcast)."
  }

  local log_level_button = set.new {
    x = 19,
    y = 10,
    w = 1,
    h = 1,
    text = ("%1d"):format(config.log_level),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.log_level = (config.log_level + 1) % 5
      logging.set_level(config.log_level)
      self.text = ("%1d"):format(config.log_level)
    end
  }

  local channel_offset_button = set.input_box {
    x = 37,
    y = 10,
    w = 3,
    text = ("%3d"):format(config.channel_offset),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.channel_offset = self.result
      self.text = ("%3d"):format(config.channel_offset)

      comms.set_channels(CHANNELS.DISCOVERY, CHANNELS.CONTROLS + config.channel_offset)
      main_context.debug("Opened the following channels on modem:", CHANNELS.DISCOVERY,
        CHANNELS.CONTROLS + config.channel_offset)
      server_info.channel_offset = config.channel_offset
    end,
    verification_callback = function(str)
      local v = tonumber(str)
      if v then
        if v >= 0 and v <= 999 then
          return v
        end

        return nil, "Input must be between 0 and 999 (inclusive)."
      else
        return nil, "Input must be a number."
      end
    end,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the channel offset. This offsets the communications of each channel to prevent overlap.",
  }

  local master_password_button = set.input_box {
    x = 21,
    y = 12,
    w = 10,
    text = config.master_password == "" and "None" or ("\x07"):rep(10),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      config.master_password = self.result == "" and "" or hash_text(self.result) --ecc.sha256.digest(self.result):toHex()
      self.text = config.master_password == "" and "None" or ("\x07"):rep(10)
    end,
    verification_callback = verify_password,
    info_x = 3,
    info_y = 15,
    info_w = 47,
    info_h = 3,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Set the master password for the server. Leave blank to clear.",
    password_field = true
  }

  local function redraw()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Main box
    display_utils.fast_box(3, 3, w - 4, 11, colors.gray)

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    term.setCursorPos(4, 4)
    term.write("Server name:")
    term.setCursorPos(33, 4)
    term.write("Server hidden:")
    term.setCursorPos(4, 6)
    term.write("Encryption key:")
    term.setCursorPos(4, 8)
    term.write("Max playlist length:")
    term.setCursorPos(30, 8)
    term.write("Broadcast rate:")
    term.setCursorPos(4, 10)
    term.write("Logging level:")
    term.setCursorPos(21, 10)
    term.write("Channel offset:")
    term.setCursorPos(4, 12)
    term.write("Master password:")

    set.draw()
  end

  while true do
    redraw()
    local event = table.pack(os.pullEvent())

    local old_pw, old_ec = config.master_password, config.server_enc_key

    if set.event(table.unpack(event, 1, event.n)) then
      save_config()
    end

    if old_pw ~= config.master_password or old_ec ~= config.server_enc_key then
      on_change_callback()
    end

    if go_back then
      return
    end
  end
end

local function run_server()
  local set = button.set()
  local should_lock = config.master_password ~= ""
  local locked = should_lock
  local was_locking = should_lock
  local locked_last_tick = false
  local lock_timeout ---@type integer?

  local server_data = {
    song_queue = {
      position = 0,
    },
    randomized = false, ---@type boolean
    randomized_queue = {position = 0},
    looping = false, ---@type boolean
    state = "startup", ---@type server_state
    broadcast_state = "offline", ---@type server_broadcast_state
    playing = false ---@type boolean
  }

  local current_term = term.current() -- capture the current terminal -- if the screen locks while an editor is opened, it will lose the terminal.

  if config.server_running then
    server_data.broadcast_state = config.server_hidden and "offline" or "online"
  else
    server_data.broadcast_state = config.server_hidden and "offline" or "ignore"
  end

  --- Check if the server is in a state which allows it to broadcast data or respond to pings.
  ---@return boolean
  local function broadcast_state()
    return server_data.broadcast_state == "online"
        or server_data.broadcast_state == "ignore"
  end

  local function on_pw_change()
    -- Catch password or encryption key changes
    if config.master_password == "" then
      should_lock = false
      locked = false
    else
      should_lock = true
      if not was_locking then
        locked = true
        lock_timeout = os.startTimer(60)
      end
    end
  end

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
    callback = function()
      server_settings(server_data, on_pw_change)
    end
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
    callback = function()
      config.server_running = not config.server_running
      if config.server_running then
        server_data.broadcast_state = config.server_hidden and "offline" or "online"
      else
        server_data.broadcast_state = config.server_hidden and "offline" or "ignore"
      end
    end
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
    callback = function()
      server_data.playing = false
      server_data.song_queue = { position = 0 }
      os.queueEvent "fatmusic:stop"
    end
  }

  local logs_button = set.new {
    x = 44,
    y = 15,
    w = 6,
    h = 3,
    text = "LOGS",
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
    callback = display_logs
  }

  local draw_context = logging.create_context "DRAW"
  local function draw_lock_icon()
    if should_lock then
      current_term.setCursorPos(w, 1)
      current_term.blit('\xa4', 'e', '0')
    end
  end
  local function draw_server()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Server status main box
    display_utils.fast_box(3, 3, w - 4, 5, colors.gray)

    -- Server status text box
    display_utils.fast_box(4, 4, w - 25, 3, colors.lightGray)

    -- Server status status box
    display_utils.fast_box(31, 4, 9, 3, config.server_running and colors.green or colors.red)

    -- write server status
    term.setCursorPos(10, 5)
    term.blit("SERVER STATUS", "fffffffffffff", "8888888888888")

    -- set the running/stopped things
    if config.server_running then
      start_stop_button.bar_color = colors.yellow
      start_stop_button.bg_color = colors.red
      start_stop_button.highlight_bg_color = colors.orange
      start_stop_button.text = "STOP"

      term.setCursorPos(32, 5)
      term.blit("RUNNING", "0000000", "ddddddd")
    else
      start_stop_button.bar_color = colors.lime
      start_stop_button.bg_color = colors.green
      start_stop_button.highlight_bg_color = colors.lime
      start_stop_button.text = "STRT"

      term.setCursorPos(32, 5)
      term.blit("STOPPED", "0000000", "eeeeeee")
    end

    -- Playlist info box
    display_utils.fast_box(3, 9, w - 4, 5, colors.gray)

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    -- Current song
    term.setCursorPos(4, 10)
    term.write(("Current song   : %20s"):format(
      server_data.song_queue[server_data.song_queue.position] and
      server_data.song_queue[server_data.song_queue.position].name
      or "None"
    ))

    -- playlist length
    term.setCursorPos(4, 11)
    term.write(("Playlist length: %20d"):format(
      #server_data.song_queue
    ))

    -- playing
    term.setCursorPos(4, 12)
    term.write(("State          : %20s"):format(server_data.state))

    -- draw all the buttons.
    set.draw()

    draw_lock_icon()
  end

  local song_context = logging.create_context "MUSIC_CONTROL"
  local function get_next_song()
    if server_data.randomized then
      -- Create a random queue if one does not exist.
      -- OR if we've reached the end of the current random queue.
      ---@todo weighted generation: at midway point, cut half the queue and weight those songs high.
      --       The second half of the current queue will be weighted low, lower the closest to current song.
      --       This should allow the user to go back if the queue reaches the end and wraps around.
      --       As well, this should give a pretty even randomization so it doesn't seem like the same songs are playing over and over again.
      local len = #server_data.randomized_queue
      if len == 0 or (server_data.randomized_queue.position >= len and server_data.looping) then
        server_data.randomized_queue = {}
        server_data.randomized_queue.position = 0
        -- fun fact: the following section of code is technically O(inf) :)
        song_context.info("No randomized list exists, creating one.")
        local selected = {}
        local slen = #server_data.song_queue
        for i = 1, slen do
          local selection
          repeat
            selection = math.random(1, slen)
          until not selected[selection]
          selected[selection] = true

          server_data.randomized_queue[selection] = server_data.song_queue[i]
        end
      end

      -- Get the next song in the list, determine its position in the song queue.
      server_data.randomized_queue.position = server_data.randomized_queue.position + 1
      local song = server_data.randomized_queue[server_data.randomized_queue.position]
      for i = 1, #server_data.song_queue do
        if song == server_data.song_queue[i] then
          server_data.song_queue.position = i
          return song
        end
      end

      if song then
        -- Not found in the song queue.
        return song
      elseif not server_data.looping and server_data.randomized_queue.position >= len then
        -- Song not found, at end of list and not looping.
        server_data.song_queue.position = 0
        server_data.playing = false
      else
        -- Song not found, at end of list and looping (shouldn't happen)
        -- Can happen if queue is empty maybe? Will need to test.
        ---@todo test the above.
        error("Song not found, at end of randomized playlist and not looping. This shouldn't happen.")
      end
    else
      server_data.song_queue.position = server_data.song_queue.position + 1
      song_context.debug "Increment song queue position"
      song_context.debug(server_data.song_queue.position - 1, "->", server_data.song_queue.position)
      local song = server_data.song_queue[server_data.song_queue.position]

      if song then
        song_context.debug "Got song at position!"
        return song
      else
        song_context.debug "No song at that queue position."
        if server_data.looping then
          -- we reached the end, return to zero
          server_data.song_queue.position = 0
          -- the next tick the server will grab the correct song.
        else
          server_data.song_queue.position = 0
          server_data.playing = false
        end
      end
    end
  end

  local audio_context = logging.create_context "AUDIO"

  --- Download the given song.
  ---@param song song_info The information about the song.
  ---@return string|false song_data The song data, or false if it failed to download.
  ---@return string? error The error, if there was one.
  local function download_song(song)
    local handle, err = http.get(song.remote, nil, true)
    if not handle then
      return false, err
    end

    local data = handle.readAll() --[[@as string]]
    handle.close()

    return data
  end

  --- Load the song given its song info and downloaded data.
  ---@param song song_info The song's information.
  ---@param data string The song data, downloaded from the internets.
  ---@return aukit_stream|false stream The stream iterator.
  ---@return number|string length_or_error The song length, in seconds. Returns the reason if it failed to load the song.
  local function load_song(song, data)
    if song.file_type == "pcm" then
      return aukit.stream.pcm(
        data,
        song.audio_options.bit_depth,
        song.audio_options.data_type,
        song.audio_options.channels,
        song.audio_options.sample_rate,
        song.audio_options.big_endian,
        song.audio_options.mono
      )
    elseif song.file_type == "dfpwm" then
      return aukit.stream.dfpwm(
        data,
        song.audio_options.sample_rate,
        song.audio_options.channels,
        song.audio_options.mono
      )
    elseif song.file_type == "wav" or song.file_type == "aiff" or song.file_type == "au" then
      return aukit.stream[song.file_type](
        data,
        song.audio_options.mono,
        song.audio_options.ignore_header
      )
    elseif song.file_type == "flac" then
      return aukit.stream.flac(
        data,
        song.audio_options.mono
      )
    end

    return false, ("Unsupported file type: %s"):format(song.file_type)
  end

  local lock_set = button.set()

  local lock_password = lock_set.input_box {
    x = 15,
    y = 7,
    w = 23,
    text = "",
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function(self)
      if hash_text(self.result) == config.master_password then--ecc.sha256.digest(self.result):toHex() == config.master_password then
        locked = false
      end
    end,
    verification_callback = function(str)
      return str
    end,
    info_x = 8,
    info_y = 12,
    info_w = 37,
    info_h = 2,
    info_bg_color = colors.gray,
    info_txt_color = colors.white,
    info_text = "Input the master password to access server console.",
    default_text = "",
    password_input_field = true
  }

  local playback_bar = display_utils.high_fidelity_percent_bar {
    x = 8,
    y = 12,
    w = 37,
    h = 2,
    background = colors.lightGray,
    filled = colors.blue,
    current = colors.cyan,
  } --[[@as display_utils-hfpb]]

  local function draw_lock_screen()
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setBackgroundColor(colors.gray)

    display_utils.fast_box(6, 4, 41, 13, colors.gray)

    term.setCursorPos(15, 5)
    term.write("Locked - Enter password")

    local function fmt_seconds(s)
      return ("%02d:%02d"):format(math.floor(s / 60), s % 60)
    end
    local a, b = "--:--", "--:--"

    local current_song = server_data.song_queue[server_data.song_queue.position] --[[@as song_info]]
    if current_song and server_data.playing then
      playback_bar.percent = (current_song.current_position or 0) / (current_song.length or 1)
      a = fmt_seconds(current_song.current_position or 0)
      b = fmt_seconds(current_song.length or 1)
    else
      playback_bar.percent = 0
    end

    term.setCursorPos(8, 15)
    term.write(a)

    term.setCursorPos(40, 15)
    term.write(b)

    local song_name = "No song currently playing"
    if current_song then
      song_name = current_song.name
    end
    term.setCursorPos(math.floor(w / 2 - #song_name / 2 + 1.5), 10)
    term.write(song_name)

    term.setCursorPos(7, 11)
    term.blit('\x9f' .. ('\x8f'):rep(37) .. '\x90', ('7'):rep(38) .. 'f', ('f'):rep(38) .. '7')
    term.setCursorPos(7, 14)
    term.blit('\x82' .. ('\x83'):rep(37) .. '\x81', ('f'):rep(39), ('7'):rep(39))

    for i = 0, 1 do
      term.setCursorPos(7, 12 + i)
      term.blit('\x95' .. (' '):rep(37) .. '\x95', '7' .. ('f'):rep(38), 'f' .. ('7'):rep(38))
    end

    playback_bar.draw()

    lock_set.draw()
  end

  local blank = { {} }
  for i = 1, 48000 do blank[1][i] = 0 end
  --- Play audio from a given song while simultaneously preloading the given song.
  ---@param song_data song_info The song data, if have both.
  local function play_audio(song_data)
    server_data.state = "loading"
    local function play(the_song)
      parallel.waitForAny(
        function()
          -- Play the music.
          server_data.state = "playing"
          aukit.play(the_song, function(pos)
            while not server_data.playing do
              server_data.state = "paused"
              sleep(1)
            end
            server_data.state = "playing"
            song_data.current_position = pos
          end, 1, peripheral.find "speaker")
        end,
        function()
          -- if stop event received, stop the music playback.
          os.pullEvent "fatmusic:stop"
        end
      )

      server_data.state = "waiting"
    end

    -- Audio is not loaded. Load it then play it.
    local data, err = download_song(song_data)
    if data then
      local loaded, len = load_song(song_data, data)
      if loaded then
        ---@cast len integer

        song_data.length = len
        play(loaded)
        return
      end

      audio_context.error("Failed to load", song_data.name, ":", len)
    end
    audio_context.error("Failed to download", song_data.name, ":", err)
  end

  local function is_user_input(event)
    return event == "char" or event == "key" or event == "key_up" or event == "mouse_click" or event == "mouse_up" or
    event == "mouse_drag" or event == "mouse_scroll" or event == "paste"
  end

  parallel.waitForAny(
    function()
      -- Lockout thread

      while true do
        if not locked then
          draw_lock_icon() -- drawing here forces it to draw even if we have opened a text input field.
        end
        -- what a bodge.
        local event, timer, x, y = os.pullEvent()

        if is_user_input(event) and not locked and should_lock then
          lock_timeout = os.startTimer(60)
        end

        if event == "timer" and timer == lock_timeout and should_lock then
          locked = true
          os.queueEvent("fatmusic:lock_console")
          main_context.info("Automatically locked server console after 60 second timeout.")

          -- Fix buttons:
          config_button.holding = false
          logs_button.holding = false
        elseif should_lock and event == "mouse_click" and timer == 1 and x == w and y == 1 then
          locked = true
        end
      end
    end,
    function()
      -- UI thread

      if locked then
        draw_lock_screen()
      else
        draw_server()
      end

      locked_last_tick = false
      while true do
        if locked_last_tick then
          draw_lock_screen()
          locked_last_tick = false
        end
        local event = table.pack(os.pullEvent())

        if locked then
          lock_set.event(table.unpack(event, 1, event.n))

          if locked then
            draw_lock_screen()
          else
            draw_server()

            lock_timeout = os.startTimer(60)
            main_context.info("User unlocked the server after entering the correct password.")
          end
        else
          was_locking = should_lock

          parallel.waitForAny(
            function()
              set.event(table.unpack(event, 1, event.n))
            end,
            function()
              os.pullEvent("fatmusic:lock_console")
              locked_last_tick = true
              term.redirect(current_term) -- ensure we return to the correct terminal.
              term.setCursorBlink(false)
              main_context.debug("Locked console from parallel")
            end
          )

          draw_server()
        end
      end
    end,
    function()
      -- Audio/Radio thread
      local player_context = logging.create_context "PLAYER"

      while true do
        if server_data.playing then
          local song = get_next_song()
          player_context.debug "Player tick."

          if song then
            server_data.state = "loading"
            player_context.debug "Song exists."
            play_audio(song)
            server_data.state = "waiting"
          else
            server_data.playing = false
            server_data.song_queue.position = 0
          end
        else
          server_data.state = "stopped"
        end

        sleep(1)
      end
    end,
    function()
      -- Remote receiver thread.
      local remote_context = logging.create_context "REMOTE"

      ---@type table<string, fun(request:server_message):table?> No return means to assume status 200.
      local actions = {
        play = function(request)
          server_data.playing = true
          remote_context.debug "Music resumed."
        end,
        pause = function(request)
          server_data.playing = false
          remote_context.debug "Music paused."
        end,
        stop = function(request)
          server_data.playing = false
          os.queueEvent "fatmusic:stop"
          server_data.song_queue.position = math.max(server_data.song_queue.position - 1, 0)
          remote_context.debug "Music stopped."
        end,
        back = function(request)
          os.queueEvent "fatmusic:stop"
          server_data.song_queue.position = math.max(server_data.song_queue.position - 2, 0)
          remote_context.debug "Music rewinded."
        end,
        skip = function(request)
          os.queueEvent "fatmusic:stop"
          remote_context.debug "Current song stopped, should skip to next automatically."
        end,
        skip_to = function(request)
          if not request.position then
            return { code = 400, error = "Expected argument 'position'" }
          end
          server_data.song_queue.position = math.min(#server_data.song_queue, request.position - 1)
          os.queueEvent "fatmusic:stop"
          remote_context.debug(("Skipped to queue position %d."):format(request.position))
        end,
        song = function(request)
          if not request.song then
            return { code = 400, error = "Expected argument 'song'" }
          end
          if #server_data.song_queue >= config.max_playlist then
            return { code = 413, error = "Queue is full." }
          end

          remote_context.debug "Message is table!"
          remote_context.debug(textutils.serialize(request.song, { compact = true }))
          table.insert(server_data.song_queue, request.song)
        end,
        playlist = function(request)
          return { code = 501, error = "Not implemented." }

          -- Can respond 413 "request entity too large" if not enough space in the queue for the playlist.
        end,
        loop = function(request)
          if type(request.loop_status) ~= "boolean" then
            return { code = 400, error = "Expected boolean argument 'loop_status'" }
          end

          server_data.looping = request.loop_status
        end,
        randomize = function(request)
          if type(request.randomize_status) ~= "boolean" then
            return { code = 400, error = "Expected boolean argument 'randomize_status'" }
          end

          server_data.randomized = request.randomize_status
        end,
        clear_queue = function(request)
          server_data.song_queue = { position = 0 }
          server_data.playing = false
          server_data.state = "stopped"
          os.queueEvent "fatmusic:stop"
        end
      }

      while true do
        local packet = comms.receive()
        remote_context.debug "Received message."
        remote_context.debug("Server running:", config.server_running, "State:", server_data.broadcast_state)
        if config.server_running and server_data.broadcast_state == "online" then
          local payload = packet.payload
          if actions[payload.action] then
            remote_context.debug("Action", payload.action, "exists.")
            local response = actions[payload.action](payload)
            comms.send_packet(comms.new_response(packet, response or { code = 200 }),
              CHANNELS.CONTROLS + config.channel_offset)
          else
            remote_context.debug("Action", payload.action, "does not exist!")
            comms.send_packet(comms.new_response(packet, { code = 404, error = "Action does not exist." }),
              CHANNELS.CONTROLS + config.channel_offset)
          end
        end
      end
    end,
    function()
      -- Remote broadcast thread.

      --- Clean the server data table of any unneeded (or private) information.
      ---@return table
      local function clean_data()
        local t = { song_queue = { position = server_data.song_queue.position } }

        for i, song_data in ipairs(server_data.song_queue) do
          ---@diagnostic disable-next-line WHY THE FUCK DO YOU THINK IT'S AN INTEGER??????????
          ---@cast song_data song_info

          t.song_queue[i] = {
            artist = song_data.artist,
            current_position = song_data.current_position,
            length = song_data.length,
            genre = song_data.genre,
            name = song_data.name,
          }
        end

        t.playing = server_data.playing
        t.state = server_data.state
        t.randomized = server_data.randomized
        t.looping = server_data.looping
        return t
      end

      while true do
        sleep(config.data_ping_every)

        if broadcast_state() then
          comms.send_packet(comms.new_packet(
            {
              action = "data",
              data = clean_data()
            }
          ), CHANNELS.DATA_PING + config.channel_offset)
        end
      end
    end
  )

  error("One of the main coroutines have stopped. No error was raised.", 0)
end

local relaunch_n = 0
while true do
  local ok, err = pcall(function()
    if config.type == "client" then
      main_context.debug "Running client."
      run_client()
    elseif config.type == "server" then
      main_context.debug "Running server."
      run_server()
    else
      error(("Unknown config type: %s"):format(config.type), 0)
    end
  end)

  if not ok then
    main_context.error(err)
    local relaunch = display_logs(err)

    if relaunch then
      relaunch_n = relaunch_n + 1
      main_context.warn("Server relaunched after an error.\n  Relaunch count:", relaunch_n)
    else
      term.setBackgroundColor(colors.black)
      term.setCursorPos(1, h)
      error(err, 0)
    end
  end
end
