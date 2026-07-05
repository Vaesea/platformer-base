package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.ui.FlxButton;

class MainMenuState extends FlxState
{
    var playButton:FlxButton;

    override public function create()
    {
        super.create();

        if (FlxG.sound.music != null) // Check if song is playing, if it is, stop song. This if statement is here just to avoid a really weird crash.
        {
            FlxG.sound.music.stop();
        }

        Global.checkpointReached = false;
        Global.currentLevel = 0;
        Global.coins = 0;

        // Adding Title Screen background
        var bg = new FlxSprite();
        bg.loadGraphic("assets/images/menu/title.png", false);
        add(bg);

        // Adding button, will probably be replaced by an image?
        playButton = new FlxButton(0, 0, "Play Game", clickPlay);
        playButton.screenCenter();
        add(playButton);
    }

    function clickPlay()
    {
        FlxG.switchState(CreditsState.new); // Switch State
    }
}