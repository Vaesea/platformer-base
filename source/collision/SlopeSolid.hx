package collision;

import flixel.FlxObject;

typedef SlopeCollisionHit =
{
    var depth:Float;
    var normalX:Float;
    var normalY:Float;
    var feature:Int;
}

typedef SlopeAxisResult =
{
    var valid:Bool;
    var depth:Float;
    var normalX:Float;
    var normalY:Float;
}

class SlopeSolid extends FlxObject
{
    public final risesRight:Bool;

    public final gradient:Float;
    public final surfaceSlope:Float;

    public function new(x:Float, y:Float, width:Float, height:Float, risesRight:Bool)
    {
        super(x, y, width, height);

        this.risesRight = risesRight;
        gradient = width > 0 ? height / width : 0;
        surfaceSlope = risesRight ? -gradient : gradient;

        solid = true;
        moves = false;
        immovable = true;
    }

    public inline function lineYAt(worldX:Float)
    {
        final localX = worldX - x;

        if (risesRight)
        {
            return y + height - localX * gradient;
        }

        return y + localX * gradient;
    }

    public inline function surfaceYAt(worldX:Float)
    {
        var localX = worldX - x;

        if (localX < 0)
        {
            localX = 0;
        }
        else if (localX > width)
        {
            localX = width;
        }

        return lineYAt(x + localX);
    }

    public inline function surfaceYForBody(bodyX:Float, bodyWidth:Float):Null<Float>
    {
        final overlapLeft = Math.max(bodyX, x);
        final overlapRight = Math.min(bodyX + bodyWidth, x + width);

        if (overlapLeft >= overlapRight)
        {
            return null;
        }

        final sampleX = risesRight ? overlapRight : overlapLeft;

        return lineYAt(sampleX);
    }

    public inline function ceilingYForBody(bodyX:Float, bodyWidth:Float):Null<Float>
    {
        final overlapLeft = Math.max(bodyX, x);
        final overlapRight = Math.min(bodyX + bodyWidth, x + width);

        if (overlapLeft >= overlapRight)
        {
            return null;
        }

        final sampleX = risesRight ? overlapLeft : overlapRight;

        return lineYAt(sampleX);
    }

    public function collideAABB(bodyX:Float, bodyY:Float, bodyWidth:Float, bodyHeight:Float):Null<SlopeCollisionHit>
    {
        if (bodyWidth <= 0 || bodyHeight <= 0 || width <= 0 || height <= 0)
        {
            return null;
        }

        final left = bodyX;
        final right = bodyX + bodyWidth;
        final top = bodyY;
        final bottom = bodyY + bodyHeight;

        if (right <= x || left >= x + width || bottom <= y || top >= y + height)
        {
            return null;
        }

        final vx0 = vertexX(0);
        final vy0 = vertexY(0);
        final vx1 = vertexX(1);
        final vy1 = vertexY(1);
        final vx2 = vertexX(2);
        final vy2 = vertexY(2);

        final rectCenterX = bodyX + bodyWidth * 0.5;
        final rectCenterY = bodyY + bodyHeight * 0.5;

        final triangleCenterX = (vx0 + vx1 + vx2) / 3.0;
        final triangleCenterY = (vy0 + vy1 + vy2) / 3.0;

        var bestDepth = Math.POSITIVE_INFINITY;
        var bestNormalX = 0.0;
        var bestNormalY = 0.0;
        var bestFeature = -1;

        var axis = testAxis(1.0, 0.0, -1, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);

        if (!axis.valid)
        {
            return null;
        }

        bestDepth = axis.depth;
        bestNormalX = axis.normalX;
        bestNormalY = axis.normalY;
        bestFeature = -1;

        axis = testAxis(0.0, 1.0, -1, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);

        if (!axis.valid)
        {
            return null;
        }

        if (shouldUseAxis(axis.depth, -1, bestDepth, bestFeature))
        {
            bestDepth = axis.depth;
            bestNormalX = axis.normalX;
            bestNormalY = axis.normalY;
            bestFeature = -1;
        }

        axis = edgeAxis(vx0, vy0, vx1, vy1, 0, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);

        if (!axis.valid)
        {
            return null;
        }

        if (shouldUseAxis(axis.depth, 0, bestDepth, bestFeature))
        {
            bestDepth = axis.depth;
            bestNormalX = axis.normalX;
            bestNormalY = axis.normalY;
            bestFeature = 0;
        }

        axis = edgeAxis(vx1, vy1, vx2, vy2, 1, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);

        if (!axis.valid)
        {
            return null;
        }

        if (shouldUseAxis(axis.depth, 1, bestDepth, bestFeature))
        {
            bestDepth = axis.depth;
            bestNormalX = axis.normalX;
            bestNormalY = axis.normalY;
            bestFeature = 1;
        }

        axis = edgeAxis(vx2, vy2, vx0, vy0, 2, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);

        if (!axis.valid)
        {
            return null;
        }

        if (shouldUseAxis(axis.depth, 2, bestDepth, bestFeature))
        {
            bestDepth = axis.depth;
            bestNormalX = axis.normalX;
            bestNormalY = axis.normalY;
            bestFeature = 2;
        }

        return {depth: bestDepth, normalX: bestNormalX, normalY: bestNormalY, feature: bestFeature};
    }

