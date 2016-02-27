module cgy.math.advect;


void advect(Q, W, E)(Q vectorField, W get, E set, int sizeX, int sizeY, float time) {
    foreach(x, y ; Range2D(0, sizeX, 0, sizeY)) {
        auto startPos = vec2f(x, y); // + vec2f(0.5);
        auto prevPos = trace!(vectorField, typeof(startPos))(startPos, -time);
        set(x, y, get(prevPos));
    }
}


