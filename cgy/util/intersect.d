

module util.intersect;

import std.algorithm;

import stolen.aabbox3d;
import util.util;
import util.rangefromto;

// Penetrating intersection
bool intersectsExclusive(aabbox3d!double a, aabbox3d!double b){
    auto minx = max(a.MinEdge.x, b.MinEdge.x);
    auto miny = max(a.MinEdge.y, b.MinEdge.y);
    auto minz = max(a.MinEdge.z, b.MinEdge.z);
    auto maxx = min(a.MaxEdge.x, b.MaxEdge.x);
    auto maxy = min(a.MaxEdge.y, b.MaxEdge.y);
    auto maxz = min(a.MaxEdge.z, b.MaxEdge.z);

    return minx < maxx && miny<maxy && minz<maxz;
}
//And this one intersects for all intersecting ones, and ones which are right next to each other as well.
bool intersectsInclusive(aabbox3d!double a, aabbox3d!double b){
    auto minx = max(a.MinEdge.x, b.MinEdge.x);
    auto miny = max(a.MinEdge.y, b.MinEdge.y);
    auto minz = max(a.MinEdge.z, b.MinEdge.z);
    auto maxx = min(a.MaxEdge.x, b.MaxEdge.x);
    auto maxy = min(a.MaxEdge.y, b.MaxEdge.y);
    auto maxz = min(a.MaxEdge.z, b.MaxEdge.z);

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
    foreach(p ; RangeFromTo (-1, 1, -1, 1, -1, 1)){
        auto d = c;
        d.MinEdge += p.convert!double();
        d.MaxEdge += p.convert!double();
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


//Returns a quick check if a pos is within the limits.
//The limits are inclusive.
bool within(T)(T pos, T min, T max) {
    return !(pos.x < min.x || pos.x > max.x ||
       pos.y < min.y || pos.y > max.y ||
       pos.z < min.z || pos.z > max.z);
}
