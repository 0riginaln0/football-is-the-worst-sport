-- types of messages




return {
    ---@enum ClientToServerMessage
    cts = {
        input = 0,
        chat_message = 1,
        auth = 2,
    },
    ---@enum ServerToClientMessage
    stc = {
        id = 0,
        update = 1,
    }
}
