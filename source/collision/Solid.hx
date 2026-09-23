package collision;

import misc.VPBSprite;

class Solid extends VPBSprite
{
    public function new(x:Float, y:Float, width:Float, height:Float)
    {
        super(x, y);
        
        makeSolidGraphic(width, height);
    }
}