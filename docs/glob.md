# Server 
## Hodls
- current frame number

30 length array for players

each player is assigned to its ID (it's position in the array)
each player has its peer
each player has its input
each player has its last_frame

# Has 2 channels
0 channel is for `"Unsequenced"` messages (player input, world output)
1 channel is for `"reliable"` messages (chat)

When server gets "connect" event, it sends the peer its id and reserves player spot
When server gets "receive" event, it checks the id and type of message
When server gets "disconnect" event, it destroys peer and frees player spot

After receiving events server updates world and sends new world state/diff to all available players

# Let's define player input structure

Ok so we must only send player input and screen size

Hmmm... maybe I need to send only `pressed` state of buttons, and not the just_pressed just_released. Because this logic should happen in the server.

# Let's define what we will send back to client

maybe only colliders will be enough?