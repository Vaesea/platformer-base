package characters.player;

import collision.Collision;
import physics.Physics;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;

class Player extends FlxSprite
{
    // Physics
    public var physics:Physics;

    // Movement
    var playerAcceleration:Int = 2000;
    var deceleration:Int = 1000;
    var gravity:Int = 1000;
    public var minJumpHeight:Int = 320;
    public var maxJumpHeight:Int = 384;
    var walkSpeed:Int = 128;
    var speed:Int = 0;
    var runSpeed:Int = 192;
    var decelerateOnJumpRelease:Float = 0.5;
    var maxFallSpeed = 2000;

    // Ducking
    var ducking:Bool = false;
    
    // Direction
    public var direction:Int = 1;

    public function new()
    {
        super();

        // Image + Animations
        loadGraphic("assets/images/characters/oriopha.png", true, 16, 32);
        animation.add("stand", [0], 8.0, false);
        animation.add("walk", [1, 2, 3, 2], 8.0, true);
        animation.add("jump", [4], 8.0, false);
        animation.add("duck", [5], 8.0, false);
        animation.play("stand");

        // Physics
        physics = new Physics(gravity);

        // Add deceleration (drag) and gravity
        physics.dragX = deceleration;
        physics.maxVelocityX = walkSpeed;
        physics.maxVelocityY = maxFallSpeed;

        // Hitbox
        setSize(9, 26);
        offset.set(4, 6);
    }

    override public function update(elapsed:Float)
    {

        // Stop the player from falling off the map through the left
        if (x < 0)
        {
            x = 0;
        }

        if (x > Global.PS.map.width - this.width)
        {
            x = Global.PS.map.width - this.width;
        }

        // Kill the player when they fall into the void
        if (y > Global.PS.map.height)
        {
            die();
        }

        // Functions
        move();
        animate();

        // Extra safety!
        velocity.set(0, 0);
        acceleration.set(0, 0);
        drag.set(0, 0);

        super.update(elapsed);
    }

    // One frame late but that's ok!
    function animate()
    {
        if (!ducking)
        {
            // If the player is on the floor and staying where they are, stand.
            if (physics.velocityX == 0 && physics.grounded)
            {
                animation.play("stand");
            }

            // If the player is on the floor and moving, walk.
            if (physics.velocityX != 0 && physics.grounded)
            {
                animation.play("walk");
            }

            // If the player is not on the floor, jump.
            // TODO: Is velocity.y != 0 needed?
            if (physics.velocityY != 0 && physics.grounded)
            {
                animation.play("jump");
            }
        }
        else
        {
            animation.play("duck");
        }
    }

    function move()
    {
        // Speed is, by default, 0.
        physics.accelerationX = 0;

        // If CONTROL is being pressed, run, If not, then just walk
        if (FlxG.keys.pressed.CONTROL)
        {
            physics.maxVelocityX = runSpeed;
        }
        else
        {
            physics.maxVelocityX = walkSpeed;
        }

        // If player presses left, move left. If player presses right, move right.
        var duck_on_floor = (ducking && physics.grounded);
        
        if (!duck_on_floor)
        {
            if (FlxG.keys.anyPressed([LEFT, A]))
            {
                flipX = true; // Flip player
                direction = -1; // Set direction
                physics.accelerationX = -playerAcceleration;
            }
            else if (FlxG.keys.anyPressed([RIGHT, D]))
            {
                flipX = false; // Unflip player
                direction = 1; // Set direction
                physics.accelerationX = playerAcceleration;
            }
        }

        // If player is pressing jump keys and is on ground, jump
        // If player is walking at a speed above runSpeed, jump higher than usual
        if (FlxG.keys.anyJustPressed([SPACE, UP, W]) && physics.grounded)
        {
            if (Math.abs(physics.velocityX) > walkSpeed)
            {
                physics.velocityY = -maxJumpHeight;
            }
            else
            {
                physics.velocityY = -minJumpHeight;
            }

            FlxG.sound.play("assets/sounds/jump.ogg");
        }

        if (physics.velocityY < 0 && FlxG.keys.anyJustReleased([SPACE, W, UP]))
        {
            physics.velocityY -= physics.velocityY * decelerateOnJumpRelease;
        }

        // Ducking and standing (I wish there was a better way to do this)
        if (!ducking && physics.grounded && FlxG.keys.anyPressed([DOWN, S]))
        {
            setDucking(true);
        }
        else if (ducking && physics.grounded && !FlxG.keys.anyPressed([DOWN, S]))
        {
            setDucking(false);
        }
    }

    public function die()
    {
        Global.coins = 0;
        FlxG.resetState();
    }

    function setDucking(value:Bool):Bool
    {
        if (value == ducking)
        {
            return true;
        }

        if (value)
        {
            final oldHeight = height;

            setSize(12, 13);
            offset.set(4, 19);

            y += oldHeight - height;
            ducking = true;

            return true;
        }

        final oldHeight = height;
        final newHeight = 26;
        final standY = y - (newHeight - oldHeight);

        if (!Collision.canOccupy(this, Global.PS.solids, x, standY, 9, newHeight))
        {
            return false;
        }

        setSize(9, newHeight);
        offset.set(4, 6);
        y = standY;
        ducking = false;
        return true;
    }
}