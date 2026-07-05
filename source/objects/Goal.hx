package objects;

import characters.player.Player;
import flixel.FlxG;
import misc.VPBSprite;
import states.MainMenuState;
import states.PlayState;

class Goal extends VPBSprite
{
    public function new(x:Float, y:Float, width:Int, height:Int)
    {
        super(x, y);
        makeSolidGraphic(width, height, ALL);
    }

    public function reach(player:Player)
    {
        if (solid)
        {
            solid = false;
            Global.currentLevel += 1;
        }

        if (Global.currentLevel >= Global.levels.length)
        {
            FlxG.switchState(MainMenuState.new);
        }
        else
        {
            FlxG.switchState(PlayState.new);
        }
    }
}