    public inline function overlapsBody(bodyX:Float, bodyY:Float, bodyWidth:Float, bodyHeight:Float)
    {
        return collideAABB(bodyX, bodyY, bodyWidth, bodyHeight) != null;
    }

    public inline function overlapsHorizontally(bodyX:Float, bodyWidth:Float)
    {
        return bodyX < x + width && bodyX + bodyWidth > x;
    }

    public inline function getBodyY(bodyX:Float, bodyWidth:Float, bodyHeight:Float, skin:Float):Null<Float>
    {
        final surfaceY = surfaceYForBody(bodyX, bodyWidth);

        if (surfaceY == null)
        {
            return null;
        }

        return surfaceY - bodyHeight - skin;
    }

    public inline function snapBody(body:FlxObject, skin:Float)
    {
        final nextY = getBodyY(body.x, body.width, body.height, skin);

        if (nextY == null)
        {
            return false;
        }

        body.y = nextY;

        return true;
    }

    public inline function isOnSurface(bodyX:Float, bodyY:Float, bodyWidth:Float, bodyHeight:Float, tolerance:Float)
    {
        final surfaceY = surfaceYForBody(bodyX, bodyWidth);

        if (surfaceY == null)
        {
            return false;
        }

        return Math.abs(bodyY + bodyHeight - surfaceY) <= tolerance;
    }

    inline function vertexX(index:Int):Float
    {
        return switch (index)
        {
            case 0:
                risesRight ? x : x;
            case 1:
                x + width;
            default:
                risesRight ? x + width : x;
        };
    }

    inline function vertexY(index:Int):Float
    {
        return switch (index)
        {
            case 0:
                risesRight ? y + height : y;
            case 1:
                risesRight ? y : y + height;
            default:
                y + height;
        };
    }

    static function shouldUseAxis(depth:Float, feature:Int, bestDepth:Float, bestFeature:Int)
    {
        if (depth < bestDepth - 0.000001)
        {
            return true;
        }

        if (Math.abs(depth - bestDepth) <= 0.000001 && feature >= 0 && bestFeature < 0)
        {
            return true;
        }

        return false;
    }

    static function edgeAxis(x1:Float, y1:Float, x2:Float, y2:Float, feature:Int, bodyX:Float, bodyY:Float, bodyWidth:Float, bodyHeight:Float, vx0:Float, vy0:Float, vx1:Float, vy1:Float, vx2:Float, vy2:Float, rectCenterX:Float, rectCenterY:Float, triangleCenterX:Float, triangleCenterY:Float):SlopeAxisResult
    {
        final edgeX = x2 - x1;
        final edgeY = y2 - y1;
        final axisX = -edgeY;
        final axisY = edgeX;
        final axisLength = Math.sqrt(axisX * axisX + axisY * axisY);

        if (axisLength <= 0.000001)
        {
            return{valid: false, depth: 0, normalX: 0, normalY: 0};
        }

        return testAxis(axisX / axisLength, axisY / axisLength, feature, bodyX, bodyY, bodyWidth, bodyHeight, vx0, vy0, vx1, vy1, vx2, vy2, rectCenterX, rectCenterY, triangleCenterX, triangleCenterY);
    }

    static function testAxis(axisX:Float, axisY:Float, feature:Int, bodyX:Float, bodyY:Float, bodyWidth:Float, bodyHeight:Float, vx0:Float, vy0:Float, vx1:Float, vy1:Float, vx2:Float, vy2:Float, rectCenterX:Float, rectCenterY:Float, triangleCenterX:Float, triangleCenterY:Float):SlopeAxisResult
    {
        final p0 = vx0 * axisX + vy0 * axisY;
        final p1 = vx1 * axisX + vy1 * axisY;
        final p2 = vx2 * axisX + vy2 * axisY;

        final triangleMin = Math.min(p0, Math.min(p1, p2));
        final triangleMax = Math.max(p0, Math.max(p1, p2));

        final r0 = bodyX * axisX + bodyY * axisY;
        final r1 = (bodyX + bodyWidth) * axisX + bodyY * axisY;
        final r2 = (bodyX + bodyWidth) * axisX + (bodyY + bodyHeight) * axisY;
        final r3 = bodyX * axisX + (bodyY + bodyHeight) * axisY;

        final rectMin = Math.min(Math.min(r0, r1), Math.min(r2, r3));
        final rectMax = Math.max(Math.max(r0, r1), Math.max(r2, r3));

        final depth = Math.min(triangleMax, rectMax) - Math.max(triangleMin, rectMin);

        if (depth <= 0.000001)
        {
            return {valid: false, depth: 0, normalX: 0, normalY: 0};
        }

        var normalX = axisX;
        var normalY = axisY;

        final centerDeltaX = rectCenterX - triangleCenterX;
        final centerDeltaY = rectCenterY - triangleCenterY;

        if (centerDeltaX * normalX + centerDeltaY * normalY < 0)
        {
            normalX = -normalX;
            normalY = -normalY;
        }

        return {valid: true, depth: depth, normalX: normalX, normalY: normalY};
    }

    public inline function isEnteringFromLowSide(startX:Float, bodyWidth:Float, nextX:Float, tolerance:Float)
    {
        final startRight = startX + bodyWidth;
        final nextRight = nextX + bodyWidth;

        if (risesRight)
        {
            return startRight <= x + tolerance && nextRight > x + tolerance;
        }

        return startX >= x + width - tolerance && nextX < x + width - tolerance;
    }
}
