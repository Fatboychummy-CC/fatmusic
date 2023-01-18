--- Deep copy a table.
---@generic T
---@param t T The value to be copied
---@return T copied The copied value
local function deep_copy(t)
  local tnew = {}

  if type(t) ~= "table" then return t end

  for k, v in pairs(t) do
    if type(v) == "table" then
      tnew[k] = deep_copy(v)
    else
      tnew[k] = v
    end
  end

  return tnew
end

return deep_copy
