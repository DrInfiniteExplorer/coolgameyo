module util.voronoi.lattice;

import std.conv;
import std.random;

import util.util;

class VoronoiLattice {
    int width, height;
    int seed;

    vec2d scale;
    vec2d[] points;

    this(int _width, int _height, int _seed) {
        width = _width;
        height = _height;
        seed = _seed;
        scale = vec2d(1);

        //POP U LATE?
        Random gen;
        gen.seed(seed);

        points.length = width * height;
        foreach(y ; 0 .. height) {
            foreach(x ; 0 .. width) {
                
                points[y * width + x] = vec2d(
                    x + uniform(0.05, 0.95, gen),
                    y + uniform(0.05, 0.95, gen)
                );
            }
        }
    }

    void setRange(vec2d max) {
        scale = vec2d(width, height) / max;
    }

    vec2d get(int x, int y) {
        //Can't be that cell; return a distance guaranteed to be longer than
        //to any other neighboring cell.
        if(x < 0 || y < 0 || x >= width || y >= height) return vec2d(-500, -500);
        return points[y * width + x];
    }

    int identifyCell(vec2d pt) {
        pt *= scale;
        if(pt.x < 0) pt.x = 0;
        if(pt.y < 0) pt.y = 0;
        if(pt.x > width) pt.x = width;
        if(pt.y > height) pt.y = height;

        int X = cast(int) pt.x;
        int Y = cast(int) pt.y;

        double distance = 10.0;
        int ret = 0;
        foreach(y ; Y-1 .. Y+2) {
            foreach(x ; X-1 .. X+2) {
                auto dist = get(x, y).getDistanceSQ(pt);
                if(dist < distance) {
                    distance = dist;
                    ret = y * width + x;
                }
            }
        }
        return ret;
    }
}




