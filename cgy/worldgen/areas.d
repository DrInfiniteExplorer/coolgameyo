module worldgen.areas;

import std.algorithm;
import std.array;
import std.bitmanip;

import json;

struct Area_t {
    union {
        mixin(bitfields!(
                         uint, "temperature", 2,
                         uint, "moisture",    2,
                         bool, "isSea",       1,
                         uint, "derpderpderp",3));
        mixin(bitfields!(
                         uint, "climateType", 5,
                         uint, "predpredpred",3));
    };
    void setSea() {
        climateType = 1<<4; //only sea.

    }
    int areaId;
    Region region;
}
alias Area_t* Area;

final class Region {
    int regionId;
    Area[] areas;

    this(int idx) {
        regionId = idx;
    }

    Value toJSON() {
        return makeJSONObject("regionId", regionId,
                              "areas", array(map!"a.areaId"(areas)));
    }

    void fromJSON(Value val, Area areas) {
        int[] areaArray;
        val.readJSONObject("regionId", &regionId,
                           "areas", &areaArray);
        foreach(areaId ; areaArray) {
            addArea(&areas[areaId]);
        }

    }

    void addArea(Area area) {
        areas ~= area;
        area.region = this;
    }
}

mixin template Areas() {
    VoronoiWrapper areaVoronoi;

    Area_t[Dim*Dim/16] areas;

    Region[] regions;

    void areasInit() {
        //Do nothing here. Just be awesome.
    }

    string areasJSONPath() const @property {
        return worldPath ~ "/areas.bin";
    }
    string regionsJSONPath() const @property {
        return worldPath ~ "/regions.json";
    }


    void saveAreas() {
        writeBin(areasJSONPath, areas);
        encode(regions).saveJSON(regionsJSONPath, false);

    }
    void loadAreas() {
        Area_t[] temp;
        readBin(areasJSONPath, temp);
        areas[] = temp[];

        auto regionsValue = loadJSON(regionsJSONPath);
        regions.length = regionsValue.arrayLength;
        foreach(idx, regionValue ; regionsValue.asArray()) {
            auto region = new Region(idx);
            region.fromJSON(regionValue, areas.ptr);
            regions[idx] = region;
        }
    }

    void generateAreas() {
        areaVoronoi = new VoronoiWrapper(Dim/4, Dim/4, voronoiSeed);
        areaVoronoi.setScale(vec2d(Dim));
        classifyAreas();
    }

    auto getLayerAreas(int level, vec2i mapNum) {
        //Get the size of the map
        //Get the "distance between cells"
        //Use thinking to realize we only need to
        // iterate sizeOfMap±? areas, which we check
        // OR
        //  bruteforce-check all vertices, to make an
        //  array of vertices inside the sizeOfMap
        //  and return it
        //
        //The later alternative requies less thought, and will produce results faster
        // but less optimally, so do it and return later
        //TODO: Above comments.

        auto scale = mapScale[level];
        auto layerMapSize = vec2d(scale);
        Rectd layerArea;
        layerArea.start = mapNum.convert!double * layerMapSize;
        layerArea.size = layerMapSize;
        

        bool[int] areas;

        foreach(vert ; areaVoronoi.poly.vertices) {
            if(layerArea.isInside(vert.pos)) {
                foreach(edge ; vert.getEdges) {
                    areas[edge.left.siteId] = true;
                }
            }
        }
        Area[] ret;
        ret.length = areas.length;
        int c = 0;
        foreach(key ; areas.byKey()) {
            ret[c++] = &this.areas[key];
        }
        return ret;
    }

    void classifyAreas() {
        auto poly = areaVoronoi.poly;
        double temp[Dim*Dim/16];
        double moisture[Dim*Dim/16];
        double count[Dim*Dim/16];
        bool isSea[Dim*Dim/16];
        isSea[] = true;
        temp[] = 0;
        moisture[] = 0;
        count[] = 0;
        //Determine average climate in cell / area
        foreach(x, y ; Range2D(0, 400, 0, 400)) {
            int cellId = areaVoronoi.identifyCell(vec2d(x, y));
            temp[cellId] += temperatureMap.get(x, y);
            moisture[cellId] += moistureMap.get(x, y);
            count[cellId] += 1;
            if(heightMap.get(x, y) > 0) {
                isSea[cellId] = false;
            }
        }
        temp[] /= count[];
        moisture[] /= count[];

        //Transition from "cell" to "area"
        foreach(idx ; 0 .. Dim*Dim/16) {
            int tempIdx = clamp(cast(int)((temp[idx]-temperatureMin)*4 / temperatureRange), 0, 3);
            int moistIdx = clamp(cast(int)(moisture[idx]*4.0/10.0), 0, 3);
            //msg(temp[Idx], " ", moisture[Idx]);
            if(isSea[idx]) {
                areas[idx].setSea();
            } else {
                areas[idx].temperature = tempIdx;
                areas[idx].moisture = moistIdx;
            }
            areas[idx].areaId = idx;
        }

        //Group areas together into regions by floodfill.
        foreach(idx ; 0 .. Dim*Dim/16) {
            Area startArea = &areas[idx];
            if(startArea.region !is null) continue;

            Region region = new Region(regions.length);
            regions ~= region;

            //Floodfill from this area to all of the same type.
            int climateType = startArea.climateType;
            bool[int] visited;
            bool[int] toVisit;
            toVisit[idx] = true;
            while(toVisit.length > 0) {
                int visitedAreaId = toVisit.keys[0]; 
                Area area = &areas[visitedAreaId];
                toVisit.remove(visitedAreaId);
                int areaClimateType = area.climateType;
                if(areaClimateType != climateType) continue;
                region.addArea(area);
                visited[visitedAreaId] = true;
                foreach(neighbor ; areaVoronoi.poly.sites[visitedAreaId].getNeighbors()) {
                    if(neighbor is null) continue;
                    if( neighbor.siteId in visited) continue;
                    toVisit[neighbor.siteId] = true;
                }
            }
        }

    }

}
