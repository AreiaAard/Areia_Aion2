# Areia Aion2

Assist the final battle of the Transcend2 goal.

## Setup

Save the .xml and .lua files in the *same* directory.

If you have my channel manager plugin installed (recommended), set up a channel called `einfo`. If not, either install it and set up that channel, or else open the .lua file, find the `local function einfo`, and change the name of the channel command (the thing in quotation marks) to whatever channel you want the script to use. The advantage of using my channel manager is that you will experience no lag between events occuring and notifications posting.

Once that's done, in Mush, CTRL+SHIFT+P, ALT+A, navigate to the directory in which you saved the plugin, and select the .xml file. You should see a message in the main output window confirming successful installation.

## Usage

the script should be mostly automatic. Simply begin combat with Aion, and the plugin will begin tracking and reporting important events. The main purpose is to help guide you through the more involved minigames, as they are not accessible for some players. If for some reason you do need manually to control the script, the command is `aion2 [on|off]`.

You will probably still need to undergo some trial and error to figure out how to avoid some of the simpler games, how to pierce through Aion's defenses, etc., but for the multi-stage games, this script will indicate in words what you ought to do, rendering all the ASCII maps needless.

## A Note on Botting

With the knowledge and will, one could modify this script to advance through the minigames automatically. One would most likely be best served not to do so. Do, however, feel free to advertize this "Aion2 bot" to other people who might need it--and let others believe you to be a cheater when you beat the puzzles without sight.
