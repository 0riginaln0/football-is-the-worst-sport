local m = {}

---@class ServerUpdateMessage
---@field players table Must be iterated with for i = 1, 30, 1, because it could have nils inside

---@enum ClientToServerMessage
m.cts = {
    input = 0,
    chat_message = 1,
    auth = 2,
}

---@enum ServerToClientMessage
m.stc = {
    id = 0,
    update = 1,
}

---@enum MessageChannel
m.channel = {
    unsequenced = 0,
    unreliable = 1,
    reliable = 2,
}

return m
