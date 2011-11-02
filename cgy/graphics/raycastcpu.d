

module graphics.raycastcpu;

import std.conv;

import graphics.camera;
import graphics.image;
import light;
import util.util;
import world.world;

void computeYourMother(World world, Image img, Camera camera) {

    vec3d upperLeft, toRight, toDown, dir, startPos;
    startPos = camera.getPosition();
    camera.getRayParameters(upperLeft, toRight, toDown);

    Tile tile;
    TilePos tilePos;
    vec3i tileNormal;
    double intersectionTime;

    enum maxIter = 100;

    foreach(y ; 0 .. img.imgHeight) {
        int imgY = img.imgHeight-y-1;
        foreach(x ; 0 .. img.imgWidth) {
            double percentX = to!double(x) / to!double(img.imgWidth);
            double percentY = to!double(y) / to!double(img.imgHeight);
            dir = (upperLeft + percentX*toRight + percentY * toDown).normalize();
            int iter = world.intersectTile(startPos, dir, maxIter, tile, tilePos, tileNormal, &intersectionTime);
            if(iter > 0) {
                double dist = intersectionTime;
                int r = cast(int)(255.0*dist/maxIter);
                img.setPixel(x, imgY, r, 0, 0);

            } else {
                img.setPixel(x, imgY, 0, 0, 0);
            }
        }
    }
    

    //world.intersectTile
}
