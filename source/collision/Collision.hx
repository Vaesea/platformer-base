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

    public static function resolve(body:FlxObject, solids:FlxGroup, physics:Physics, elapsed:Float, ?onCollision:FlxObject->FlxObject->Void)
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
        }

        final totalDX = physics.velocityX * elapsed;
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

            final stepDX = physics.velocityX * stepTime;
            final stepDY = physics.velocityY * stepTime;

            final supportedBeforeHorizontal = physics.grounded || (wasGrounded && physics.velocityY >= -move_epsilon);

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

    static function resolveHorizontalRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

            if (movingRight && oldRight <= solid.x + time_epsilon && newRight > solid.x - skin && canCollide(body.allowCollisions, solid.allowCollisions, -1, 0))
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
            else if (movingLeft && oldX >= solidRight - time_epsilon && body.x < solidRight + skin && canCollide(body.allowCollisions, solid.allowCollisions, 1, 0))
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

    static function resolveVerticalRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, moveY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

    static function resolveVerticalFloorRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

        if (onCollision != null && bestOther != null)
        {
            onCollision(body, bestOther);
        }

        return true;
    }

    static function resolveVerticalCeilingRectangles(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

    static function resolveSlopeContacts(body:FlxObject, solids:FlxGroup, oldX:Float, oldY:Float, endX:Float, endY:Float, moveX:Float, moveY:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

                final absNormalX = Math.abs(hit.normalX);
                final absNormalY = Math.abs(hit.normalY);

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
                    }
                    else
                    {
                        body.touching |= UP;

                        if (physics.velocityY < 0)
                        {
                            physics.velocityY = 0;
                        }

                        physics.grounded = false;
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

    static function followGroundAfterHorizontalMove(body:FlxObject, solids:FlxGroup, referenceX:Float, referenceY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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
            final referenceDistance = referenceSurface == null ? Math.abs(referenceBottom - nextSurface) : Math.abs(referenceBottom - referenceSurface);

            if (referenceDistance > supportEpsilon)
            {
                continue;
            }

            final surfaceChange = Math.abs(nextSurface - referenceBottom);
            final maximumSurfaceChange = Math.abs(moveX) * slope.gradient + supportEpsilon;

            if (surfaceChange > maximumSurfaceChange)
            {
                continue;
            }

            final distance = Math.abs(nextSurface - referenceBottom);

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

        if (bestFlat != null  && (bestSlope == null || bestFlatDistance <= bestSlopeDistance))
        {
            body.y = bestFlatY - body.height - skin;
            body.touching |= DOWN;
            physics.velocityY = 0;
            physics.grounded = true;

            if (onCollision != null)
            {
                onCollision(body, bestFlat);
            }

            return true;
        }

        body.y = bestSurface - body.height - skin;
        body.touching |= DOWN;
        physics.velocityY = 0;
        physics.grounded = true;

        if (onCollision != null)
        {
            onCollision(body, bestSlope);
        }

        return true;
    }

    static function maintainGround(body:FlxObject, solids:FlxGroup, referenceX:Float, referenceY:Float, moveX:Float, physics:Physics, ?onCollision:FlxObject->FlxObject->Void)
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

            if (Math.abs(body.y + body.height - solid.y) <= slope_ground_tolerance)
            {
                body.y = solid.y - body.height - skin;
                body.touching |= DOWN;
                physics.velocityY = 0;
                physics.grounded = true;

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
                    if (!canCollide(body.allowCollisions, slope.allowCollisions, 0, 1))
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
            var penetration:PenetrationHit = {depth: Math.POSITIVE_INFINITY, normalX: 0, normalY: 0};

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

    static function canCollide(bodyFlags:FlxDirectionFlags, solidFlags:FlxDirectionFlags, normalX:Int, normalY:Int)
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
