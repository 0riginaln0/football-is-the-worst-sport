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
> - processes incoming user commands
> - runs a physical simulation step
> - checks the game rules
> - updates all object states
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

# Actual coding