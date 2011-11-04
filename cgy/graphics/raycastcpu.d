

module graphics.raycastcpu;

import std.conv;
import std.math;
import std.stdio;

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
    vec3i tileNormal, dummyNormal;
    double intersectionTime;

    enum maxIter = 100;
    double min = double.max;
    double max = -double.max;

    int startX = 7*img.imgWidth/16;
    int stopX = 9*img.imgWidth/16;
    int startY = 7*img.imgHeight/16;
    int stopY = 9*img.imgHeight/16;
    foreach(y ; startY .. stopY) {
        writeln(y, " ", min, " ", max);
        foreach(x ; startX .. stopX) {
            double percentX = to!double(x) / to!double(img.imgWidth);
            double percentY = to!double(y) / to!double(img.imgHeight);
            dir = (upperLeft + percentX*toRight + percentY * toDown).normalize();
            int iter = world.intersectTile(startPos, dir, maxIter, tile, tilePos, tileNormal, &intersectionTime);
            if(iter > 0) {
                /*
                double dist = intersectionTime;
                int r = cast(int)(255.0*dist/maxIter);
                img.setPixel(x, y, r, 0, 0);
                /*/ 
                //intersectionTime -= 0.05;
                vec3d intersectionPoint = startPos + dir * intersectionTime;
                intersectionPoint = intersectionPoint + convert!double(tileNormal)*0.01;
                auto intersectionTilePos = TilePos(convert!int(intersectionPoint));
                auto lights = world.getAffectingLights(intersectionTilePos, intersectionTilePos);
                double accumulatedLight = 0.0;
                foreach(light ; lights) {
                    auto toLight = light.position-intersectionPoint;
                    auto distance = toLight.getLength();
                    int maxLightIter = cast(int)ceil(abs(toLight.X) + abs(toLight.Y) + abs(toLight.Z));
                    double dotValue = toLight.dotProduct(convert!double(tileNormal));
                    if(dotValue <= 0) {
                    }
                    if( !world.rayCollides(intersectionPoint, light.position)) {
                        toLight.normalize();
                        accumulatedLight += dotValue * (1.0/(distance+1));
                    }
                }
                min = std.algorithm.min(min, accumulatedLight);
                max = std.algorithm.max(max, accumulatedLight);

                img.setPixel(x, y, cast(int)(255*accumulatedLight), 0, 0);
                // */
            } else {
                img.setPixel(x, y, 0, 0, 0);
            }
        }
    }
    

    //world.intersectTile
}
