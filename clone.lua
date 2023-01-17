-- Quick little helper program to help your non-technical friends create a
-- pocket computer with this program on it.

local COPY_DIR = "to_copy"
local files = fs.list(COPY_DIR)
local drive = peripheral.wrap("bottom")

local function find()
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      return turtle.select(i)
    end
  end
end

while true do
  print("Waiting for pocket computer to copy data to...")
  sleep()
  os.pullEvent("turtle_inventory")

  find()
  turtle.dropDown()

  if fs.isDir("disk") then
    for _, file in ipairs(files) do
      local copyname = fs.combine(COPY_DIR, file)
      local filename = fs.combine("disk", file)
      print("Deleting", filename)
      fs.delete(filename)
      print("Copying", copyname, "to", filename)
      fs.copy(copyname, filename)
    end

    drive.setDiskLabel("Audio Player")

    print("All done.")

    turtle.suckDown()
  end

  find()
  turtle.drop()
end
