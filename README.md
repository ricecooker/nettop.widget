# Nettop Widget for Uberschict

Widget that behaves similarly to the command line tool nettop to show how
your computer is using the network.  The widget is for Uberschict, a desktop 
widget app for OSX.  Good for the curious or paranoid.

Currently the widget shows:
* What hosts you're connected to
* All active network interfaces
* All connections each application has open or listening

How this is useful:
* You can verify that your browser is using your VPN tunnel
* Are you running any unwanted servers or a backdoor?
* See who's connected to you

How this is useless:
* Hostname lookups are reverse dns lookups so it might not tell you much.  For example *all* google services run off of 1e100.net
* Can only spot really poorly written malware

For more information on Ubersicht:
* Site: http://tracesof.net/uebersicht/
* Github repo: https://github.com/felixhageloh/uebersicht
* Widget gallery: http://tracesof.net/uebersicht-widgets/

## Installing
1. Install ubersicht
1. Launch it
1. Go to your widget folder: `Library/Application Support/Übersicht/widgets`
1. Git clone this repo: `git clone https://github.com/ricecooker/nettop.widget.git`
1. Refresh all widgets

## Customizing the look
Coming soon
