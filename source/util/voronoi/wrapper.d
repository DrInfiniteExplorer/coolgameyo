module util.voronoi.wrapper;

import util.util;
import util.voronoi.voronoi;
import util.voronoi.lattice;
import util.voronoi.fortune;

final class VoronoiWrapper {
    VoronoiLattice lattice;
    VoronoiPoly poly;
    int width, height, seed;

    vec2d scale = vec2d(1.0);
    vec2d latticeScale;

    this(int _width, int _height, int _seed) {
        width = _width;
        height = _height;
        seed = _seed;

    }

    void generate() {

        lattice = new VoronoiLattice(width, height, seed);
        auto fortune = new FortuneVoronoi;
        poly = fortune.makeVoronoi(lattice.points);
        poly.cutDiagram(vec2d(0, 0), vec2d(width, height));
        poly.scale(vec2d(1.0 / width, 1.0 / height));
        latticeScale.set(width, height);
    }

    void setScale(vec2d _scale) {
        auto toNew = _scale / scale;
        scale = _scale;
        latticeScale = vec2d(width, height) / scale;
        poly.scale(toNew);
    }

    int identifyCell(vec2d pt) {
        return lattice.identifyCell(pt * latticeScale);
    }


}
