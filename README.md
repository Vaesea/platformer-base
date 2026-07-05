# Vaesea's Platformer Base
A base for basic platformers made using HaxeFlixel. Will have a 
branch for SuperTux fangames.

## Why This Is Being Made
I decided to make this because I find that I keep making projects 
and copying the source code of my very old fangame version of my
SuperTux mod, PepperTux, specifically the HaxeFlixel version.

This will hopefully be a good base for any platformer game, which 
is why it will have two branches.

## Branches
Both branches will likely be unstable. For stable code, please go 
to the releases.

### Main
This is where the base of this base will be made, just including a
few things like coins and obviously, the player.

### STM1 (Doesn't Exist Yet)
STM1 = SuperTux Milestone 1

This is where all SuperTux Milestone 1 things will be recreated,
except from certain things like menus and the level editor.

## How To Make / Edit Levels
You'll need to install Tiled for this.

Then, you can load any map in the game and edit it. You can also
create new ones using the (not-added-yet) base.tmx level.

## I Found A Bug!
Nice job! Report the bug in the issues.

## I Want To Add Something!
Nice, make sure it's something in SuperTux Milestone 1 and you're 
adding it to the STM1 branch.

## How To Build
You'll need HaxeFlixel, including Lime, Haxe, Flixel-Addons and 
OpenFL for this. If you're on Windows, you'll also need some Visual 
Studio things.

(This section will be expanded later)

You can only compile for the platform you're on, due to the way Lime 
works. I recommend using a virtual machine for Windows or Linux, 
however, for Mac, I recommend asking someone to test the game for you.

You can't compile this base for iOS / Android yet. This will likely be
possible in the future when I add mobile controls.

## Credits
### Code
- Vaesea (PepperTux-Haxe stuff)
- AnatolyStev (PepperTux-Haxe stuff)
- Codename Engine (makeSolidGraphic function from cne-flixel, which was modified here to allow for unisolid objects. This will likely be removed soon)
- SuperTux Team (some player variables are based on supertux's player variables, although they did not make any code for this project, obviously)
- Discover HaxeFlixel (Book / PDF) (Despite some things being changed, the code is still based on Discover HaxeFlixel)
### Art (Main Branch)
- Vaesea
### Art (STM1 Branch)
- SuperTux Team (The art was made for SuperTux Milestone 1)
### Music (Main Branch)
- Vaesea (The drum samples were taken from a Sonic 4 Episode II soundfont, those drum samples were taken from Sonic The Hedgehog 1 and 2. Because of this, I'm not sure that the song can be CC-BY-SA 4.0. although I do allow everyone to use the song, you'll probably need to credit SEGA or Sonic Team)
### Music (STM1 Branch)
- Wansti (The SuperTux Theme used was made for SuperTux Milestone 1)
- Mystical (Salcon)
- Mortimer Twang (Chipdisko)
## Special Thanks
- Haxe (This project obviously uses Haxe)
- HaxeFlixel (This project obviously uses HaxeFlixel)
- SuperTux Team (The STM1 branch is a base for SuperTux fangames)

## Future Additions, Improvements And Fixes
### Beta 2
- [ ] Credits Menu (Will also contain the GPL 3 license text (because this project uses the GPL 3 license) and the MIT license text as HaxeFlixel uses the MIT license)
- [ ] Replacement of Solid Object Layer with FlxTilemap's Tile Properties
- [ ] Checkpoints
- [ ] The warning that appears when entering the level

### Full Release
- [ ] Ducking / Crouching
- [ ] Skidding

### Unconfirmed
- Options Menu (Really, I think this would be bloat for a simple platformer base like this. Anyone using this project would just add their own options menu anyways...)
- Using Echo Flixel (It's quite slow when you have too many dynamic bodies on screen at once)
- Using FlxTilemapExt for state.map (Anyone using this project would probably just do this themselves)
- HUD (Anyone using this project would just add their own HUD anyways so this likely won't be added since it's just bloat for something simple like this...)

## What's The License?
It's the GNU General Public License 3.0. Check the LICENSE file for
more information.
