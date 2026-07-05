package states.substates;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

class IntroSubState extends FlxSubState
{
    // FlxTexts
    var readyText:FlxText;
    var titleText:FlxText;

    // How much time the player should be getting ready to play the level.
    var waitTime = 2;

    override public function create()
    {
        super.create();

        /* Check if song is playing, if it is, stop song. 
           This if statement is here just to avoid a really weird crash. */
        if (FlxG.sound.music != null)
        {
            FlxG.sound.music.stop();
        }

        titleText = new FlxText(0, 5, 0, Global.levelName, 14);
        titleText.setFormat(null, 14, FlxColor.BLACK, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.WHITE);
        titleText.scrollFactor.set();
        titleText.screenCenter(X);
        titleText.borderSize = 1.25;

        readyText = new FlxText(0, 0, 0, "Get Ready!", 14);
        readyText.setFormat(null, 14, FlxColor.BLACK, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.WHITE);
        readyText.scrollFactor.set();
        readyText.screenCenter();
        readyText.borderSize = 1.25;

        add(titleText);
        add(readyText);

        new FlxTimer().start(waitTime, function(_)
        {
            if (Global.currentSong != null) // If it's null and this isn't done, the game will crash.
            {
                FlxG.sound.playMusic(Global.currentSong, 1.0, true);
            }
            close();
        } , 1);
    }
}