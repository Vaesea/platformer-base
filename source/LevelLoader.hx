package;

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

        /* Add the tile ids here and what they should be.
           I recommend adding comments to the tile property thing. */
        state.map.setTileProperties(0, NONE); // Ignore this, it's always an empty tile!
        state.map.setTileProperties(1, ANY); // Solid tile
        state.map.setTileProperties(2, NONE); // Water (Deeper)
        state.map.setTileProperties(3, NONE); // Water (Deep)
        state.map.setTileProperties(4, NONE); // Water
        state.map.setTileProperties(5, NONE); // Empty Tile
        state.map.setTileProperties(6, NONE); // Decoration 1
        state.map.setTileProperties(7, NONE); // Decoration 2
        state.map.setTileProperties(8, NONE); // Empty Tile
        state.map.setTileProperties(9, NONE); // Decoration 3
        state.map.setTileProperties(10, NONE); // Decoration 4
        state.map.setTileProperties(11, NONE); // Decoration 5
        state.map.setTileProperties(12, NONE); // Decoration 6

        state.add(backgroundMap);
        state.add(state.map);

        // Load goal
        for (object in getLevelObjects(tiledMap, "Level"))
        {
            switch (object.type)
            {
                case "goal": // Will add a checkpoint at some point!
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