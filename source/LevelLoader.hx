package;

import collision.SlopeSolid;
import collision.Solid;
import flixel.FlxG;
import flixel.FlxState;
import flixel.addons.editors.tiled.TiledMap;
import flixel.addons.editors.tiled.TiledObject;
import flixel.addons.editors.tiled.TiledObjectLayer;
import flixel.addons.editors.tiled.TiledTileLayer;
import flixel.math.FlxPoint;
import flixel.tile.FlxTilemap;
import objects.Coin;
import objects.Goal;
import states.PlayState;

class LevelLoader extends FlxState
{
    public static function loadLevel(state:PlayState, level:String)
    {
        var tiledMap = new TiledMap("assets/data/levels/" + level + ".tmx");

        // Don't remove the custom properties of the base level unless you remove one of the custom properties here!
        var song = tiledMap.properties.get("Music");
        var levelName = tiledMap.properties.get("Level Name");

        Global.levelName = levelName;

        // FlxG.sound.playMusic(song, 1.0, true); only add back if there's a problem
        Global.currentSong = song;

        FlxG.camera.bgColor = tiledMap.backgroundColor;
        
        // Background
        var backgroundLayer:TiledTileLayer = cast tiledMap.getLayer("Background");
        
        var backgroundMap = new FlxTilemap();
        backgroundMap.loadMapFromArray(backgroundLayer.tileArray, tiledMap.width, tiledMap.height, "assets/images/tiles.png", 16, 16, Global.PS.startingTile);
        backgroundMap.solid = false;

        // Interactive / Main
        var interactiveLayer:TiledTileLayer = cast tiledMap.getLayer("Main");

        state.map = new FlxTilemap();
        state.map.loadMapFromArray(interactiveLayer.tileArray, tiledMap.width, tiledMap.height, "assets/images/tiles.png", 16, 16, Global.PS.startingTile);
        state.map.solid = false;

        state.add(backgroundMap);
        state.add(state.map);

        // Load solids
        for (object in getLevelObjects(tiledMap, "Solid"))
        {
            switch (object.type)
            {
                default:
                    state.solids.add(new Solid(object.x, object.y, object.width, object.height));
                case "slope_r":
                    state.solids.add(new SlopeSolid(object.x, object.y, object.width, object.height, true));
                case "slope_l":
                    state.solids.add(new SlopeSolid(object.x, object.y, object.width, object.height, false));
            }
        }

        // Load goal
        for (object in getLevelObjects(tiledMap, "Level"))
        {
            switch (object.type)
            {
                case "goal":
                    state.items.add(new Goal(object.x, object.y, object.width, object.height));
                case "checkpoint":
                    state.checkpoint = new FlxPoint(object.x, object.y - 16);
            }
        }

        // Load coins
        for (object in getLevelObjects(tiledMap, "Objects"))
        {
            switch (object.type)
            {
                case "coin":
                    state.items.add(new Coin(object.x, object.y - 16));
            }
        }
        
        // Don't be like me. Don't remove this.
        var playerThing:TiledObject = getLevelObjects(tiledMap, "Player")[0];
        var playerPosition:FlxPoint = new FlxPoint(playerThing.x, playerThing.y);

        if (Global.checkpointReached)
        {
            playerPosition = state.checkpoint;
        }
        else
        {
            playerPosition.set(playerPosition.x, playerPosition.y);
        }

        state.player.setPosition(playerPosition.x, playerPosition.y - 26);
    }

    public static function getLevelObjects(map:TiledMap, layer:String):Array<TiledObject>
    {
        if ((map != null) && (map.getLayer(layer) != null))
        {
            var objLayer:TiledObjectLayer = cast map.getLayer(layer);
            return objLayer.objects;
        }
        else
        {
            trace("Object layer " + layer + " not found! Also credits to Discover Haxeflixel.");
            return [];
        }
    }
}