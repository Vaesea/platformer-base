package collision;

import flixel.FlxObject;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxDirectionFlags;
import physics.Physics;

typedef CollisionHit =
{
    var normalX:Int;
    var normalY:Int;
    var other:FlxObject;
}

typedef PenetrationHit =
{
    var depth:Float;
    var normalX:Int;
    var normalY:Int;
}

class Collision
{
    public static inline var skin:Float = 0.01;
    public static inline var time_epsilon:Float = 0.000001;
    public static inline var move_epsilon:Float = 0.000001;

    public static inline var slope_ground_tolerance:Float = 0.10;

    public static inline var max_step_pixels:Float = 1.0;
    public static inline var max_substeps:Int = 64;

    public static function resolve(body:FlxObject, solids:FlxGroup, physics:Physics, elapsed:Float, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        if (body == null || solids == null || physics == null || elapsed <= 0)
        {
            return false;
        }

        if (!body.exists || !body.alive || !body.active || !body.moves || !body.solid || body.immovable)
        {
            return false;
        }

        body.touching = NONE;

        final wasGrounded = physics.grounded && physics.velocityY >= -move_epsilon;

        if (!wasGrounded)
        {
            physics.groundSlope = 0.0;
        }

        depenetrateRectangles(body, solids);
        depenetrateSlopes(body, solids);

        physics.grounded = false;

        if (physics.velocityY < -move_epsilon)
        {
            physics.grounded = false;
        }

        physics.integrate(elapsed, wasGrounded);

        if (physics.velocityY < -move_epsilon)
        {
            physics.grounded = false;
            physics.groundSlope = 0.0;
        }

        final initialHorizontalMultiplier = wasGrounded ? physics.horizontalMovementMultiplier() : 1.0;
        final totalDX = physics.velocityX * elapsed * initialHorizontalMultiplier;
        final totalDY = physics.velocityY * elapsed;

        final largestDistance = Math.max(Math.abs(totalDX), Math.abs(totalDY));

        var substeps = Std.int(Math.ceil(largestDistance / max_step_pixels));

        if (substeps < 1)
        {
            substeps = 1;
        }

        if (substeps > max_substeps)
        {
            substeps = max_substeps;
        }

        final stepTime = elapsed / substeps;
        var collided = false;

        for (_ in 0...substeps)
        {
            final oldX = body.x;
            final oldY = body.y;

            final stepDY = physics.velocityY * stepTime;

            final supportedBeforeHorizontal = physics.grounded || (wasGrounded && physics.velocityY >= -move_epsilon);

            final horizontalMultiplier = supportedBeforeHorizontal && physics.velocityY >= -move_epsilon ? physics.horizontalMovementMultiplier() : 1.0;

            final stepDX = physics.velocityX * stepTime * horizontalMultiplier;

            if (Math.abs(stepDX) > move_epsilon)
            {
                body.x += stepDX;

                if (supportedBeforeHorizontal && physics.velocityY >= -move_epsilon && followGroundAfterHorizontalMove(body, solids, oldX, oldY, stepDX, physics, onCollision))
                {
                    collided = true;
                }

                if (resolveHorizontalRectangles(body, solids, oldX, oldY, stepDX, physics, onCollision))
                {
                    collided = true;
                }
            }

            if (Math.abs(stepDY) > move_epsilon)
            {
                final verticalOldX = body.x;
                body.y += stepDY;

                if (resolveVerticalRectangles(body, solids, verticalOldX, oldY, stepDY, physics, onCollision))
                {
                    collided = true;
                }
            }

            if (resolveSlopeContacts(body, solids, oldX, oldY, body.x, body.y, stepDX, stepDY, physics, onCollision))
            {
                collided = true;
            }

            if (supportedBeforeHorizontal && Math.abs(stepDX) <= move_epsilon && physics.velocityY >= -move_epsilon && !physics.grounded && maintainGround(body, solids, oldX, oldY, 0, physics, onCollision))
            {
                collided = true;
            }
        }

        if (!physics.grounded)
        {
            physics.groundSlope = 0.0;
        }

        body.velocity.x = physics.velocityX;
        body.velocity.y = physics.velocityY;

        return collided;
    }

