Ok, lets keep camera on client and manipulate it only on client

But if we keep camera on client, we calculate the spot on client too. Yes. And we don't need to pass
window height&width to server.

So, let's make it in the following way:
When client connects to the server, server gets free player ID and sends it to client.

Then server sends to the client list of all players, and client itself connects camera to his player-id coordinates, calculates the cursor spot and sends it back to server.


# Controlling your player
## Movement:
The player's movement is controlled by mouse - your player will run after your mouse's cursor.

Depending on your 'slowmoving area radius' settings, the closer the mouse cursor is to your player, the slower he will move.

![alt text](image.png)


# Position

1/2 rule

Position is field by default for all, but when match starts, the server decides who is gonna play gk for the 1st, 2nd half, and additional time 3rd, 4th. And sends a message to chosen peer that it is a goalie. Client receives this message and turns into gk player mode.

Clients can send an "i want to be a goalie for this match" message to the server. And so it will.




# Modelling

Ball
## Exporting
When exporting model from Blockbench, check the `Model Export Scale` setting. Adjust `Model Export Scale` to change the scale of your GLTF (File > Preferences > Settings > search for Model Export Scale).
> By default it is 16, which makes 16 modelling units 1 meter.

