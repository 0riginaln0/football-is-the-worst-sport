-- types of messages


return {
    -- from client to server
    cts = {
        input = 0,
        chat_message = 1,
        auth = 2,
    },
    -- from server to client
    stc = {
        id = 0,
        update = 1,
    }
}
