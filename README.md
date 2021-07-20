# Custom DPSS Laser
All of the important code for the Custom DPSS laser

## Galil Stage Program
The program that actually runs the stage.

### Usage
1. Check your origin by cutting a cross, then adjusting the crosshair to where the cross was actually cut.
2. NEW: Press and hold the "Zero Origin" button for 3 seconds to update the offset variables (instead of manually updating them in the code)

_Note: The program assumes the stage is in camera view upon startup. If the stage was unable to move before, jog it over to the camera position and zero it._

### Flash the program to the motion controller

1. Download the "_.dmc_" file.
2. Open the program in GalilTools
3. "Download" the program to the controller
4. Execute the program

### Set the program to run on startup

1. Open the Terminal ("Tools" >> "Terminal")
2. Send the BP Command to "Burn the program". _Note: You only need to do this once if you change the program, but just in case the memory is wiped, now you know how to do it._