    public static function resolveGroup<T:FlxObject>(group:FlxTypedGroup<T>, solids:FlxGroup, physicsFor:T->Physics, elapsed:Float, ?onCollision:FlxObject->FlxObject->Void)
    {
        if (group == null || solids == null || physicsFor == null)
        {
            return;
        }

        for (member in group.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            final physics = physicsFor(member);

            if (physics == null)
            {
                continue;
            }

            resolve(member, solids, physics, elapsed, onCollision);
        }
    }

    public static function canOccupy(body:FlxObject, solids:FlxGroup, x:Float, y:Float, width:Float, height:Float):Bool
    {
        if (body == null || solids == null || width <= 0 || height <= 0)
        {
            return false;
        }

        var testX = x;
        var testY = y;
        var testWidth = width;
        var testHeight = height;

        final targetBottom = y + height;
        final currentBottom = body.y + body.height;

        final sameHorizontalBounds = Math.abs(x - body.x) <= skin && Math.abs(width - body.width) <= skin;
        final sameFeet = Math.abs(targetBottom - currentBottom)  <= Math.max(skin * 2, slope_ground_tolerance);

        final growsUpward = y < body.y - move_epsilon;

        if (sameHorizontalBounds && sameFeet && growsUpward)
        {
            testHeight = body.y - y;

            if (testHeight <= move_epsilon)
            {
                return true;
            }
        }

        final right = testX + testWidth;
        final bottom = testY + testHeight;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            if (!Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solidObject:FlxObject = cast member;

            if (solidObject == body || !solidObject.active || !solidObject.solid)
            {
                continue;
            }

            if (Std.isOfType(solidObject, SlopeSolid))
            {
                final slope:SlopeSolid = cast solidObject;

                if (slope.width <= 0 || slope.height <= 0)
                {
                    continue;
                }

                if (slope.collideAABB(testX, testY, testWidth, testHeight) != null)
                {
                    return false;
                }

                continue;
            }

            final solid:FlxObject = solidObject;

            if (solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            final solidRight = solid.x + solid.width;
            final solidBottom = solid.y + solid.height;

            if (right > solid.x + skin && testX < solidRight - skin && bottom > solid.y + skin && testY < solidBottom - skin)
            {
                return false;
            }
        }

        return true;
    }

    static function isSlopeTopTransition(body:FlxObject, solids:FlxGroup, solid:FlxObject, referenceX:Float, referenceY:Float, moveX:Float, physics:Physics):Bool
    {
        if (!physics.grounded || Math.abs(moveX) <= move_epsilon)
        {
            return false;
        }

        final feetY = referenceY + body.height;
        final tolerance = slope_ground_tolerance + skin;
        final slopeEpsilon = 0.5;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            if (!Std.isOfType(member, SlopeSolid))
            {
                continue;
            }

            final slope:SlopeSolid = cast member;

            if (!slope.active || !slope.solid || slope.width <= 0 || slope.height <= 0)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, -1))
            {
                continue;
            }

            final currentSurface = slope.surfaceYForBody(referenceX, body.width);

            if (currentSurface == null || Math.abs(feetY - currentSurface) > tolerance)
            {
                continue;
            }

            final movesTowardHighEnd = slope.risesRight ? moveX > move_epsilon : moveX < -move_epsilon;

            if (!movesTowardHighEnd)
            {
                continue;
            }

            final highX = slope.risesRight ? slope.x + slope.width : slope.x;
            final highY = slope.y;

            if (Math.abs(solid.y - highY) > slopeEpsilon)
            {
                continue;
            }

            final sameEndpoint = slope.risesRight ? Math.abs(solid.x - highX) <= slopeEpsilon : Math.abs((solid.x + solid.width) - highX) <= slopeEpsilon;

            if (!sameEndpoint)
            {
                continue;
            }

