20.04.2025 11:15

# Intro
Yesterday I somehow managed to distinguish the data wich is used in the server and in the client. Today's goal is to finally create a separate `server.lua` file that will run all the world simulation. Let's dive in!

# Thinking about the future

The `server.lua` will be a base for all server match code. So the key moment is to distinguish data, managed by the server and set restrictions on it.

## Connections - 32
- For now I think that maximum of **30 players** in one server will be a reasonable restriction
  - 11vs11 field players
  - 4*2 players on the bench
- **2 reserved** slots for the:
  - admin
  - restreaming the match details into the "streaming or observer" service.

# How the communication between Client-Server works

I've found legit [Valve's docs](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking) on this topic.

> *The server takes snapshots of the current world state at a constant rate and broadcasts these snapshots to the clients.* Network packets take a certain amount of time to travel between the client and the server (i.e. half the ping time). This means that the client time is always a little bit behind the server time  
> ...  
>  the timestep is 15ms, so 66.666... ticks per second are simulated. During each tick, the server:
> 1. processes incoming user commands
> 2. runs a physical simulation step
> 3. checks the game rules
> 4. updates all object states
>
> After simulating a tick, the server decides *if any client needs a world update* and takes a snapshot of the current world state if necessary.   
> - Game data is compressed using *delta compression* to reduce network load. That means the server doesn't send a full world snapshot each time, but rather only changes (a delta snapshot) that happened since the last *acknowledged update*. With each packet sent between the client and server, acknowledge numbers are attached to keep track of their data flow.

My friend MigoMipo has developed [his own game server for HQM game](https://github.com/migomipo/migo-hqm-server), and I asked him to explain to me what an acknowleded update is and how it works:
- Each frame in a game has a number, it is included when the server sends it to the client
- In each input update that the client sends to the server, it includes the number of the most recently received frame. So that is how the server "Acknowledges" the update.

> Usually full (non-delta) snapshots are only sent when a game starts or a client suffers from heavy packet loss for a couple of seconds.  

> A higher tickrate increases the simulation precision, but also requires more CPU power and available bandwidth on both server and client.  
> Clients usually have only a limited amount of available bandwidth. In the worst case, players with a modem connection can't receive more than 5 to 7 KB/sec. If the server tried to send them updates with a higher data rate, packet loss would be unavoidable.

There are additional techniques like Entity interpolation, Input prediction, Lag compenstation which try to minimize low latency advantage and allow a fair game for players with slower connections.

But for today, lets leave them aside and implement basic Client-Server communication with snapshots and diffs.

I think the MigoMipo's [protocol.rs](https://github.com/migomipo/migo-hqm-server/blob/f85a25bf26ee38ffd600f833649fb75c84e470e3/src/protocol.rs) would be quite helpful for me!

# Let's get to coding :)

For a first approximation, let's pass everything as Lua objects. In the future we can optimize the package size using C-structures, bit fields and other ways.

Before we define packet types and packet structure, let's try just passing something between the client and the server.

Useful docs & sources  
- https://lovr.org/docs/enet   
- [Leafo's minimal docs of ENet](https://leafo.net/lua-enet/)    
- [Love2D docs for ENet](https://love2d.org/wiki/lua-enet) (Their docs are actually good)
- [Usergames ENet Tutorial Series](https://www.youtube.com/playlist?list=PLQ9u5jUZr6xP1bUzC-_BWDxIqOZuvdCgl)
- [ENet official site](http://enet.bespin.org/)


Here is a templete for the client-server architecture:
```
my_project/
├── main.lua      (Entry point)
├── client.lua    (Client-specific code)
└── server.lua    (Server-specific code)
```

`main.lua`
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

`client.lua`
```lua
local enet = require 'enet'

local clientpeer = nil
local enetclient = nil
local server_ip_port = 'localhost:6750'

function lovr.load()
   print("Starting as client...")
   enetclient = enet.host_create()
   clientpeer = enetclient:connect(server_ip_port)
end

local function clientSendAndReceive()
   local event = enetclient:service(0)

   -- Send input
   clientpeer:send("I pressed W button")

   -- Receive new state
   if event and event.type == 'receive' then
      print("Received ", event.data, " from ", event.peer)
   end
end

function lovr.update(dt)
   clientSendAndReceive()
end

function lovr.draw()
end

```

`server.lua`
```lua
local enet = require 'enet'

local enethost = nil
local hostevent = nil
local server_ip_port = 'localhost:6750'
local max_peers = 32

local game_data = 1

function lovr.load()
   print("Starting as server...")
   enethost = enet.host_create(server_ip_port, max_peers)
end

local function serverListen()
   hostevent = enethost:service(0)

   if hostevent then
      print("Server detected message type: " .. hostevent.type)
      if hostevent.type == "connect" then
         print(hostevent.peer, "connected.")
      end
      if hostevent.type == "receive" then
         print("Received message: ", hostevent.data, hostevent.peer)
      end
   end
end

local function sendUpdate()
   for i = 1, max_peers do
      local peer = enethost:get_peer(i)
      if peer:state() == 'connected' then
         game_data = game_data + 1
         peer:send(game_data)
      end
   end
end

function lovr.update(dt)
   -- Process incoming user commands
   serverListen()

   -- Run a physical simulation step
   -- Update all objects

   -- Decide if any client needs a world update and take a snapshot of the current world state
   -- if necessary
   sendUpdate()
end

function lovr.draw()
end

```
Run both server and client:
```
lovrc . --client
lovrc . --server
```

We can send just strings as input for ENet's send() function because
> Lua is eight-bit clean and so strings may contain characters with any numeric value, including embedded zeros. That means that you can store any binary data into a string. https://www.lua.org/pil/2.4.html

In the following, we will send() encoded Lua tables representing messages and decode them using the https://luajit.org/ext_buffer.html#serialize

Plans for Implementing client-server architecture in the game:
1. Define messages types
2. Define players pool mapping to peers & authentification
3. Maybe use reliable messages for connect/disconnect/chat

# Final words
So here it is, the template for the client-server architecture is done:
- Client sends inputs and waits for an update world state.
- Server listens for the incoming input and sends updates for connected peers.

Seems like a good start!
