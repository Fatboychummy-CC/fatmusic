--- Controls transmission between computers.

local expect = require "cc.expect".expect

local TIMEOUT = 1

local last_id = 0
local system_id = os.getComputerID()

---@class action An action object representing something that the transmitter wants.
---@field public action string The action to be taken.
---@field public data any The data to be bound to the action.
---@field public error string? The error to be bound with the action, if any.

---@class modem
---@field transmit fun(transmit_channel:integer, response_channel:integer, payload:any)

---@class transmission
---@field private _CHANNEL integer The channel this transmission is being broadcasted on.
---@field private _RESPONSE_CHANNEL integer The channel this transmission listens on.
---@field private _MODEM modem The modem to transmit on.
---@field private _MODEM_NAME string The peripheral name of the modem.
local transmission = {}

--- Create a new transmission object.
---@param channel integer The channel to broadcast on.
---@param response_channel integer The channel tro listen for responses on.
---@param modem modem The modem to use.
---@return transmission object The transmission object.
---@nodiscard
function transmission.create(channel, response_channel, modem)
  ---@type transmission
  return setmetatable(
    {
      _CHANNEL = channel,
      _RESPONSE_CHANNEL = response_channel,
      _MODEM = modem,
      _MODEM_NAME = peripheral.getName(modem)
    },
    { __index = transmission }
  )
end

--- Create an action object to be used in transmission:
---@param action any
---@param data any
---@param error any
---@return action
function transmission.make_action(action, data, error)
  expect(1, action, "string")
  expect(3, error, "string", "nil")

  last_id = last_id + 1

  ---@type action
  return {
    action = action,
    data = data,
    error = error,
    transmission_id = last_id,
    system_id = system_id
  }
end

--- Shorthand to ACK a packet.
---@param action action The action to ACK.
---@return action ACK The ack packet.
function transmission.ack(action)
  return transmission.make_action("ack", { transmission_id = action.transmission_id, system_id = action.system_id })
end

--- Shorthand to ERROR a packet.
---@param action action The action to ERROR
---@param error string The error to send
---@return action error The error packet.
function transmission.error(action, error)
  return transmission.make_action("error", action.transmission_id, error)
end

--- Verify an object is an action.
---@param action any The item to verify.
---@return boolean is_action If the object is an action.
function transmission.verify(action)
  return type(action) == "table" and type(action.action) == "string" and type(action.transmission_id) == "number" and
      type(action.system_id) == "number" and (type(transmission.error) == "string" or transmission.error == nil)
end

--- Transmit an action.
---@param self transmission
---@param action action The action to send.
---@param no_ack boolean? If true, ignores waiting for an ACK.
---@return boolean acked Whether or not the action was acknowledged.
---@return string? error The error returned with the acknowledgement, if one. This can appear even if `acked` was true!
function transmission.send(self, action, no_ack)
  expect(1, action, "table")
  if not transmission.verify(action) then
    error("Bad argument #1: Expected action object.", 0)
  end
  local attempts = 0

  repeat
    self._MODEM.transmit(self._CHANNEL, self._RESPONSE_CHANNEL, action)
    if no_ack then
      return false
    end

    local time_elapsed = 0
    repeat
      local start = os.clock()
      local response = self:receive(nil, TIMEOUT - time_elapsed + 0.05)
      time_elapsed = time_elapsed + (os.clock() - start)

      if response then
        if type(response.data) == "table" and
            response.data.system_id == system_id and
            response.data.transmission_id == action.transmission_id then
          if response.action == "ack" then
            return true
          elseif response.action == "error" then
            return true, response.error
          end

          return true, "ACKed with incorrect packet type."
        end
      else
        attempts = attempts + 1
      end
    until time_elapsed >= TIMEOUT or not response
  until attempts >= 5

  return false, "Timed out."
end

--- Receive an action.
---@param self transmission
---@param action_type string? If passed, only return actions of the specified type.
---@param timeout integer Timeout, if passed.
---@overload fun(self:transmission, action_type:string?):action Guaranteed return of an action if no timeout is given.
---@return action? action If a timeout was passed, will return nil on no response.
function transmission.receive(self, action_type, timeout)
  local timer
  if timeout then
    timer = os.startTimer(timeout)
  end

  while true do
    ---@type string, string|integer, integer, integer, any
    local event, side, sent_channel, _, msg = os.pullEvent()

    -- If we receive a message, its from our modem on our response channel, and it's an action...
    -- and we are either listening for no action type, or we are listening for a specific action (and we got that)
    -- return the action
    if event == "modem_message" and side == self._MODEM_NAME and sent_channel == self._RESPONSE_CHANNEL and
        transmission.verify(msg) and (action_type == nil or action_type == msg.action) then
      return msg
    elseif event == "timer" and timer and side == timer then
      return
    end
  end
end

return transmission