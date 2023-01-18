local expect = require "cc.expect".expect

local utils = {}

--- Returns a function which can be used in parallel to run multiple coroutines
--- as needed. Two other functions are returned that allow you to add and remove
--- coroutines whenever needed.
---
---@return function manager The coroutine manager.
---@return fun(name:string, func:fun()|thread) coroutine_add The function that adds coroutines.
---@return fun(name:string) coroutine_remove The function that removes coroutines.
function utils.editable_coroutine()
  local coroutines = {}
  local filters = {}

  --- Adds a coroutine to be run in the manager.
  ---@param name string The name of the coroutine.
  ---@param func fun()|thread The function to be converted to a coroutine, or a thread.
  local function coroutine_add(name, func)
    expect(1, name, "string")
    expect(2, func, "function", "thread")
    if coroutines[name] then error("A coroutine with that name already exists.", 2) end

    if type(func) == "function" then
      func = coroutine.create(func)
    end


    coroutines[name] = func
  end

  --- Removes a coroutine from the manager.
  ---@param name string The name of the coroutine to be removed.
  local function coroutine_remove(name)
    coroutines[name] = nil
    filters[name] = nil
  end

  --- Coroutine manager.
  local function manager()
    ---@param coro thread The coroutine to resume.
    ---@param name string The coroutine's name.
    ---@param ... any The values to resume with.
    local function resume(coro, name, ...)
      local ok, filter = coroutine.resume(coro, ...)

      -- If the coroutine stopped due to error, throw the error.
      if not ok then
        error(filter, 0)
      end

      filters[name] = filter
    end

    -- Main coroutine loop
    while true do
      -- Gather the event.
      local event = table.pack(os.pullEvent())

      -- Loop through each coroutine and check if it should be resumed.
      for name, coro in pairs(coroutines) do
        -- If filter is the same
        -- Or if filter is not set (take any event)
        -- Or if the event is a terminate event
        if event[1] == filters[name] or event[1] == "terminate" or not filters[name] then
          resume(coro, name, table.unpack(event, 1, event.n))

          -- If the coroutine finished, remove it.
          if coroutine.status(coro) == "dead" then
            coroutine_remove(name)
          end
        end
      end
    end
  end

  return manager, coroutine_add, coroutine_remove
end

return utils
