package states;

import characters.player.Player;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import objects.Coin;
import objects.Goal;
import states.substates.IntroSubState;

class PlayState extends FlxState
{
	// The main tiles.
	public var map:FlxTilemap;

	/* If you add another tileset before the main tileset, 
	   the main tileset will start with a different id. */
	public var startingTile = 1;

	// Add things (Variables)
	public var player(default, null):Player;
	public var items(default, null):FlxTypedGroup<FlxSprite>;
	
	/* If you're planning on adding more things (like enemies)
	   that can't go in the items group, add them to entities!
	   It will save you from having a headache when you start
	   to add enemies! :3 */
	var entities:FlxGroup;

	// TODO: Allow for more checkpoints
	public var checkpoint:FlxPoint;

	override public function create()
	{
		// Just so Global.PS actually works...
		Global.PS = this;

		// Add things part 2
		entities = new FlxGroup();
		player = new Player();
		items = new FlxTypedGroup<FlxSprite>();

		// The number of the level to load
		var numberOfLevel = Global.levels[Global.currentLevel];

		// Load the level
		LevelLoader.loadLevel(this, numberOfLevel);

		// Add things part 3
		entities.add(items);
		add(entities);
		add(player);

		// Camera
		FlxG.camera.follow(player, PLATFORMER);
		FlxG.camera.setScrollBoundsRect(0, 0, map.width, map.height, true);

		openSubState(new IntroSubState(FlxColor.BLACK));
		super.create();
	}

	override public function update(elapsed:Float)
	{
		updateCheckpoint();

		// Tux collision
		FlxG.overlap(entities, player, collideEntities);
		FlxG.collide(map, player);

		super.update(elapsed);
	}

	function collideEntities(entity:FlxSprite, player:Player)
	{
		if (Std.isOfType(entity, Coin))
		{
			(cast entity).collect();
		}
		
		if (Std.isOfType(entity, Goal))
		{
			(cast entity).reach(player);
		}
	}

	function updateCheckpoint()
	{
		if (checkpoint == null || Global.checkpointReached)
		{
			return;
		}

		if (player.x >= checkpoint.x)
		{
			trace("Checkpoint reached!");
			Global.checkpointReached = true;
			trace(Global.checkpointReached);
		}
	}
}
