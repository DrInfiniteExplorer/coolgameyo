module random.modscaleoffset;

import cgy.util.util;
import cgy.util.rect;
import random.valuesource;

//Scale and offset. For example, to use a valuemap(width, height) as source for world height,
// we want to scale with width/(WorldSize*sectorsize.x) and offset with (width/2, height/2) to make sampling of
// 0, SectorSize.y*WorldSize/2 sample the value at width/2, height
final class ModScaleOffset : ValueSource {
    ValueSource source;
    vec3d scale;
    vec3d offset;
    this(ValueSource s, vec3d _scale, vec3d _offset) {
        source = s;
        scale = _scale;
        offset = _offset;
    }

    ~this(){
    }

    override double getValue3(vec3d pos) {
        auto v = source.getValue3(pos*scale + offset);
        return v;
    }

    override double getValue2(vec2d pos) {
        auto v = source.getValue2(pos * scale.v2 + offset.v2);
        return v;
    }
    override double getValue(double x) {
        auto v = source.getValue(x*scale.x + offset.x);
        return v;
    }
}

//A more sane version of the cryptic stuff above.
// Maps for example (100, 100, 200, 200) to (10, 10). Derp.
auto MapRectToSize(ValueSource s, Rectd sourceRect, vec2d targetSize) {
    auto a = (sourceRect.size / targetSize);
    auto b = sourceRect.start;
    return new ModScaleOffset(s, a.v3, b.v3);
}

/*
// A more sane version of the cryptic one above.
final class MapRectToSize : ValueSource {
    ValueSource source;
    Rectd sourceRect;
    vec2d targetRange;
    this(ValueSource s, Rectd _sourceRect, vec2d _targetRange) {
        source = s;
        sourceRect = _sourceRect;
        targetRange = _targetRange;
    }

    ~this(){
    }

    override double getValue3(vec3d pos) {
        enforce(0, "MapRectToSize is not implemented for 3-D querying.");
        return double.init;
    }

    override double getValue2(vec2d pos) {
        //X, Y in range 0->1
        auto X = x / scale.x;
        auto Y = y / scale.y;
        //X, Y -> range 0->sourceSize
        X *= sourceRect.size.x;
        Y *= sourceRect.size.y;
        //X, Y -> range start->end
        X += sourceRect.start.x;
        Y += sourceRect.start.y;
        auto v = source.getValue(X, Y);

        return v;
    }
    override double getValue(double x) {
        enforce(0, "MapRectToSize is not implemented for 1-D querying.");
    }
}
*/
