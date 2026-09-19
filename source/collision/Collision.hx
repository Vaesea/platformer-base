package collision;

// Collision - Simple (not really) class that does some cool collision stuff.
// Copyright (C) 2026 AnatolyStev
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import flixel.tile.FlxTile;
import flixel.tile.FlxTilemap;
import flixel.util.FlxDirectionFlags;
import flixel.group.FlxGroup;
import flixel.FlxObject;

typedef SweepHit = 
{
    var time:Float;
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

    public static inline var max_iterations:Int = 4;

    public static inline var max_depenetration_iterations:Int = 8;

    public static inline var time_epsilon:Float = 0.000001;
    public static inline var move_epsilon:Float = 0.000001;

    /**
     * Resolves one moving FlxObject against all solid objects in the group.
     *
     * "onCollision" is called after the body's flags have been resolved, so
     * it's possible to safely use isTouching().
    */
    public static function resolve(body:FlxObject, solids:FlxGroup, ?onCollision:FlxObject->FlxObject->Void)
    {
        if (body == null || solids == null)
        {
            return;
        }

        if (!body.exists || !body.alive || !body.active || !body.moves || !body.solid || body.immovable)
        {
            return;
        }

        final targetX = body.x;
        final targetY = body.y;

        body.x = body.last.x;
        body.y = body.last.y;

        depenetrate(body, solids);

        var moveX = targetX - body.x;
        var moveY = targetY - body.y;

        for (_ in 0...max_iterations)
        {
            if (Math.abs(moveX) < move_epsilon && Math.abs(moveY) < move_epsilon)
            {
                break;
            }

            final hit = findEarliestHit(body, solids, moveX, moveY);
            
            if (hit == null)
            {
                body.x += moveX;
                body.y += moveY;
                break;
            }

            final time = hit.time;
            
            body.x += moveX * time;
            body.y += moveY * time;

            if (hit.normalX < 0)
            {
                body.x -= skin;
                body.touching |= RIGHT;
            }
            else if (hit.normalX > 0)
            {
                body.x += skin;
                body.touching |= LEFT;
            }

            if (hit.normalY < 0)
            {
                body.y -= skin;
                body.touching |= DOWN;
            }
            else if (hit.normalY > 0)
            {
                body.y += skin;
                body.touching |= UP;
            }

            if (hit.normalX != 0 && body.velocity.x * hit.normalX < 0)
            {
                body.velocity.x = 0;
            }

            if (hit.normalY != 0 && body.velocity.y * hit.normalY < 0)
            {
                body.velocity.y = 0;
            }

            if (onCollision != null)
            {
                onCollision(body, hit.other);
            }

            final remaining = 1.0 - time;

            moveX *= remaining;
            moveY *= remaining;

            if (hit.normalX != 0)
            {
                moveX = 0;
            }

            if (hit.normalY != 0)
            {
                moveY = 0;
            }

            if (remaining <= move_epsilon)
            {
                break;
            }
        }

        depenetrate(body, solids);
    }

    /**
     * Resolves every member (has to be alive) in a typed group against the solids.
    */
    public static function resolveGroup<T:FlxObject>(group:FlxTypedGroup<T>, solids:FlxGroup)
    {
        if (group == null || solids == null)
        {
            return;
        }

        for (member in group.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            resolve(member, solids);
        }
    }

    static function findEarliestHit(body:FlxObject, solids:FlxGroup, moveX:Float, moveY:Float):Null<SweepHit>
    {
        var bestTime = 1.0;
        var bestOther:FlxObject = null;
        var bestNormalX = 0;
        var bestNormalY = 0;

        final startX = body.x;
        final startY = body.y;
        final bodyWidth = body.width;
        final bodyHeight = body.height;

        final endX = startX + moveX;
        final endY = startY + moveY;

        final sweepLeft = moveX < 0 ? endX : startX;
        final sweepRight = moveX > 0 ? endX + bodyWidth : startX + bodyWidth;
        final sweepTop = moveY < 0 ? endY : startY;
        final sweepBottom = moveY > 0 ? endY + bodyHeight : startY + bodyHeight;

        final scratch:SweepHit = {time: 0, normalX: 0, normalY: 0, other: body};

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            if (Std.isOfType(member, FlxTilemap))
            {
                final tilemap:FlxTilemap = cast member;

                if (findEarliestTilemapHit(body, tilemap, startX, startY, bodyWidth, bodyHeight, moveX, moveY, sweepLeft, sweepRight, sweepTop, sweepBottom, bestTime, scratch))
                {
                    if (scratch.time <= bestTime)
                    {
                        bestTime = scratch.time;
                        bestOther = scratch.other;
                        bestNormalX = scratch.normalX;
                        bestNormalY = scratch.normalY;
                    }
                }
                
                continue;
            }

            if (!Std.isOfType(member, FlxObject))
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid == body || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            final solidRight = solid.x + solid.width;
            final solidBottom = solid.y + solid.height;

            if (sweepRight < solid.x || sweepLeft > solidRight || sweepBottom < solid.y || sweepTop > solidBottom)
            {
                continue;
            }

            if (!sweepFast(body.allowCollisions, startX, startY, bodyWidth, bodyHeight, solid.x, solid.y, solidRight, solidBottom, solid.allowCollisions, moveX, moveY, bestTime, solid, scratch))
            {
                continue;
            }

            if (scratch.time <= bestTime)
            {
                bestTime = scratch.time;
                bestOther = scratch.other;
                bestNormalX = scratch.normalX;
                bestNormalY = scratch.normalY;
            }
        }

        if (bestOther == null)
        {
            return null;
        }

        return {time: bestTime, normalX: bestNormalX, normalY: bestNormalY, other: bestOther};
    }

    static function findEarliestTilemapHit(body:FlxObject, tilemap:FlxTilemap, startX:Float, startY:Float, bodyWidth:Float, bodyHeight:Float, moveX:Float, moveY:Float, sweepLeft:Float, sweepRight:Float, sweepTop:Float, sweepBottom:Float, bestTime:Float, out:SweepHit):Bool
    {
        if (!tilemap.exists || !tilemap.alive || !tilemap.active || tilemap.widthInTiles <= 0 || tilemap.heightInTiles <= 0 || tilemap.scaledTileWidth <= 0 || tilemap.scaledTileHeight <= 0)
        {
            return false;
        }

        final tileWidth = tilemap.scaledTileWidth;
        final tileHeight = tilemap.scaledTileHeight;

        final invTileWidth = 1.0 / tileWidth;
        final invTileHeight = 1.0 / tileHeight;

        var minTileX:Int = Std.int(Math.floor((sweepLeft - tilemap.x) * invTileWidth));
        var maxTileX:Int = Std.int(Math.floor((sweepRight - tilemap.x) * invTileWidth));
        var minTileY:Int = Std.int(Math.floor((sweepTop - tilemap.y) * invTileHeight));
        var maxTileY:Int = Std.int(Math.floor((sweepBottom - tilemap.y) * invTileHeight));

        if (minTileX < 0)
        {
            minTileX = 0;
        }

        if (minTileY < 0)
        {
            minTileY = 0;
        }

        if (maxTileX >= tilemap.widthInTiles)
        {
            maxTileX = tilemap.widthInTiles - 1;
        }

        if (maxTileY >= tilemap.heightInTiles)
        {
            maxTileY = tilemap.heightInTiles - 1;
        }

        if (minTileX > maxTileX || minTileY > maxTileY)
        {
            return false;
        }

        var bestHitTime = bestTime;
        var bestTile:FlxTile = null;
        var bestMapIndex = -1;
        var bestNormalX = 0;
        var bestNormalY = 0;

        final mapWidth = tilemap.widthInTiles;

        var tileWorldY = tilemap.y + minTileY * tileHeight;

        for (tileY in minTileY...maxTileY + 1)
        {
            var tileWorldX = tilemap.x + minTileX * tileWidth;
            var mapIndex = tileY * mapWidth + minTileX;

            for (_ in minTileX...maxTileX + 1)
            {
                final tile = tilemap.getTileData(mapIndex);

                if (tile != null && tile.allowCollisions != NONE)
                {
                    final tileRight = tileWorldX + tileWidth;
                    final tileBottom = tileWorldY + tileHeight;

                    if (sweepFast(body.allowCollisions, startX, startY, bodyWidth, bodyHeight, tileWorldX, tileWorldY, tileRight, tileBottom, tile.allowCollisions, moveX, moveY, bestHitTime, tile, out))
                    {
                        if (out.time <= bestHitTime)
                        {
                            bestHitTime = out.time;
                            bestTile = tile;
                            bestMapIndex = mapIndex;
                            bestNormalX = out.normalX;
                            bestNormalY = out.normalY;
                        }
                    }
                }

                mapIndex += 1;
                tileWorldX += tileWidth;
            }

            tileWorldY += tileHeight;
        }

        if (bestTile == null)
        {
            return false;
        }

        bestTile.orientByIndex(bestMapIndex);

        out.time = bestHitTime;
        out.normalX = bestNormalX;
        out.normalY = bestNormalY;
        out.other = bestTile;

        return true;
    }

    static function sweepFast(bodyFlags:FlxDirectionFlags, startX:Float, startY:Float, bodyWidth:Float, bodyHeight:Float, solidX:Float, solidY:Float, solidRight:Float, solidBottom:Float, solidFlags:FlxDirectionFlags, moveX:Float, moveY:Float, bestTime:Float, other:FlxObject, out:SweepHit):Bool
    {
        final bodyRight = startX + bodyWidth;
        final bodyBottom = startY + bodyHeight;

        var xEntry:Float;
        var xExit:Float;

        if (moveX > 0)
        {
            xEntry = (solidX - bodyRight) / moveX;
            xExit = (solidRight - startX) / moveX;
        }
        else if (moveX < 0)
        {
            xEntry = (solidRight - startX) / moveX;
            xExit = (solidX - bodyRight) / moveX;
        }
        else
        {
            if (bodyRight <= solidX || startX >= solidRight)
            {
                return false;
            }

            xEntry = Math.NEGATIVE_INFINITY;
            xExit = Math.POSITIVE_INFINITY;
        }

        if (xEntry > bestTime)
        {
            return false;
        }

        var yEntry:Float;
        var yExit:Float;

        if (moveY > 0)
        {
            yEntry = (solidY - bodyBottom) / moveY;
            yExit = (solidBottom - startY) / moveY;
        }
        else if (moveY < 0)
        {
            yEntry = (solidBottom - startY) / moveY;
            yExit = (solidY - bodyBottom) / moveY;
        }
        else
        {
            if (bodyBottom <= solidY || startY >= solidBottom)
            {
                return false;
            }

            yEntry = Math.NEGATIVE_INFINITY;
            yExit = Math.POSITIVE_INFINITY;
        }

        final entryTime = xEntry > yEntry ? xEntry : yEntry;
        final exitTime = xExit < yExit ? xExit : yExit;

        if (entryTime > exitTime || entryTime < 0 || entryTime > 1 || entryTime > bestTime)
        {
            return false;
        }

        var normalX = 0;
        var normalY = 0;

        if (Math.abs(xEntry - entryTime) <= time_epsilon)
        {
            normalX = moveX > 0 ? -1 : 1;
        }

        if (Math.abs(yEntry - entryTime) <= time_epsilon)
        {
            normalY = moveY > 0 ? -1 : 1;
        }

        if (normalX < 0 && (!bodyFlags.has(RIGHT) || !solidFlags.has(LEFT)))
        {
            normalX = 0;
        }
        else if (normalX > 0 && (!bodyFlags.has(LEFT) || !solidFlags.has(RIGHT)))
        {
            normalX = 0;
        }

        if (normalY < 0 && (!bodyFlags.has(DOWN) || !solidFlags.has(UP)))
        {
            normalY = 0;
        }
        else if (normalY > 0 && (!bodyFlags.has(UP) || !solidFlags.has(DOWN)))
        {
            normalY = 0;
        }

        if (normalX == 0 && normalY == 0)
        {
            return false;
        }

        out.time = entryTime;
        out.normalX = normalX;
        out.normalY = normalY;
        out.other = other;

        return true;
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

    static function depenetrate(body:FlxObject, solids:FlxGroup)
    {
        for (_ in 0...max_depenetration_iterations)
        {
            final penetration:PenetrationHit = {depth: Math.POSITIVE_INFINITY, normalX: 0, normalY: 0};

            for (member in solids.members)
            {
                if (member == null || !member.exists || !member.alive)
                {
                    continue;
                }

                if (Std.isOfType(member, FlxTilemap))
                {
                    considerTilemapPenetration(body, cast member, penetration);
                    continue;
                }

                if (!Std.isOfType(member, FlxObject))
                {
                    continue;
                }

                final solid:FlxObject = cast member;

                if (!solid.active || !solid.solid || solid == body || solid.width <= 0 || solid.height <= 0)
                {
                    continue;
                }

                considerPenetration(body, solid.x, solid.y, solid.width, solid.height, solid.allowCollisions, penetration);
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

                if (body.velocity.x > 0)
                {
                    body.velocity.x = 0;
                }
            }
            else if (penetration.normalX > 0)
            {
                body.x += separation;
                body.touching |= LEFT;

                if (body.velocity.x < 0)
                {
                    body.velocity.x = 0;
                }
            }

            if (penetration.normalY < 0)
            {
                body.y -= separation;
                body.touching |= DOWN;

                if (body.velocity.y > 0)
                {
                    body.velocity.y = 0;
                }
            }
            else if (penetration.normalY > 0)
            {
                body.y += separation;
                body.touching |= UP;

                if (body.velocity.y < 0)
                {
                    body.velocity.y = 0;
                }
            }
        }
    }

    static function considerPenetration(body:FlxObject, solidX:Float, solidY:Float, solidWidth:Float, solidHeight:Float, solidFlags:FlxDirectionFlags, out:PenetrationHit)
    {
        final solidRight = solidX + solidWidth;
        final solidBottom = solidY + solidHeight;
        final bodyRight = body.x + body.width;
        final bodyBottom = body.y + body.height;
        
        final overlapRight = bodyRight < solidRight ? bodyRight : solidRight;
        final overlapLeft = body.x > solidX ? body.x : solidX;
        
        final penetrationX = overlapRight - overlapLeft;

        if (penetrationX <= 0)
        {
            return;
        }

        final overlapBottom = bodyBottom < solidBottom ? bodyBottom : solidBottom;
        final overlapTop = body.y > solidY ? body.y : solidY;

        final penetrationY = overlapBottom - overlapTop;

        if (penetrationY <= 0)
        {
            return;
        }

        final bodyCenterX = body.x + body.width * 0.5;
        final bodyCenterY = body.y + body.height * 0.5;
        final solidCenterX = solidX + solidWidth * 0.5;
        final solidCenterY = solidY + solidHeight * 0.5;

        if (penetrationX < penetrationY)
        {
            final normalX = bodyCenterX < solidCenterX ? -1 : 1;

            if (!canCollide(body.allowCollisions, solidFlags, normalX, 0))
            {
                return;
            }

            if (penetrationX < out.depth)
            {
                out.depth = penetrationX;
                out.normalX = normalX;
                out.normalY = 0;
            }
        }
        else
        {
            final normalY = bodyCenterY < solidCenterY ? -1 : 1;

            if (!canCollide(body.allowCollisions, solidFlags, 0, normalY))
            {
                return;
            }

            if (penetrationY < out.depth)
            {
                out.depth = penetrationY;
                out.normalX = 0;
                out.normalY = normalY;
            }
        }
    }

    static function considerTilemapPenetration(body:FlxObject, tilemap:FlxTilemap, out:PenetrationHit)
    {
        if (!tilemap.exists || !tilemap.alive || !tilemap.active || tilemap.widthInTiles <= 0 || tilemap.heightInTiles <= 0 || tilemap.scaledTileWidth <= 0 || tilemap.scaledTileHeight <= 0)
        {
            return;
        }

        var tileWidth:Float = tilemap.scaledTileWidth;
        var tileHeight:Float = tilemap.scaledTileHeight;

        final invTileWidth = 1.0 / tileWidth;
        final invTileHeight = 1.0 / tileHeight;

        final bodyRight = body.x + body.width;
        final bodyBottom = body.y + body.height;

        var minTileX:Int = Std.int(Math.floor((body.x - tilemap.x) * invTileWidth));
        var maxTileX:Int = Std.int(Math.floor((bodyRight - tilemap.x) * invTileWidth));
        var minTileY:Int = Std.int(Math.floor((bodyRight - tilemap.y) * invTileWidth));
        var maxTileY:Int = Std.int(Math.floor((bodyBottom - tilemap.y) * invTileHeight));

        if (minTileX < 0)
        {
            minTileX = 0;
        }

        if (minTileY < 0)
        {
            minTileY = 0;
        }

        if (maxTileX >= tilemap.widthInTiles)
        {
            maxTileX = tilemap.widthInTiles - 1;
        }

        if (maxTileY >= tilemap.heightInTiles)
        {
            maxTileY = tilemap.heightInTiles - 1;
        }

        if (minTileX > maxTileX || minTileY > maxTileY)
        {
            return;
        }

        final mapWidth = tilemap.widthInTiles;

        var tileWorldY:Float = tilemap.y + minTileY * tileHeight;

        for (tileY in minTileY...maxTileY + 1)
        {
            var tileWorldX = tilemap.x + minTileX * tileWidth;
            var mapIndex = tileY * mapWidth + minTileX;

            for (_ in minTileX...maxTileX + 1)
            {
                final tile = tilemap.getTileData(mapIndex);

                if (tile != null && tile.allowCollisions != NONE)
                {
                    considerPenetration(body, tileWorldX, tileWorldY, tileWidth, tileHeight, tile.allowCollisions, out);
                }

                mapIndex += 1;
                tileWorldX += tileWidth;
            }

            tileWorldY += tileHeight;
        }
    }
}