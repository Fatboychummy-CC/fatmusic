--- Installer program to install either the client or server.

local args = table.pack(...)

local RUNNING = shell.getRunningProgram()
local DIR = shell.dir()
local NAME = fs.getName(RUNNING)
if NAME:match("wget%.lua") then
  NAME = "installer.lua"
end

local DIR_TO = fs.combine(DIR, args[2] or "")

--- Display how to use this program.
local function usage()
  local old = term.getTextColor()
  term.setTextColor(colors.orange)

  print("USAGE:")
  print(("%s <target> [install-location]"):format(NAME))
  print('\n')
  print("<target>: client or server")
  print()
  print(("[install-location]: Directory to install to, by default the current directory ( /%s )."):format(DIR))

  term.setTextColor(old)
end

---@type table<string, string>
local files_needed
if args[1] == "client" then
  files_needed = {
    ["client.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/client.lua",
    ["deep_copy.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/deep_copy.lua",
    ["transmission.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/transmission.lua",
    ["logging.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/logging.lua",
    ["QIT.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/QIT.lua",
    ["menus.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/menus.lua",
    ["file_helper"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/file_helper.lua"
  }
elseif args[1] == "server" then
  files_needed = {
    ["server.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/server.lua",
    ["deep_copy.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/deep_copy.lua",
    ["transmission.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/transmission.lua",
    ["logging.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/logging.lua",
    ["QIT.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/QIT.lua",
    ["menus.lua"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/menus.lua",
    ["file_helper"] = "https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/file_helper.lua",

    -- EXTERNAL
    ["aukit.lua"] = "https://raw.githubusercontent.com/MCJack123/AUKit/master/aukit.lua"
  }
else
  usage()
  print()
  printError("Unknown target:", args[1])
  return
end

if not fs.exists(DIR_TO) then
  fs.makeDir(DIR_TO)
end

if fs.exists(DIR_TO) and not fs.isDir(DIR_TO) then
  error("That's a file, bruv.", 0)
end

print()
local w = term.getSize()
local _, y = term.getCursorPos()
local function progress(n, filename)
  local fill = math.floor(n * (w - 2))
  term.setCursorPos(1, y - 1)
  term.clearLine()
  term.write(filename)
  term.setCursorPos(1, y)

  term.write('[')
  term.write(('\x7F'):rep(fill))
  term.write(('\xB7'):rep(w - 2 - fill))
  term.write(']')
end

local count = 0
for _ in pairs(files_needed) do count = count + 1 end

local i = 0
for filename, remote in pairs(files_needed) do
  local output_file = fs.combine(DIR_TO, filename)

  progress(i / count, filename)
  i = i + 1

  local handle, err = http.get(remote)
  if not handle then
    print()
    error(err, 0)
  end

  local data = handle.readAll()
  handle.close()

  io.open(output_file, 'w'):write(data):close()
end

progress(1, "Done.")
