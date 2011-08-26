

module util.intersect;

import std.algorithm;

import stolen.aabbox3d;
import util.util;
import util.rangefromto;

// Penetrating intersection
bool intersectsExclusive(aabbox3d!double a, aabbox3d!double b){
    auto minx = max(a.MinEdge.X, b.MinEdge.X);
    auto miny = max(a.MinEdge.Y, b.MinEdge.Y);
    auto minz = max(a.MinEdge.Z, b.MinEdge.Z);
    auto maxx = min(a.MaxEdge.X, b.MaxEdge.X);
    auto maxy = min(a.MaxEdge.Y, b.MaxEdge.Y);
    auto maxz = min(a.MaxEdge.Z, b.MaxEdge.Z);

    return minx < maxx && miny<maxy && minz<maxz;
}
//And this one intersects for all intersecting ones, and ones which are right next to each other as well.
bool intersectsInclusive(aabbox3d!double a, aabbox3d!double b){
    auto minx = max(a.MinEdge.X, b.MinEdge.X);
    auto miny = max(a.MinEdge.Y, b.MinEdge.Y);
    auto minz = max(a.MinEdge.Z, b.MinEdge.Z);
    auto maxx = min(a.MaxEdge.X, b.MaxEdge.X);
    auto maxy = min(a.MaxEdge.Y, b.MaxEdge.Y);
    auto maxz = min(a.MaxEdge.Z, b.MaxEdge.Z);

    return minx <= maxx && miny <= maxy && minz <= maxz;
}


unittest{
    alias aabbox3d!double box;
    auto a = box(-1, -1, -1, 1, 1, 1);
    auto b = box(-2, -2, -2, 2, 2, 2);
    assert(intersectsExclusive(b, a) == true, "Intersectswithbox doesnt seem to account for wholly swallowed boxes");
    assert(intersectsExclusive(b, a) == true, "Intersectswithbox doesnt seem to account for wholly bigger boxes");
    assert(intersectsExclusive(a, a) == true, "Intersection when exactly the same wvaluated to false");

    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0, 0, 0, 2, 2, 2)) == true, "This shouldve been true");
    assert(intersectsExclusive(box(0, 0, 0, 2, 2, 2), box(0, 0, 0, 1, 1, 1)) == true, "This shouldve been true");

    //This makes the ones below this for redundant, i think and hope and such
    auto c = box(0, 0, 0, 1, 1, 1);
    foreach(p ; RangeFromTo(-1, 2, -1, 2, -1, 2)){
        auto d = c;
        d.MinEdge += util.util.convert!double(p);
        d.MaxEdge += util.util.convert!double(p);
        bool bbb = p == vec3i(0,0,0);
        assert(intersectsExclusive(c, d) == bbb, "This should've been " ~ bbb);
        assert(intersectsExclusive(d, c) == bbb, "This should've been " ~ bbb);
    }

    //We dont want boxes that are lining up to intersect with each other...
    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0-1, 0, 0, 1-1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x-.");
    assert(intersectsExclusive(box(0-1, 0, 0, 1-1, 1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x-(2).");
    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0+1, 0, 0, 1+1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x+.");
    assert(intersectsExclusive(box(0+1, 0, 0, 1+1, 1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in x+(2).");

    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0, 0-1, 0, 1, 1-1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y-.");
    assert(intersectsExclusive(box(0, 0-1, 0, 1, 1-1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y-(2).");
    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0, 0+1, 0, 1, 1+1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y+.");
    assert(intersectsExclusive(box(0, 0+1, 0, 1, 1+1, 1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in y+(2).");

    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0, 0, 0-1, 1, 1, 1-1)) == false, "Seems that boxes next to each other intersect. Sadface in z-.");
    assert(intersectsExclusive(box(0, 0, 0-1, 1, 1, 1-1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in z-(2).");
    assert(intersectsExclusive(box(0, 0, 0, 1, 1, 1), box(0, 0, 0+1, 1, 1, 1+1)) == false, "Seems that boxes next to each other intersect. Sadface in z+.");
    assert(intersectsExclusive(box(0, 0, 0+1, 1, 1, 1+1), box(0, 0, 0, 1, 1, 1)) == false, "Seems that boxes next to each other intersect. Sadface in z+(2).");

}
