package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class CreditsState extends FlxState
{
    var creditsText:FlxText;

    var speed = 20;
    var increaseOrDecreaseSpeed = 10;

    override public function create()
    {
        super.create();

        var bg = new FlxSprite();
        bg.loadGraphic("assets/images/menu/title.png", false);
        add(bg);
        
        creditsText = new FlxText(-12, 240, 256, "
        Vaesea - Coding, Level, Art

        AnatolyStev - Coding

        Discover Haxeflixel - Book / PDF - Original
        Code

        CNE-Flixel - HaxeFlixel fork that had
        the original version of the
        makeSolidGraphic function that I put
        in the VPBSprite.hx thing



        Press Space to play.", 8);
        creditsText.setFormat(null, 8, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        creditsText.borderSize = 1.25;
        creditsText.moves = true;
        creditsText.velocity.y = -speed;
        add(creditsText);
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.SPACE)
        {
            FlxG.switchState(PlayState.new); // Switch State
        }
        
        if (FlxG.keys.justPressed.DOWN)
        {
            creditsText.velocity.y -= increaseOrDecreaseSpeed;
        }
        else if (FlxG.keys.justPressed.UP)
        {
            creditsText.velocity.y += increaseOrDecreaseSpeed;
        }
    }
}