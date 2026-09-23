package physics;

class Physics
{
    public static inline var epsilon:Float = 0.000001;

    public var velocityX:Float = 0;
    public var velocityY:Float = 0;

    public var accelerationX:Float = 0;
    public var accelerationY:Float = 0;

    public var gravity:Float = 1000;
    public var gravityEnabled:Bool = true;
    public var gravityModifier:Float = 1.0;

    public var dragX:Float = 1000;

    public var maxVelocityX:Float = 128;
    public var maxVelocityY:Float = 2000;

    public var grounded:Bool = false;

    public function new(?gravity:Float = 1000)
    {
        this.gravity = gravity;
    }

    public function reset()
    {
        velocityX = 0;
        velocityY = 0;
        accelerationX = 0;
        accelerationY = 0;
        grounded = false;
        gravityEnabled = true;
        gravityModifier = 1.0;
    }

    public function setVelocity(x:Float, y:Float)
    {
        velocityX = x;
        velocityY = y;
    }

    public function setVelocityX(value:Float)
    {
        velocityX = value;
    }

    public function setVelocityY(value:Float)
    {
        velocityY = value;
    }

    public function inverseVelocityX()
    {
        velocityX = -velocityX;
    }

    public function inverseVelocityY()
    {
        velocityY = -velocityY;
    }

    public function setAcceleration(x:Float, y:Float)
    {
        accelerationX = x;
        accelerationY = y;
    }

    public function setAccelerationX(value:Float)
    {
        accelerationX = value;
    }

    public function setAccelerationY(value:Float)
    {
        accelerationY = value;
    }

    public function enableGravity(enabled:Bool)
    {
        gravityEnabled = enabled;
    }

    public function setGravityModifier(value:Float)
    {
        gravityModifier = value;
    }

    public function integrate(elapsed:Float, ?groundedForFrame:Bool = false)
    {
        if (elapsed <= 0)
        {
            return;
        }

        velocityX += accelerationX * elapsed;

        if (Math.abs(accelerationX) <= epsilon && dragX > 0)
        {
            final dragAmount = dragX * elapsed;

            if (velocityX > 0)
            {
                velocityX = Math.max(0, velocityX - dragAmount);
            }
            else if (velocityX < 0)
            {
                velocityX = Math.min(0, velocityX + dragAmount);
            }
        }

        velocityY += accelerationY * elapsed;

        final applyGravity = gravityEnabled && (!groundedForFrame || velocityY < -epsilon);

        if (applyGravity)
        {
            velocityY += gravity * gravityModifier * elapsed;
        }
        else if (groundedForFrame && velocityY > -epsilon)
        {
            velocityY = 0;
        }

        if (maxVelocityX >= 0)
        {
            if (velocityX > maxVelocityX)
            {
                velocityX = maxVelocityX;
            }
            else if (velocityX < -maxVelocityX)
            {
                velocityX = -maxVelocityX;
            }
        }

        if (maxVelocityY >= 0)
        {
            if (velocityY > maxVelocityY)
            {
                velocityY = maxVelocityY;
            }
            else if (velocityY < -maxVelocityY)
            {
                velocityY = -maxVelocityY;
            }
        }
    }
}
