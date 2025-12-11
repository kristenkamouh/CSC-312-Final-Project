# JewManji

JewManji is a real-time MIPS assembly game built for the 512×512 bitmap display.
You control a 32×32 goblin, collect randomly spawned coins, race against a shrinking timer bar, and try to survive the difficulty mode you select at the start.

The game consists of three screens:
1. Welcome Screen
2. Game Map
3. Game Over Screen

## Welcome Screen
When assembling and running the program, the first screen prompts the user to enter a choice using one of the following letters (case-insensitive):

- E — Easy mode (30 seconds)
- H — Hard mode (20 seconds)
- I — Impossible mode (10 seconds)

The chosen mode determines the timer duration and the speed at which the time bar decreases during gameplay.

## Game Map
Once a mode is selected, the actual game loads. The score and timer bar appear immediately.
During gameplay:

- The timer bar shrinks in real time. The shrink rate depends on the selected difficulty.
- The last 5 seconds of any mode turn the remaining part of the bar red to signal that the game is nearly over.
- Coins spawn at random positions, and every collision between the goblin and a coin increases the score by 1.
- Score digits are hard-coded pixel patterns, drawn with a black background to improve visibility on the map.
- A sound plays for each collected coin.
- When the timer reaches 0, a different game-over sound plays immediately.

Controls use MMIO keyboard input with the keys:
W A S D → Up, Left, Down, Right.

## Game Over Screen

When the timer reaches 0, the game transitions to the final screen indicating that time has expired.
A sound is played, and the system halts or waits for restart depending on your implementation.



# Files
All the assets are within this repository. Png, HEX with # and HEX with 0x00 are all placed in their respective folders.
Replacing # with 0x00 was done via a python script found in `transistor/.py` where path was entered to get and save the files
