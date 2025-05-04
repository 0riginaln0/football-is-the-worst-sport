-- types of messages


---@class ServerUpdateMessage
---@field arrayOfPlayers table

local m = {}

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

m.channel = {
    unsequenced = 0,
    unreliable = 1,
    reliable = 2,
}

return m
