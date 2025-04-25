# Prefrase

This article should have been written yesterday, but I had a great five hour multiplayer session in Worms Ultimate Mayhem.

Which is kind of related, because
1. Worms Ultimate Mayhem uses Lua
2. In this post, I'll talk about how I prepared my game for multiplayer!

<div style="display: flex; justify-content: center; align-items: center; gap: 20px;">
    <div style="height: 300px;">
        <img src="../res/Worms Ultimate Mayhem loading screen.jpg" alt="Worms Ultimate Mayhem loading screen" style="height: 100%; width: auto;">
    </div>
    <div style="height: 300px;">
        <img src="../res/multiplayer in a nutshell.jpg" alt="Multiplayer in a nutshell" style="height: 100%; width: auto;">
    </div>
</div>


- [Prefrase](#prefrase)
- [Starting point](#starting-point)
- [ENet library overview](#enet-library-overview)
  - [UDP, TCP and something in-between](#udp-tcp-and-something-in-between)
  - [Channel](#channel)
  - [Host](#host)
  - [Address](#address)
  - [Peer](#peer)
  - [Event](#event)
- [What is a state in my game?](#what-is-a-state-in-my-game)
- [Syncing worlds](#syncing-worlds)
  - [Predefining worlds](#predefining-worlds)
  - [Picture overview](#picture-overview)
  - [Define protocol](#define-protocol)
  - [Client: Sending and reveiving messages](#client-sending-and-reveiving-messages)
    - [Creating host and getting server peer](#creating-host-and-getting-server-peer)
    - [Sending message](#sending-message)
    - [Receiving messages](#receiving-messages)
  - [Server: Sending and reveiving messages](#server-sending-and-reveiving-messages)
    - [Host Creation and Player Management](#host-creation-and-player-management)
    - [Server update loop](#server-update-loop)
- [Outro](#outro)
- [Resources](#resources)

# Starting point

The key points in the development of a multiplayer game are determining
- the shared state of the game
- how to update the it
- how to synchronize it between players

Speaking of Worms, it's shared state are the map, worms specs (name, health, coordinates, choosed weapon), projectiles and so on. The state updates (as far as I understood) at players local machines and then updated state is sent to others players. This approach is good for Worms because it's a turn-based game.

But my game is a high-pace football (soccer) simulator where all the players move and interact with the world at the same time.
And in my case, I want to have only one point of updating the game state -  the server. The players (clients) will connect to the server, send the actions they want to perform and accept the updated state.

# ENet library overview
For the further reading, I need to introduce you main ENet concepts from the Lua perspective.

## UDP, TCP and something in-between
ENet library is network communication layer on top of UDP. The primary feature it provides is both `"unsequenced"`, `"unreliable"` and `"reliable"` delivery of packets.
- *Unsequenced* packets are neither guaranteed to arrive, nor do they have any guarantee on the order they arrive.
- *Unreliable* packets arrive in the order in which they are sent, but they aren't guaranteed to arrive.
- *Reliable* packets are guaranteed to arrive, and arrive in the order in which they are sent.

## Channel

Channels in ENet are used to seperate different messages.

Each channel is independently sequenced, and so the delivery status of a packet in one channel will not stall the delivery of other packets in another channel.

For example, if you will send `"reliable"` and `"unsequenced"` messages in the same channel, your `"unsequenced"` messages have a high chance of being blocked by the `"reliable"` ones. Therefore, it's a wise choice to seperate these messages into separate channels.

## Host

A host in networking terminology refers to any device that connects to a network and has an Internet address. Hosts can be any device capable of sending and receiving data over a network, including computers, servers, smartphones, and IoT devices.

## Address

ip:port

"127.0.0.1:8888", "localhost:2232", "*:6767"


## Peer

Peer is any *host* that you have connection to.

The server's peers could be all the clients (players) that are connected to the server. While client's peer could be one server it joined in.

Peers are used to send messages.

## Event

Event is a Lua table with several fields depending on the event type.

|  event.type  | event.peer | event.data | event.channel |
| :----------: | :--------: | :--------: | :-----------: |
|  "receive"   |    peer    |   string   |    number     |
| "disconnect" |    peer    |   number   |               |
|  "connect"   |    peer    |   number   |               |

All of event types have a peer.

When event type is "receive" it's data is a `string` and only this type of event has a channel field which specifies the number of the channel.

Every other event's data is `number`

# What is a state in my game?

In my game I have a global variables for:
- player collider
- cameras
- ground collider
- ball collider
- Window width&height
- Buttons & mouse inputs

To turn my game into multiplayer, the server state should contain

- List of clients with the following info for each entry:
  - player's collider
  - player's camera
  - player's input
  - the width and height of the player's window
- ground collider
- ball collider


# Syncing worlds

From this moment I create `client.lua` and `server.lua` files.

Also I change the `main.lua` file so it runs app according to mode passed via command line args:
```lua
local MODE = {
    CLIENT = 0,
    SERVER = 1
}
local mode = nil

for _, arg in ipairs(arg) do
    if arg == "--server" then
        mode = MODE.SERVER
    elseif arg == "--client" then
        mode = MODE.CLIENT
    end
end
if not mode then
    mode = MODE.CLIENT
end

if mode == MODE.SERVER then
    print("Run in server mode")
    require 'server'
elseif mode == MODE.CLIENT then
    print("Run in client mode")
    require 'client'
end
```

## Predefining worlds
So basically, yes. We need to create identical worlds in both `client.lua` and `server.lua` to be able to sync them.

In `lovr.load()` I initialize game world which looks like this:
```lua
local state = {
    world = nil,
    ground = nil,
    -- others colliders
}

function lovr.load()
    -- World initialization
    state.world = lovr.physics.newWorld({ tags = { "ground", "ball", "ball-area", "player" } })
    state.world:disableCollisionBetween("ball-area", "ball")
    state.world:disableCollisionBetween("ball-area", "ground")
    state.world:disableCollisionBetween("ball-area", "player")
    state.ground = state.world:newBoxCollider(vec3(0, -2, 0), vec3(90, 4, 120))
    state.ground:setFriction(0.2)
    state.ground:setKinematic(true)
    state.ground:setTag("ground")
    -- <players and ball intitialization>
end

```

## Picture overview

While in monolith app the game loop in pseudocode looks like:

```lua
while gameIsRunning do
    local input = GetInput()
    local updatedworld = UpdateWorld(input)
    DrawWorld(updatedworld)
end

```

In client - server approach it looks like:

Client side:
```lua
while gameIsRunning do
    local input = GetInput()
    SendInputToServer(input)

    local newstate = GetNewWorldStateFromServer()
    SetNewWorldState(newstate)

    DrawWorld()
end

```

Server side:
```lua
while gameIsRunning do
    local playersinput = handleIncomingEvents()

    local updatedworld = nil
    for _, input in ipairs(playersinput) do
        updatedworld = updateWorld(input)
    end

    for _, playerpeer in ipairs(connectedplayers) do
        sendUpdatedWorld(playerpeer, updatedworld)
    end
end

```

## Define protocol
First of all, I establish protocol a.k.a. convention over messages types that can be sent.

`protocol.lua`
```lua
return {
    -- from client to server
    cts = {
        auth = 0,
        input = 1,
        chat_message = 2,
    },
    -- from server to client
    stc = {
        id = 0,
        update = 1,
        chat_message = 2,
    }
}
```

## Client: Sending and reveiving messages
### Creating host and getting server peer

First of all we import enet library, create a client host and make a connection to the server

```lua
local enet = require("enet")
local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 3, -- 0 for "unsequenced", 1 for "unreliable", 2 for "reliable"
    peer = nil,
}

-- Data to get from server
local state = {
    host = nil,
    world = nil,
    ground = nil,
}

function lovr.load()
    state.host = enet.host_create(nil, 1, server.channel_count)
    server.peer = state.host:connect(server.address, server.channel_count)
end

```
### Sending message
Defining controls and input table message
```lua
local controls = {
    jump = "d",
    header = "s",
    slide = "d",
    focus = "w",
    look_right = "e",
    look_left = "q",
    zoom_in = "y",
    zoom_out = "t",
    move_camera_up = "h",
    move_camera_down = "g",
    move_camera_higher = "n",
    move_camera_lower = "b",
    increase_fov = "z",
    decrease_fov = "c",
}

local input = {
    type = protocol.cts.input,
    last_received_frame = nil,
    id = nil,

    window_width = 0,
    window_height = 0,

    mouse_x = 0,
    mouse_y = 0,
    mouse_dx = 0,
    mouse_dy = 0,

    wheel_moved_dx = 0,
    wheel_moved_dy = 0,

    lmb_pressed = false,
    rmb_pressed = false,
    mmb_pressed = false,

    jump_button_pressed = false,
    -- other buttons
}
```
I set new states for `input` table entries in callbacks `lovr.mousemoved`, `lovr.resize`, `lovr.wheelmoved`, `lovr.keyreleased`, ` lovr.keypressed`, `lovr.mousepressed` and `lovr.mousereleased`.

And in the beginning of lovr.update I send encoded `input` table to server. I use encoding function from the `string.buffer` LuaJIT's library.
```lua
local buf = require 'string.buffer'

function lovr.update(dt)
    local msg = buf.encode(input)
    if server.peer and input.id then
        server.peer:send(msg, channel.unsequenced, "unsequenced")
    end
end

```

Note that I don't store `"just_released"` or `"just_pressed"` in the `input`, because I send `input` as an `"unsequensed"` message which is not garanteed to arrive.


### Receiving messages

For receiving messages I use the following construction:

```lua
local messages = {}

function lovr.update(dt)
    if state.host then
        local event = state.host:service(0)
        local count, limit = 0, 50
        while event and count < limit do
            if event.type == "receive" then
                table.insert(messages, buf.decode(event.data))
            -- handling other types ov events
            end
            event = state.host:check_events() -- receive any waiting messages
            count = count + 1
        end
    end
end
```

The key points here is that we call `host:service()` which *Wait for events, send and receive any ready packets.* (So actually `peer:send()` doesn't immideatly send the message)

When we received an event, we handle it based on it's type and then call `host:check_events()` which *Checks for any queued events and dispatches one if available. Returns the associated event if something was dispatched*.

In case we get a LOT of events we could stuck forever in a while loop. Therefore we use a counter that limits the while loop, so after we handled N amount of events we exit it.

And after handling events, we read them one by one and applying them to our world state.

```lua
table.clear = require 'table.clear'

local messages = {}

function lovr.update(dt)
    -- sending input

    -- Receiving messages
   
    -- Set updated world info
    for index, data in ipairs(messages) do
        if data.type == protocol.stc.id then
            print("Got id", data.id)
            input.id = data.id
        elseif data.type == protocol.stc.update then
            setUpdatedWorldValues(state.world, data.updated)
        end
    end
    table.clear(messages)
end

```

## Server: Sending and reveiving messages
### Host Creation and Player Management
The server initializes an ENet host configured to accept multiple connections and manages players through a fixed-size array:

```lua
local server = {
    address = 'localhost:6750',
    max_peers = 32,
    channel_count = 3,
    host = nil,
    frame = 0,
}
local players = { -- 30 predefined slots
    { status = "free" }, { status = "free" }, ... -- (30 entries total)
}
```

The server creates its host in `lovr.load` with physics world initialization similar to client-side:
```lua
function lovr.load()
    server.host = enet.host_create(server.address, server.max_peers, server.channel_count)
    state.world = lovr.physics.newWorld(...) -- Authoritative world state
end
```

Setting address as non-nil argument makes host that can be connected to. 

### Server update loop

Handling new events looks the same as in the client, but we store each player's input into it's own reserved index in `players` array.

After input handling we iterate over all active players and and update the world state according to their input.

```lua
for index, player in ipairs(players) do
    if player.status == "occupied" and player.peer and player.input then
        updateWorldState(state.world, player.input)
    end
end
```

After the physics simulation, we take a snapshot of the world (updating the coordinates and properties of other colliders) and send an updated snapshot of the world for each active player.
```lua
local function sendUpdatedSnapshot(snapshot)
    for index, player in ipairs(players) do
        if player.status == "occupied" and player.peer then
            player.peer:send(
                buf.encode({ type = protocol.stc.update, updated = snapshot }),
                channel.unsequenced,
                "unsequenced"
            )
        end
    end
end
```

# Outro

In conclusion, I hope this article gave you an idea of how the client-server multiplayer game could be done with LOVR framework and ENet library.

For the details on handling events and authentication, you can check my repo, specificly [clientserver branch](https://github.com/0riginaln0/football-is-the-worst-sport/tree/clientserver)

For the current state of my game - prototype - this netcode is fine, because it's flexible and makes it easy to edit messages API. But in the future, when API will be stable, there is a big room of optimizations and improvements: delta snapshots, acknowledged messages, minimizing message size by using bitfields or other encoding, usage of compression algorhitms, entity interpolation, input prediction, lag compenstation and so on.

# Resources

- Valve article on multiplayer networks (multiplayer) https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking
- Official ENet documentation http://enet.bespin.org/
- Documentation of enet bindings for Lua https://leafo.net/lua-enet/
- Lua extended enet bindings documentation https://love2d.org/wiki/lua-enet
- LuaJIT serializing https://luajit.org/ext_buffer.html#serialize
- LÖVR framework documentation https://lovr.org/docs/

