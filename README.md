AutoRaise & Launcher

This project consists of two components: AutoRaise and Launcher. 

AutoRaise is written and maintained by Stefan Post at https://github.com/sbmpost/AutoRaise. From the readme:

"When AutoRaise is running and you hover the mouse cursor over a window it will be raised to the front (with a delay of your choosing) and gets the focus. There is also an option to warp the mouse to the center of the activated window, using the cmd-tab key combination for example."

See also: https://stackoverflow.com/questions/98310/focus-follows-mouse-plus-auto-raise-on-mac-os-x

While AutoRaise is concerned with GUI window and mouse behaviour, as a command line application it lacks a GUI itself.

Here is where Launcher into play: it's a menubar application that allows to conveniently control and configure AutoRaise. A mouse click on it's menubar icon will start/stop AutoRaise, preferences can be configured from it's context menu and will be saved between sessions.

![AutoRaise Preferences](/Launcher/Prefs.png?raw=true)