            if (!slope.overlapsHorizontally(referenceX, body.width))
            {
                continue;
            }

            if (slope.risesRight)
            {
                if (referenceX >= highX + tolerance)
                {
                    continue;
                }
            }
            else if (referenceX + body.width <= highX - tolerance)
            {
                continue;
            }

            return true;
        }

        return false;
    }

    static function resolveHorizontalRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        final movingRight = moveX > move_epsilon;
        final movingLeft = moveX < -move_epsilon;

        var found = false;
        var bestX = body.x;
        var bestOther:FlxObject = null;
        var bestNormalX = 0;
        var bestDistance = Math.POSITIVE_INFINITY;

        final oldRight = oldX + body.width;
        final newRight = body.x + body.width;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid))
            {
                continue;
            }

            if (!Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (body.y + body.height <= solid.y || body.y >= solid.y + solid.height)
            {
                continue;
            }

            final solidRight = solid.x + solid.width;

            if (movingRight && oldRight <= solid.x + time_epsilon && newRight > solid.x - skin && canCollide(body.allowCollisions, solid.allowCollisions, -1, 0) && !isSlopeTopTransition(body, solids, solid, oldX, oldY, moveX, physics))
            {
                final candidateX = solid.x - body.width - skin;
                final distance = Math.abs(candidateX - body.x);

                if (distance < bestDistance)
                {
                    found = true;
                    bestDistance = distance;
                    bestX = candidateX;
                    bestOther = solid;
                    bestNormalX = -1;
                }
            }
            else if (movingLeft && oldX >= solidRight - time_epsilon && body.x < solidRight + skin && canCollide(body.allowCollisions, solid.allowCollisions, 1, 0) && !isSlopeTopTransition(body, solids, solid, oldX, oldY, moveX, physics))
            {
                final candidateX = solidRight + skin;
                final distance = Math.abs(candidateX - body.x);

                if (distance < bestDistance)
                {
                    found = true;
                    bestDistance = distance;
                    bestX = candidateX;
                    bestOther = solid;
                    bestNormalX = 1;
                }
            }
        }

        if (!found)
        {
            return false;
        }

        body.x = bestX;

        if (bestNormalX < 0)
        {
            body.touching |= RIGHT;
        }
        else
        {
            body.touching |= LEFT;
        }

        physics.velocityX = 0;

        if (onCollision != null && bestOther != null)
        {
            onCollision(body, bestOther);
        }

        return true;
    }

    static function resolveVerticalRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, moveY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        final movingUp = moveY < -move_epsilon;
        final movingDown = moveY > move_epsilon;

        if (movingUp)
        {
            return resolveVerticalCeilingRectangles(body, solids, oldX, oldY, physics, onCollision);
        }

        if (movingDown)
        {
            return resolveVerticalFloorRectangles(body, solids, oldX, oldY, physics, onCollision);
        }

        return false;
    }

    static function resolveVerticalFloorRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        final oldBottom = oldY + body.height;
        final newBottom = body.y + body.height;

        var found = false;
        var bestY = body.y;
        var bestDistance = Math.POSITIVE_INFINITY;
        var bestOther:FlxObject = null;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid) || !Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (body.x + body.width <= solid.x || body.x >= solid.x + solid.width)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, solid.allowCollisions, 0, -1))
            {
                continue;
            }

            if (oldBottom <= solid.y + slope_ground_tolerance && newBottom >= solid.y - skin)
            {
                final candidateY = solid.y - body.height - skin;
                final distance = Math.abs(candidateY - body.y);

                if (distance < bestDistance)
                {
                    found = true;
                    bestDistance = distance;
                    bestY = candidateY;
                    bestOther = solid;
                }
            }
        }

        if (!found)
        {
            return false;
        }

        body.y = bestY;
        body.touching |= DOWN;
        physics.velocityY = 0;
        physics.grounded = true;
        physics.groundSlope = 0.0;

        if (onCollision != null && bestOther != null)
        {
            onCollision(body, bestOther);
        }

        return true;
    }

    static function resolveVerticalCeilingRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        final oldTop = oldY;
        final newTop = body.y;

        var found = false;
        var bestY = body.y;
        var bestDistance = Math.POSITIVE_INFINITY;
        var bestOther:FlxObject = null;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid) || !Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (body.x + body.width <= solid.x || body.x >= solid.x + solid.width)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, solid.allowCollisions, 0, 1))
            {
                continue;
            }

            final ceilingY = solid.y + solid.height;

            if (oldTop >= ceilingY - slope_ground_tolerance && newTop <= ceilingY + skin)
            {
                final candidateY = ceilingY + skin;
                final distance = Math.abs(candidateY - body.y);

                if (distance < bestDistance)
                {
                    found = true;
                    bestDistance = distance;
                    bestY = candidateY;
                    bestOther = solid;
                }
            }
        }

        if (!found)
        {
            return false;
        }

        body.y = bestY;
        body.touching |= UP;
        physics.velocityY = 0;
        physics.grounded = false;

        if (onCollision != null && bestOther != null)
        {
            onCollision(body, bestOther);
        }

        return true;
    }

    static function resolveSlopeContacts(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, endX:Float, endY:Float, moveX:Float, moveY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        var anyResolved = false;

        for (_ in 0...2)
        {
            var resolvedThisPass = false;

            for (member in solids.members)
            {
                if (member == null || !member.exists || !member.alive)
                {
                    continue;
                }

                if (!Std.isOfType(member, SlopeSolid))
                {
                    continue;
                }

                final slope:SlopeSolid = cast member;

                if (!slope.active || !slope.solid || slope.width <= 0 || slope.height <= 0)
                {
                    continue;
                }

                final hit = slope.collideAABB(body.x, body.y, body.width, body.height);

                if (hit == null)
                {
                    continue;
                }

                if (hit.feature == 0 && hit.normalY < -move_epsilon)
                {
                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, -1))
                    {
                        continue;
                    }

                    final surfaceY = slope.surfaceYForBody(body.x, body.width);

                    if (surfaceY != null)
                    {
                        body.y = surfaceY - body.height - skin;
                    }
                    else
                    {
                        body.y += hit.normalY * (hit.depth + skin);
                    }

                    body.touching |= DOWN;
                    physics.velocityY = 0;
                    physics.grounded = true;
                    physics.groundSlope = slope.surfaceSlope;
                    resolvedThisPass = true;
                    anyResolved = true;

                    if (onCollision != null)
                    {
                        onCollision(body, slope);
                    }

                    continue;
                }

                if (hit.feature == 0 && hit.normalY > move_epsilon)
                {
                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, 1))
                    {
                        continue;
                    }

                    final ceilingY = slope.ceilingYForBody(body.x, body.width);

                    if (ceilingY != null)
                    {
                        body.y = ceilingY + skin;
                    }
                    else
                    {
                        body.y += hit.normalY * (hit.depth + skin);
                    }

                    body.touching |= UP;

                    if (physics.velocityY < 0)
                    {
                        physics.velocityY = 0;
                    }

                    physics.grounded = false;
                    physics.groundSlope = 0.0;
                    resolvedThisPass = true;
                    anyResolved = true;

                    if (onCollision != null)
                    {
                        onCollision(body, slope);
                    }

                    continue;
                }

                final normalX = hit.normalX;
                final normalY = hit.normalY;

                if (Math.abs(normalX) >= Math.abs(normalY))
                {
                    final collisionNormalX = normalX < 0 ? -1 : 1;

                    if (!canCollide(body.allowCollisions, slope.allowCollisions, collisionNormalX, 0))
                    {
                        continue;
                    }

                    body.x += normalX * (hit.depth + skin);

                    if (normalX < 0)
                    {
                        body.touching |= RIGHT;
                    }
                    else
                    {
                        body.touching |= LEFT;
                    }

                    if (physics.velocityX * normalX < 0)
                    {
                        physics.velocityX = 0;
                    }

                    resolvedThisPass = true;
                    anyResolved = true;
                }
                else
                {
                    final collisionNormalY = normalY < 0 ? -1 : 1;

                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, collisionNormalY))
                    {
                        continue;
                    }

                    body.y += normalY * (hit.depth + skin);

                    if (normalY < 0)
                    {
                        body.touching |= DOWN;
                        physics.velocityY = 0;
                        physics.grounded = true;
                        physics.groundSlope = 0.0;
                    }
                    else
                    {
                        body.touching |= UP;

                        if (physics.velocityY < 0)
                        {
                            physics.velocityY = 0;
                        }

                        physics.grounded = false;
                        physics.groundSlope = 0.0;
                    }

                    resolvedThisPass = true;
                    anyResolved = true;
                }

                if (resolvedThisPass && onCollision != null)
                {
                    onCollision(body, slope);
                }
            }

            if (!resolvedThisPass)
            {
                break;
            }
        }

        return anyResolved;
    }

    static function followGroundAfterHorizontalMove(body:FlxObject, solids:FlxGroup, referenceX:Float, referenceY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        if (physics.velocityY < -move_epsilon)
        {
            return false;
        }

        final referenceBottom = referenceY + body.height;
        final supportEpsilon = slope_ground_tolerance + skin;

        var bestFlat:FlxObject = null;
        var bestFlatY = 0.0;
        var bestFlatDistance = Math.POSITIVE_INFINITY;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid) || !Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (body.x + body.width <= solid.x || body.x >= solid.x + solid.width)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, solid.allowCollisions, 0, -1))
            {
                continue;
            }

            if (referenceBottom > solid.y + move_epsilon)
            {
                continue;
            }

            final distance = Math.abs(referenceBottom - solid.y);

            if (distance <= supportEpsilon && distance < bestFlatDistance)
            {
                bestFlatDistance = distance;
                bestFlatY = solid.y;
                bestFlat = solid;
            }
        }

        var bestSlope:SlopeSolid = null;
        var bestSurface = 0.0;
        var bestSlopeDistance = Math.POSITIVE_INFINITY;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            if (!Std.isOfType(member, SlopeSolid))
            {
                continue;
            }

            final slope:SlopeSolid = cast member;

            if (!slope.active || !slope.solid || slope.width <= 0 || slope.height <= 0)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, -1))
            {
                continue;
            }

            final nextSurface = slope.surfaceYForBody(body.x, body.width);

            if (nextSurface == null)
            {
                continue;
            }

            final referenceSurface = slope.surfaceYForBody(referenceX, body.width);

            final bodySpanHeight = body.width * slope.gradient;
            final movementHeight = Math.abs(moveX) * slope.gradient;
            final maximumAcquisitionHeight = bodySpanHeight + movementHeight + supportEpsilon;

            if (referenceSurface != null)
            {
                final previousSurfaceOffset = Math.abs(referenceBottom - referenceSurface);

                if (previousSurfaceOffset > bodySpanHeight + supportEpsilon)
                {
                    continue;
                }

                final surfaceTravel = Math.abs(nextSurface - referenceSurface);

                if (surfaceTravel > movementHeight + supportEpsilon)
                {
                    continue;
                }
            }
            else if (Math.abs(nextSurface - referenceBottom) > maximumAcquisitionHeight)
            {
                continue;
            }

            final distance = Math.abs(nextSurface - referenceBottom);

            if (distance > maximumAcquisitionHeight)
            {
                continue;
            }

            if (distance < bestSlopeDistance)
            {
                bestSlopeDistance = distance;
                bestSurface = nextSurface;
                bestSlope = slope;
            }
        }

        if (bestFlat == null && bestSlope == null)
        {
            return false;
        }

        if (bestFlat != null && (bestSlope == null || bestFlatDistance <= bestSlopeDistance))
        {
            body.y = bestFlatY - body.height - skin;
            body.touching |= DOWN;
            physics.velocityY = 0;
            physics.grounded = true;
            physics.groundSlope = 0.0;

            if (onCollision != null)
            {
                onCollision(body, bestFlat);
            }

            return true;
        }

        final slopeBlocker = constrainUphillSlopeMovement(body, solids, referenceX, referenceY, body.x, bestSlope, physics);

        if (slopeBlocker != null)
        {
            if (onCollision != null)
            {
                onCollision(body, slopeBlocker);
            }

            return true;
        }

        body.y = bestSurface - body.height - skin;
        body.touching |= DOWN;
        physics.velocityY = 0;
        physics.grounded = true;
        physics.groundSlope = bestSlope.surfaceSlope;

        if (onCollision != null)
        {
            onCollision(body, bestSlope);
        }

        return true;
    }

    static function constrainUphillSlopeMovement(body:FlxObject, solids:FlxGroup, startX:Float, startY:Float, endX:Float, slope:SlopeSolid, physics:Physics):Null<FlxObject>
    {
        if (slope == null || Math.abs(endX - startX) <= move_epsilon)
        {
            return null;
        }

        final endSurface = slope.surfaceYForBody(endX, body.width);

        if (endSurface == null)
        {
            return null;
        }

        final endBodyY = endSurface - body.height - skin;

        if (endBodyY >= startY - move_epsilon)
        {
            return null;
        }

        final blockingAtEnd = blockingRectangleAt(body, solids, endX, endBodyY);

        if (blockingAtEnd == null)
        {
            return null;
        }

        if (blockingRectangleAt(body, solids, startX, startY) != null)
        {
            return null;
        }

        var lo = 0.0;
        var hi = 1.0;

        for (_ in 0...18)
        {
            final mid = (lo + hi) * 0.5;

            final testX = startX + (endX - startX) * mid;
            final testSurface = slope.surfaceYForBody(testX, body.width);

            if (testSurface == null)
            {
                lo = mid;
                continue;
            }

            final testY = testSurface - body.height - skin;

            if (blockingRectangleAt(body, solids, testX, testY) != null)
            {
                hi = mid;
            }
            else
            {
                lo = mid;
            }
        }

        final safeT = Math.max(0.0, lo - 0.0001);
        final safeX = startX + (endX - startX) * safeT;
        final safeSurface = slope.surfaceYForBody(safeX, body.width);

        if (safeSurface == null)
        {
            return null;
        }

        body.x = safeX;
        body.y = safeSurface - body.height - skin;
        physics.velocityX = 0;
        physics.velocityY = 0;
        physics.grounded = true;
        physics.groundSlope = slope.surfaceSlope;
        body.touching |= DOWN;

        return blockingAtEnd;
    }

    static function blockingRectangleAt(body:FlxObject, solids:FlxGroup, x:Float, y:Float):Null<FlxObject>
    {
        final right = x + body.width;
        final bottom = y + body.height;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid))
            {
                continue;
            }

            if (!Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, solid.allowCollisions, 0, 1))
            {
                continue;
            }

            final solidRight = solid.x + solid.width;
            final solidBottom = solid.y + solid.height;

            if (right > solid.x && x < solidRight && bottom > solid.y && y < solidBottom)
            {
                return solid;
            }
        }

        return null;
    }

    static function maintainGround(body:FlxObject, solids:FlxGroup, referenceX:Float, referenceY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void):Bool
    {
        if (physics.velocityY < -move_epsilon)
        {
            return false;
        }

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive || member == body)
            {
                continue;
            }

            if (Std.isOfType(member, SlopeSolid) || !Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            if (body.x + body.width <= solid.x || body.x >= solid.x + solid.width)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, solid.allowCollisions, 0, -1))
            {
                continue;
            }

            final bodyBottom = body.y + body.height;

            if (bodyBottom > solid.y + move_epsilon)
            {
                continue;
            }

            if (Math.abs(bodyBottom - solid.y) <= slope_ground_tolerance)
            {
                body.y = solid.y - body.height - skin;
                body.touching |= DOWN;
                physics.velocityY = 0;
                physics.grounded = true;
                physics.groundSlope = 0.0;

                if (onCollision != null)
                {
                    onCollision(body, solid);
                }

                return true;
            }
        }

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            if (!Std.isOfType(member, SlopeSolid))
            {
                continue;
            }

            final slope:SlopeSolid = cast member;

            if (!slope.active || !slope.solid || slope.width <= 0 || slope.height <= 0)
            {
                continue;
            }

            if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, -1))
            {
                continue;
            }

            final surfaceY = slope.surfaceYForBody(body.x, body.width);

            if (surfaceY == null)
            {
                continue;
            }

            final currentBottom = body.y + body.height;
            final surfaceDelta = currentBottom - surfaceY;
            final maximumDownhillChange = Math.abs(moveX) * slope.gradient + slope_ground_tolerance + skin;

            if (surfaceDelta > slope_ground_tolerance || surfaceDelta < -maximumDownhillChange)
            {
                continue;
            }

            final referenceSurface = slope.surfaceYForBody(referenceX, body.width);

            if (referenceSurface != null)
            {
                final referenceDelta = referenceY + body.height - referenceSurface;

                if (Math.abs(referenceDelta) > slope_ground_tolerance)
                {
                    continue;
                }
            }

            body.y = surfaceY - body.height - skin;
            body.touching |= DOWN;
            physics.velocityY = 0;
            physics.grounded = true;
            physics.groundSlope = slope.surfaceSlope;

            if (onCollision != null)
            {
                onCollision(body, slope);
            }

            return true;
        }

        return false;
    }

    static function depenetrateSlopes(body:FlxObject, solids:FlxGroup)
    {
        for (_ in 0...4)
        {
            var moved = false;

            for (member in solids.members)
            {
                if (member == null || !member.exists || !member.alive)
                {
                    continue;
                }

                if (!Std.isOfType(member, SlopeSolid))
                {
                    continue;
                }

                final slope:SlopeSolid = cast member;

                if (!slope.active || !slope.solid || slope.width <= 0 || slope.height <= 0)
                {
                    continue;
                }

                final hit = slope.collideAABB(body.x, body.y, body.width, body.height);

                if (hit == null)
                {
                    continue;
                }

                if (hit.feature == 0 && hit.normalY < -move_epsilon)
                {
                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, -1))
                    {
                        continue;
                    }

                    final surfaceY = slope.surfaceYForBody(body.x, body.width);

                    if (surfaceY != null)
                    {
                        body.y = surfaceY - body.height - skin;
                        body.touching |= DOWN;
                    }
                    else
                    {
                        body.y += hit.normalY * (hit.depth + skin);
                    }

                    moved = true;
                    continue;
                }

                if (hit.feature == 0 && hit.normalY > move_epsilon)
                {
                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, 1 ))
                    {
                        continue;
                    }

                    final ceilingY = slope.ceilingYForBody(body.x, body.width);

                    if (ceilingY != null)
                    {
                        body.y = ceilingY + skin;
                        body.touching |= UP;
                    }
                    else
                    {
                        body.y += hit.normalY * (hit.depth + skin);
                    }

                    moved = true;
                    continue;
                }

                if (Math.abs(hit.normalX) >= Math.abs(hit.normalY))
                {
                    final normalX = hit.normalX < 0 ? -1 : 1;

                    if (!canCollide(body.allowCollisions, slope.allowCollisions, normalX, 0))
                    {
                        continue;
                    }

                    body.x += hit.normalX * (hit.depth + skin);

                    if (hit.normalX < 0)
                    {
                        body.touching |= RIGHT;
                    }
                    else
                    {
                        body.touching |= LEFT;
                    }
                }
                else
                {
                    final normalY = hit.normalY < 0 ? -1 : 1;

                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, normalY))
                    {
                        continue;
                    }

                    body.y += hit.normalY * (hit.depth + skin);

                    if (hit.normalY < 0)
                    {
                        body.touching |= DOWN;
                    }
                    else
                    {
                        body.touching |= UP;
                    }
                }

                moved = true;
            }

            if (!moved)
            {
                break;
            }
        }
    }

    static function depenetrateRectangles(body:FlxObject, solids:FlxGroup)
    {
        for (_ in 0...4)
        {
            var penetration:PenetrationHit =
            {
                depth: Math.POSITIVE_INFINITY,
                normalX: 0,
                normalY: 0
            };

            for (member in solids.members)
            {
                if (member == null || !member.exists || !member.alive || member == body)
                {
                    continue;
                }

                if (Std.isOfType(member, SlopeSolid))
                {
                    continue;
                }

                if (!Std.isOfType(member, FlxObject))
                {
                    continue;
                }

                final solid:FlxObject = cast member;

                if (!solid.active || !solid.solid || solid.width <= 0 || solid.height <= 0)
                {
                    continue;
                }

                if (!isFullySolid(solid.allowCollisions))
                {
                    continue;
                }

                considerRectanglePenetration(body, solid, penetration);
            }

            if (penetration.depth == Math.POSITIVE_INFINITY)
            {
                break;
            }

            final separation = penetration.depth + skin;

            if (penetration.normalX < 0)
            {
                body.x -= separation;
                body.touching |= RIGHT;
            }
            else if (penetration.normalX > 0)
            {
                body.x += separation;
                body.touching |= LEFT;
            }

            if (penetration.normalY < 0)
            {
                body.y -= separation;
                body.touching |= DOWN;
            }
            else if (penetration.normalY > 0)
            {
                body.y += separation;
                body.touching |= UP;
            }
        }
    }

    static function considerRectanglePenetration(body:FlxObject, solid:FlxObject, out:PenetrationHit)
    {
        final solidRight = solid.x + solid.width;
        final solidBottom = solid.y + solid.height;

        final bodyRight = body.x + body.width;
        final bodyBottom = body.y + body.height;

        if (bodyRight <= solid.x || body.x >= solidRight || bodyBottom <= solid.y || body.y >= solidBottom)
        {
            return;
        }

        final pushLeft = bodyRight - solid.x;

        if (pushLeft > 0 && canCollide(body.allowCollisions, solid.allowCollisions, -1, 0) && pushLeft < out.depth)
        {
            out.depth = pushLeft;
            out.normalX = -1;
            out.normalY = 0;
        }

        final pushRight = solidRight - body.x;

        if (pushRight > 0 && canCollide(body.allowCollisions, solid.allowCollisions, 1, 0) && pushRight < out.depth)
        {
            out.depth = pushRight;
            out.normalX = 1;
            out.normalY = 0;
        }

        final pushUp = bodyBottom - solid.y;

        if (pushUp > 0 && canCollide(body.allowCollisions, solid.allowCollisions, 0, -1) && pushUp < out.depth)
        {
            out.depth = pushUp;
            out.normalX = 0;
            out.normalY = -1;
        }

        final pushDown = solidBottom - body.y;

        if (pushDown > 0 && canCollide(body.allowCollisions, solid.allowCollisions, 0, 1) && pushDown < out.depth)
        {
            out.depth = pushDown;
            out.normalX = 0;
            out.normalY = 1;
        }
    }

    static inline function isFullySolid(flags:FlxDirectionFlags):Bool
    {
        return flags.has(LEFT) && flags.has(RIGHT) && flags.has(UP) && flags.has(DOWN);
    }

    static function canCollide(bodyFlags:FlxDirectionFlags, solidFlags:FlxDirectionFlags, normalX:Int, normalY:Int):Bool
    {
        if (normalX < 0)
        {
            return bodyFlags.has(RIGHT) && solidFlags.has(LEFT);
        }

        if (normalX > 0)
        {
            return bodyFlags.has(LEFT) && solidFlags.has(RIGHT);
        }

        if (normalY < 0)
        {
            return bodyFlags.has(DOWN) && solidFlags.has(UP);
        }

        if (normalY > 0)
        {
            return bodyFlags.has(UP) && solidFlags.has(DOWN);
        }

        return false;
    }
}
