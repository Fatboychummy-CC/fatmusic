--- The main program for fatmusic. This will setup as either a server or remote.
--- This will also DOWNLOAD any required libraries.

-- TEMPORARY
rednet.open("back")

local file_helper = require "libs.file_helper"
local display_utils = require "libs.display_utils"
local button = require "libs.button"
local ecc = require "libs.ecc"
local logging = require "libs.logging"
local aukit = require "libs.aukit"

local main_context = logging.create_context "Main"
local w, h = term.getSize()

local FILES = {
  CONFIG = "config.lson",
  DUMP_FILE = fs.combine(file_helper.working_directory, ".fatmusic_log_dump")
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
  config.max_history = 20
  config.max_playlist = 9999
  config.broadcast_radio = false
  config.data_ping_every = 5
  config.server_hidden = false
  config.server_running = false
  config.log_level = logging.LOG_LEVEL.DEBUG

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
end

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
    {"button.lua", "libs.button", false, false},
    {"display_utils.lua", "libs.display_utils", false, false},
    {"ecc.lua", "libs.ecc", false, false},
    {"file_helper.lua", "libs.file_helper", false, false},
    {"logging.lua", "libs.logging", false, false}
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

local function server_settings(data)
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

  local server_name_button = set.new {
    x = 17,
    y = 4,
    w = 15,
    h = 1,
    text = config.server_name,
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function()
      -- ...?
    end
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

  local encryption_button = set.new {
    x = 20,
    y = 6,
    w = 15,
    h = 1,
    text = ("\x07"):rep(15),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function()
      -- ...?
    end
  }

  local playlist_length_button = set.new {
    x = 25,
    y = 8,
    w = 4,
    h = 1,
    text = ("%4d"):format(config.max_playlist),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function()
      -- ...?
    end,
  }

  local broadcast_rate_button = set.new {
    x = 46,
    y = 8,
    w = 2,
    h = 1,
    text = ("%2d"):format(config.data_ping_every),
    bg_color = colors.lightGray,
    highlight_bg_color = colors.white,
    txt_color = colors.black,
    highlight_txt_color = colors.black,
    callback = function()
      -- ...?
    end
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
      config.log_level = (config.log_level + 1) % 4
      logging.set_level(config.log_level)
      self.text = ("%1d"):format(config.log_level)
    end
  }

  local function redraw()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- Main box
    display_utils.fast_box(3, 3, w - 4, 11, colors.gray)
    
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)

    term.setCursorPos(4, 4) term.write("Server name:")
    term.setCursorPos(33, 4) term.write("Server hidden:")
    term.setCursorPos(4, 6) term.write("Encryption key:")
    term.setCursorPos(4, 8) term.write("Max playlist length:")
    term.setCursorPos(30, 8) term.write("Broadcast rate:")
    term.setCursorPos(4, 10) term.write("Logging level:")

    -- Information box.
    display_utils.fast_box(10, 15, 40, 3, colors.gray)

    set.draw()
  end

  while true do
    redraw()
    local event = table.pack(os.pullEvent())

    set.event(table.unpack(event, 1, event.n))

    if go_back then
      return
    end
  end
end

local function run_server()
  local set = button.set()

  local server_data = {
    song_queue = {
      position = 0,
    },
    state = "startup", ---@type server_state
    broadcast_state = config.server_hidden and "offline" or "ignore", ---@type server_broadcast_state
    playing = false
  }

  --- Check if the server is in a state which allows it to broadcast data or respond to pings.
  ---@return boolean
  local function broadcast_state()
    return server_data.broadcast_state == "online"
      or server_data.broadcast_state == "ignore"
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
      server_data.song_queue = {position = 0}
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
      server_data.song_queue[server_data.song_queue.position] and server_data.song_queue[server_data.song_queue.position].name
      or "None"
    ))

    -- playlist length
    term.setCursorPos(4, 11)
    term.write(("Playlist length: %20d"):format(
      #server_data.song_queue
    ))

    -- playing
    term.setCursorPos(4, 12)
    term.write(("Playing        : %20s"):format(server_data.playing and "true" or "false"))

    -- draw all the buttons.
    set.draw()
  end

  local song_context = logging.create_context "MUSIC_CONTROL"
  local function get_next_song()
    server_data.song_queue.position = server_data.song_queue.position + 1
    song_context.debug "Increment song queue position"
    song_context.debug(server_data.song_queue.position - 1, "->", server_data.song_queue.position)
    local song = server_data.song_queue[server_data.song_queue.position]
    if song then
      song_context.debug "Got song at position!"
      return song
    else
      song_context.debug "No song at that queue position."
      server_data.song_queue.position = server_data.song_queue.position - 1
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


  local blank = {{}}
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

  parallel.waitForAny(
    function()
      -- UI thread

      draw_server()
      local timer = os.startTimer(1)
      while true do
        local event = table.pack(os.pullEvent())
        set.event(table.unpack(event, 1, event.n))

        if event[1] == "timer" and event[2] == timer then
          timer = os.startTimer(1)
        else
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

      while true do
        local sender, message = rednet.receive("fatmusic")
        remote_context.debug "Received message."
        remote_context.debug("Server running:", config.server_running, "State:", server_data.broadcast_state)
        if config.server_running and server_data.broadcast_state == "online" then
          if type(message) == "table" then
            if message.action == "play" then
              server_data.playing = true
              remote_context.debug "Music resumed."
            elseif message.action == "pause" then
              server_data.playing = false
              remote_context.debug "Music paused."
            elseif message.action == "stop" then
              server_data.playing = false
              os.queueEvent "fatmusic:stop"
              server_data.song_queue.position = math.max(server_data.song_queue.position - 1, 0)
              remote_context.debug "Music stopped."
            elseif message.action == "back" then
              os.queueEvent "fatmusic:stop"
              server_data.song_queue.position = math.max(server_data.song_queue.position - 2, 0)
              remote_context.debug "Music rewinded."
            elseif message.action == "skip" then
              os.queueEvent "fatmusic:stop"
              remote_context.debug "Current song stopped, should skip to next automatically."
            elseif message.action == "skip_to" then
              server_data.song_queue.position = math.min(#server_data.song_queue, message.data - 1)
              os.queueEvent "fatmusic:stop"
              remote_context.debug(("Skipped to queue position %d."):format(message.data))
            elseif message.action == "song" then
              remote_context.debug "Message is table!"
              remote_context.debug(textutils.serialize(message.song, {compact=true}))
              table.insert(server_data.song_queue, message.song)
            end
          end
        end
      end
    end,
    function()
      -- Remote broadcast thread.

      local function clean_data()
        local t = {song_queue = {position = server_data.song_queue.position}}

        for i, song_data in ipairs(server_data.song_queue) do
          ---@diagnostic disable-next-line WHY THE FUCK DO YOU THINK IT'S AN INTEGER??????????
          ---@cast song_data song_info

          t.song_queue[i] = {
            artist = song_data.artist,
            current_position = song_data.current_position,
            length = song_data.length,
            genre = song_data.genre,
            name = song_data.name
          }
        end

        t.playing = server_data.playing
        t.state = server_data.state
        return t
      end

      while true do
        sleep(config.data_ping_every)
        
        if broadcast_state() then
          rednet.broadcast(
            {
              action = "data",
              data = clean_data()
            },
            "fatmusic"
          )
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