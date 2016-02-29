
module worldgen.worldpop;

import std.random;

import worldgen.maps;
import random.random;
import random.randsource;


immutable CityKernelSize = 20;
immutable WaterKernelSize = 4;
immutable NearCityDistance = 30;

immutable StartCityCount = 100;

immutable roadVertShader = q{
    #version 430
    layout(location = 0) in ivec2 pos;

    uniform mat4 transform;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;
    uniform vec2 cellSize;

    out vec3 transformedPos;
    flat out ivec2 posss;

    float get(ivec2 pos) {
        float h = texelFetch(height, pos, 0).x;
        h += texelFetch(h2, pos, 0).x;
        //h += texelFetch(h3, pos, 0).x;
        return h;
    }

    void main() {
        float h = get(pos);
        vec3 vert = vec3(pos * cellSize, h);
        gl_Position = transform * vec4(vert, 1.0);
        transformedPos = (transform * vec4(vert, 1.0)).xyz;
        posss = pos;

        float water = clamp(texelFetch(h3, pos, 0).x, 0.0, 1.0);
        //clr = mix(col, vec3(0.1, 0.1, 0.9), water);
    }
};
immutable roadFragShader = q{
    #version 430

    in vec3 transformedPos;
    flat in ivec2 posss;
    layout(location = 0) out vec4 frag_color;
    layout(location = 1) out vec4 light;
    //layout(binding=2, r16f) readonly uniform image2D h3;
    //layout(location = 2) out vec4 depth;
    layout(binding = 0) uniform sampler2D height;
    layout(binding = 1) uniform sampler2D h2;
    layout(binding = 2) uniform sampler2D h3;


    void main() {
        light = vec4(1.0, 1.0, 1.0, 1.0);
        frag_color = vec4(1.0, 0.0, 0.0, 1.0);
    }
};

mixin template WorldPopulation() {

    import std.json : parseJSON;

    import painlessjson : toJSON, fromJSON;

    import cgy.opengl.textures;

    import graphics.ogl;
    import graphics.shader;
    import graphics.heightmap : Heightmap, renderLoop;
    import graphics.camera : Camera;
    import cgy.util.traits : DownwardDelegate;
    import cgy.util.util;
    import cgy.math.aabb;

    class Road {

        this(Endpoint _a, Endpoint _b) {
            a = _a;
            b = _b;
            if(a !is null) {
                a.addRoad(this);
                aabb.reset(a.pos);
            }
            if(b !is null) {
                b.addRoad(this);
                aabb.addInternal(b.pos);
            }
        }

        void add(vec2i pt) {
            if(points.length == 0) {
                if(a !is null) {
                    aabb.reset(a.pos);
                }
                if(b !is null) {
                    aabb.addInternal(b.pos);
                }
            }
            aabb.addInternal(pt);
            points ~= pt;
        }
        void addEndpoint(Endpoint e) {
            if(a is null) {
                e.addRoad(this);
                a = e;
                return;
            }
            BREAK_IF(b !is null);
            e.addRoad(this);
            b = e;

        }
        void removeEndpoint(Endpoint e) {
            if(e == a) {
                a = b;
            }
            if(e == b) {
                b = null;
            }
            e.removeRoad(this);
        }
        bool hasEndpoint(Endpoint e) {
            return e == a || e == b;
        }
        Endpoint commonEndpoint(Road other) {
            if(other.hasEndpoint(a)) {
                return a;
            }
            if(other.hasEndpoint(b)) {
                return b;
            }
            return null;
        }
        bool finished() const @property {
            return a && b;
        }

        aabb2i aabb;
        Endpoint a, b;
        vec2i[] points;

    }

    class Endpoint {
        void addRoad(Road road) {
            if(hasRoad(road)) return;
            roads ~= road;
        }
        bool hasRoad(const Road road) const {
            return roads.countUntil(road) != -1;
        }
        bool connected(Endpoint other) {
            BREAK_IF(this is other);
            foreach(road ; roads) {
                if(road.hasEndpoint(other)) return true;
            }
            return false;
        }
        void removeRoad(Road r) {
            BREAK_IF(!hasRoad(r));
            roads = roads.remove(roads.countUntil(r));
        }

        vec2i pos;
        Road[] roads;
        City city;
    }

    class City {
        vec2i pos;
        Endpoint endpoint;
        int[] closestCities;
    }

    City[] cities;
    Endpoint[] endpoints;
    Road[] roads;

    void saveRoads() {
        //worldPath = "asd/derp/map"
        string roadPath = worldPath ~ "/roads";
        mkdir(roadPath);

        JSONValue serializeCity(City city) {
            int endpointId = cast(int)endpoints.countUntil(city.endpoint);
            return JSONValue([
                "pos" : city.pos.toJSON,
                "closestCities" : city.closestCities.toJSON,
                "endpointId" : endpointId.toJSON]);
        }
        JSONValue serializeEndpoint(Endpoint e) {
            return e.pos.toJSON;
        }
        JSONValue serializeRoad(Road r) {
            int a = cast(int)endpoints.countUntil(r.a);
            int b = cast(int)endpoints.countUntil(r.b);
            return JSONValue([
                "aabb" : r.aabb.toJSON,
                "points" : r.points.toJSON,
                "endpointA" : a.toJSON,
                "endpointB" : b.toJSON
            ]);
        }

        auto val = JSONValue([
            "cityCount" : cities.length,
            "endpointCount" : endpoints.length,
            "roadCount" : roads.length
        ]);

        val["cities" ] = JSONValue(array(map!serializeCity(cities)));
        val["endpoints"] = JSONValue(array(map!serializeEndpoint(endpoints)));
        val["roads"] = JSONValue(array(map!serializeRoad(roads)));

        std.file.write(roadPath ~ "/roads.json", val.toString);
    }

    bool loadRoads() {
        string roadPath = worldPath ~ "/roads/roads.json";
        if(!exists(roadPath)) {
            return false;
        }
        auto value = std.file.readText(roadPath).parseJSON;

        long cityCount = value["cityCount"].integer;
        long endpointCount = value["endpointCount"].integer;
        long roadCount = value["roadCount"].integer;


        auto cityVal = value["cities"];
        auto endpointVal = value["endpoints"];
        auto roadVal = value["roads"];

        cities.length = cityCount;
        endpoints.length = endpointCount;
        roads.length = roadCount;
        foreach(ref c ; cities) {
            c = new City;
        }
        foreach(ref e ; endpoints) {
            e = new Endpoint;
        }
        foreach(ref r ; roads) {
            r = new Road(null, null);
        }

        foreach(size_t idx, JSONValue val ; cityVal) {
            City city = cities[idx];
            long endpointId;
            city.pos = val["pos"].fromJSON!(typeof(city.pos));
            city.closestCities = val["closestCities"].fromJSON!(typeof(city.closestCities));
            endpointId = val["endpointId"].integer;
            
            city.endpoint = endpoints[endpointId];
            city.endpoint.city = city;
        }
        foreach(size_t idx, JSONValue val ; endpointVal) {
            Endpoint endpoint = endpoints[idx];
            endpoint.pos = val.fromJSON!vec2i;
        }
        foreach(size_t idx, JSONValue val ; roadVal) {
            Road road = roads[idx];

            long endpointA = val["endpointA"].integer;
            long endpointB = val["endpointB"].integer;

            road.addEndpoint(endpoints[endpointA]);
            road.addEndpoint(endpoints[endpointB]);
            road.aabb = val["aabb"].fromJSON!(typeof(road.aabb));
            road.points = val["points"].fromJSON!(typeof(road.points));
        }        
        return true;
    }

    bool cityNear(vec2i pos) {
        foreach(data ; cities) {
            if(data.pos.getDistanceSQ(pos) < (NearCityDistance ^^ 2) ) {
                return true;
            }
        }
        return false;
    }

    Random popGen;
    void generateLife() {
        string roadPath = worldPath ~ "/roads/roads.json";

        initGenerateLife();
        scope(exit) {
            deinitGenerateLife();
        }
        if(loadRoads()) {
            render();
            return;
        }

        popGen.seed(walkSeed);

        foreach(size_t idx; 0 .. StartCityCount) {
            City city;
            city = new City;
            Endpoint endpoint = new Endpoint;
            city.endpoint = endpoint;
            endpoint.city = city;
            do {
                float score = 0.0;
                int X = void;
                int Y = void;
                do {
                    X = uniform(0, TotalSamples, popGen);
                    Y = uniform(0, TotalSamples, popGen);
                    foreach(x, y ; Range2D(X - CityKernelSize / 2, X + CityKernelSize / 2,
                                       Y - CityKernelSize / 2, Y + CityKernelSize / 2)) {
                        float tmpScore = evaluateVillageScore(vec2i(x, y));
                        if(tmpScore > score && x >= 0 && x < TotalSamples && y > 0 && y < TotalSamples) {
                            score = tmpScore;
                            city.pos.set(x, y);
                        }
                    }
                } while(score == 0.0);

            } while(cityNear(city.pos));
            cities ~= city;
            endpoints ~= endpoint;
            endpoint.pos = city.pos;
        }



        float[StartCityCount] cityDistance;
        size_t[StartCityCount] index;
        foreach(size_t idx, ref city ; cities) {
            foreach(size_t otherIdx, ref otherCity ; cities) {
                cityDistance[otherIdx] = (city.pos - otherCity.pos).convert!float.getLength();
            }
            size_t[] arr = index;
            float[] rra = cityDistance;
            makeIndex(rra, arr); // Lol, does not work with fixed size arrays. Need the two lines above.
            city.closestCities.length = 5;
            foreach(idxIdx ; 0 .. 5) {
                city.closestCities[idxIdx] = cast(int)index[idxIdx+1]; // +1 because [0] is us!
                writeln(index[idxIdx+1], " ", idx);
            }
        }

        int[2][] cityConnections;
        foreach(size_t idx, ref city ; cities) {
            foreach(otherIdx ; city.closestCities) {
                int i1 = cast(int)idx;
                int i2 = otherIdx;
                if(i1 < i2) {
                    swap(i1, i2);
                }
                int[2] tmp = makeStackArray(i1, i2);
                if(countUntil(cityConnections, tmp) == -1) {
                    cityConnections ~= tmp;
                }
            }
        }

        bool less(int[2] idx1, int[2] idx2) {
            return (cities[idx1[0]].pos - cities[idx1[1]].pos).getLengthSQ()
                < (cities[idx2[0]].pos - cities[idx2[1]].pos).getLengthSQ;
        }

        // Start by connecting the shortest roads; long roads may take advantage of existing short roads and bridges,
        //  which are "more likely" to be built/developed before long long routes.
        sort!less(cityConnections);
        foreach(size_t idx, connection ; cityConnections) {
            msg("\t", idx, " of ", cityConnections.length);
            msg(connection[0], " ", connection[1]);
            computeRoad(connection[0], connection[1]);
        }

        foreach(road ; roads) {
            if(road.points.length > 0) {
                auto pt = road.points[0];
                int distance = road.a.pos.getDistanceSQ(pt);
                if(distance > 2) {
                    swap(road.a, road.b);
                }
            }
        }
        // Make code to split roads which are longer than X long,
        // to help reduce the size of BB's of roads.

        saveRoads();
        render();
    }

    Road getRoad(vec2i pt) {
        foreach(road ; roads) {
            if(road.aabb.isInside(pt)) {
                if(road.points.countUntil(pt) != -1) {
                    return road;
                }
            }
        }
        return null;
    }

    Road[] getRoadsInSector(SectorNum sectorNum) {
        // What
        auto startTilePos = sectorNum.toTileXYPos.value;
        auto endTilePos = startTilePos + vec2i(SectorSize.x, SectorSize.y);
        vec2i minRoadPos = (startTilePos.convert!float / 25.0f).fastFloor;
        vec2i maxRoadPos = (  endTilePos.convert!float / 25.0f).fastCeil;
        bool[Road] roads;
        foreach(x, y ; Range2D(minRoadPos, maxRoadPos)) {
            auto road = getRoad(vec2i(x,y));
            if(road !is null){
                roads[road] = true;
            }
        }
        return roads.keys;
    }

    Endpoint getEndpoint(vec2i pt) {
        foreach(endpoint ; endpoints) {
            if(endpoint.pos == pt) {
                return endpoint;
            }
        }
        return null;
    }

    Endpoint splitRoad(Road r, vec2i pt) {
        Endpoint a = r.a;
        Endpoint b = r.b;
        BREAK_IF(a is null);
        BREAK_IF(b is null);
        Endpoint ret = new Endpoint;
        ret.pos = pt;
        Road newRoad = new Road(ret, b);
        r.removeEndpoint(b);
        r.addEndpoint(ret);

        r.aabb.reset(r.a.pos);
        r.aabb.addInternal(r.b.pos);
        foreach(p ; r.points) {
            r.aabb.addInternal(p);
        }

        int idx = cast(int)r.points.countUntil(pt);
        BREAK_IF(idx == -1);
        newRoad.points = r.points[idx+1 .. $];
        foreach(p ; newRoad.points) {
            newRoad.aabb.addInternal(p);
        }
        r.points.length = idx;
        roads ~= newRoad;
        endpoints ~= ret;

        return ret;
    }

    int cnt = 0;
    void computeRoad(int pt1, int pt2) {
        //if(cnt > 10) return;
        cnt++;
        msg("Road between ", pt1, " and ", pt2);

        auto start = endpoints[pt1];
        auto end   = endpoints[pt2];

        auto startPos = start.pos;
        auto endPos = end.pos;

        roadCompute.use();
        roadCompute.uniform.startPos = startPos;
        roadCompute.uniform.endPos = endPos;

        float highValue = WorldSize * 10;
        import cgy.util.memory;
        msg("mem ", getMemoryUsage());
        FillTexture(roadDistanceTex, highValue, 0, 0, 0);
        msg("mem ", getMemoryUsage());
        glBindImageTexture(0, roadHeightTex,   0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();
        glBindImageTexture(1, roadWaterTex,    0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();
        glBindImageTexture(2, roadDistanceTex, 0, GL_FALSE, 0, GL_READ_WRITE, GL_R32F); glError();
        glBindImageTexture(3, roadRoadTex,     0, GL_FALSE, 0, GL_READ_ONLY,  GL_R32F); glError();


        int maxPathLength = startPos.getDistance(endPos) * 2;
        msg("dist ", maxPathLength / 2);

        vec2i ul = startPos;
        vec2i lr = startPos;
        foreach(iter ; 0 .. maxPathLength) {
            glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

            ul.x = max(0, ul.x-1);
            ul.y = max(0, ul.y-1);
            lr.x = max(lr.x+1, TotalSamples/16 -1);
            lr.y = max(lr.y+1, TotalSamples/16 -1);
            roadCompute.uniform.origin = ul;
            int dX = lr.x - ul.x + 1;
            int dY = lr.y - ul.y + 1;
            int delta = max(dX, dY);
            int units = cast(int)ceil(delta / 16.0);
            glDispatchCompute(units, units, 1); glError();
        }
        glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
        roadCompute.use(false);
        glBindTexture(GL_TEXTURE_2D, roadDistanceTex);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, roadTmp.ptr); glError();
        //heightMaps.heightData[] = tmp[];
        //heightMaps.heightData[] -= 103_000.0;




        float get(int x, int y) {
            return roadTmp[y * TotalSamples + x];
        }
        vec2i getBest(vec2i pt, float minScore) {
            if(minScore == 0.0) return pt;
            vec2i ret;
            bool found = false;
            foreach(n ; neighbors2D_8(pt)) {
                if(n.x < 0 || n.y < 0 || n.x == TotalSamples || n.y == TotalSamples) continue;
                float score = get(n.x, n.y);
                if(score < minScore) {
                    ret = n;
                    found = true;
                    minScore = score;
                }
            }
            BREAK_IF(!found);
            return ret;
        }

        Road[] newRoads;

        vec2i pt = getBest(endPos, get(endPos.x, endPos.y));
        Endpoint endpoint = getEndpoint(pt);
        Road road = getRoad(pt);
        BREAK_IF(road && endpoint);
        if(endpoint) {
            if(!endpoint.connected(end)) {
                Road r = new Road(endpoint, end);
                newRoads ~= r;
                roads ~= r;
            }
        } else if(road) {
        } else {
            road = new Road(end, null);
            road.add(pt);
            endpoint = null;
        } 

        void printImages() {
            Image img;
            /*
            img.fromGLFloatTex(roadHeightTex, 0, 2000);
            img.setPixel(startPos.x, startPos.y, 0, 255, 0);
            img.setPixel(endPos.x, endPos.y, 0, 0, 255);
            img.save("height.png");
            img.fromGLFloatTex(roadWaterTex, 0, 50);
            img.setPixel(startPos.x, startPos.y, 0, 255, 0);
            img.setPixel(endPos.x, endPos.y, 0, 0, 255);
            img.save("water.png");
            */
            img.fromGLFloatTex(roadDistanceTex, 0, 50);
            //img.save("distance_nr.png");
            foreach(r ; roads) {
                foreach(_pt ; r.points) {
                    img.setPixel(_pt.x, _pt.y, 192, 192, 192);
                }
            }
            if(road) {
                foreach(_pt ; road.points) {
                    img.setPixel(_pt.x, _pt.y, 192, 192, 0);
                }
            }
            foreach(e ; endpoints) {
                img.setPixel(e.pos.x, e.pos.y, 192, 0, 192);
            }
            img.setPixel(startPos.x, startPos.y, 0, 255, 0);
            img.setPixel(endPos.x, endPos.y, 0, 0, 255);
            img.save("distance.png");

            img.fromGLFloatTex(roadRoadTex, 0, 1);
            img.setPixel(startPos.x, startPos.y, 0, 255, 0);
            img.setPixel(endPos.x, endPos.y, 0, 0, 255);
            foreach(r ; newRoads) {
                foreach(_pt ; r.points) {
                    img.setPixel(_pt.x, _pt.y, 192, 192, 192);
                }
            }
            img.save("roadroad.png");
            img.destroy();
        }

        while(pt != startPos) {
            vec2i nextPt = getBest(pt, get(pt.x, pt.y));
            Road otherRoad = getRoad(nextPt);
            Endpoint otherEndpoint = getEndpoint(nextPt);
            scope(exit) {
                pt = nextPt;
            }
            BREAK_IF(otherRoad && otherEndpoint); // Cant have road and endpoint at same place.
            BREAK_IF(road && endpoint); // Cant have road and endpoint at same place.
            BREAK_IF(!road && !endpoint); // Cant have neither road and endpoint

            // If on endpoint:
            if(endpoint) {
                // can go to other endpoint
                if(otherEndpoint) {
                    if(!endpoint.connected(otherEndpoint)) {
                        Road r = new Road(endpoint, otherEndpoint);
                        newRoads ~= r;
                        roads ~= r;
                    }
                    endpoint = otherEndpoint;
                    continue;
                }
                // if goes onto road, just go on road.
                if(otherRoad) {
                    road = otherRoad;
                    endpoint = null;
                    // But if its the final road, finish.
                    if(end.hasRoad(road)) {
                        nextPt = startPos;
                    }
                    continue;
                }
                // If goes on not-road, start new road at endpoint we are leaving.
                road = new Road(endpoint, null);
                road.add(nextPt);
                endpoint = null;
            // ELSE we are on a road
            } else {
                //  if otherroad == thisroad, continue walking, its the same road.
                if(otherRoad is road) continue;
                //  if otherEndpoint, join it
                if(otherEndpoint) {
                    if(road.finished) {
                        //BREAK_IF(!otherEndpoint.hasRoad(road));
                        if(!otherEndpoint.hasRoad(road)) {
                            Endpoint e = splitRoad(road, pt);
                            Road r = new Road(e, otherEndpoint);
                            newRoads ~= r;
                            roads ~= r;
                        }
                        endpoint = otherEndpoint;
                        road = null;
                    } else {
                        road.addEndpoint(otherEndpoint);
                        roads ~= road;
                        newRoads ~= road;
                    }
                    endpoint = otherEndpoint;
                    road = null;
                }
                //  if otherroad == null -> we will go offroad!
                else if(otherRoad is null) {
                    //  if finished(road), split road, create endpoint in between, start new road.
                    if(road.finished) {
                        int findSameRoadLimit = 5;
                        vec2i here = nextPt;
                        bool same = false;
                        Road aRoad;
                        foreach(iter ; 0 .. findSameRoadLimit) {
                            here = getBest(here, get(here.x, here.y));
                            aRoad = getRoad(here);
                            if(aRoad) {
                                if(aRoad is road
                                    || road.commonEndpoint(aRoad)) {
                                    same = true;
                                    break;
                                }
                            }
                        }
                        if(same) {
                            nextPt = here;
                            road = aRoad;
                            msg("skipping derp");
                            continue;
                        } else {
                            endpoint = splitRoad(road, pt);
                            road = new Road(endpoint, null);
                            road.add(nextPt);
                            endpoint = null;
                        }
                    //  else just continue building the road!
                    } else {
                        road.add(nextPt);
                    }
                }
                //  if otherroad != null, split otherroad, join endpoint, continue from endpoint
                else if(otherRoad !is null) {

                    // If both roads are finished, there is a chance that they share an endpoint
                    // one unit from here.
                    if(road.finished && otherRoad.finished) {
                        Endpoint common = road.commonEndpoint(otherRoad);
                        if(common
                           && common.pos.getDistanceSQ(pt) <= 5
                           && common.pos.getDistanceSQ(nextPt) <= 5) {
                            road = otherRoad;
                            continue;
                        }

                        // There isn't a common endpoint within reasonable distance...
                        // Split both roads and join them.
                        //   "be aware" that in this case, its likely probable that the roads
                        //   are running in parallel to each other, and may do so for a long or short distance.
                        //   An extra clean-up step should be taken after all roads are done, to eliminate
                        //    short double-road segments which both have the same two endpoints.

                        Endpoint e = splitRoad(road, pt);
                        endpoint = splitRoad(otherRoad, nextPt);
                        road = new Road(endpoint, e);
                        newRoads ~= road;
                        roads ~= road;
                        road = null;
                        continue;
                    }
                    if(!otherRoad.finished) {
                        printImages();
                        BREAKPOINT;
                    }
                    endpoint = splitRoad(otherRoad, nextPt);
                    road.addEndpoint(endpoint);
                    roads ~= road;
                    newRoads ~= road;
                    road = null;
                }
            }
        }

        //printImages();

        glBindTexture(GL_TEXTURE_2D, roadRoadTex);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, roadTmp.ptr); glError();

        foreach(r ; newRoads) {
            foreach(size_t idx, p ; r.points) {
                roadTmp[p.y * TotalSamples + p.x] = 1.0;
            }
        }

        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, TotalSamples, TotalSamples, GL_RED, GL_FLOAT, roadTmp.ptr); glError();
        //msg(roadEdges);
    }

    uint roadHeightTex;
    uint roadWaterTex;
    uint roadDistanceTex;
    uint roadRoadTex;
    float[] roadTmp;
    ShaderProgram!() roadCompute;
    void initGenerateLife() {
        roadCompute = new ShaderProgram!();
        roadCompute.compileCompute(roadComputeShader);
        roadCompute.link();
        roadCompute.use();
        roadCompute.uniform.size = vec2i(TotalSamples);
        roadCompute.uniform.SampleIntervall = cast(float)SampleIntervall;
        roadTmp.length = heightMaps.heightData.length;
        roadTmp.convertArray(heightMaps.heightData);
        roadTmp.convertArray!"+="(heightMaps.soilData);
        roadHeightTex = Create2DTexture!float(GL_R32F, TotalSamples, TotalSamples, roadTmp.ptr);
        roadTmp.convertArray(heightMaps.waterData);
        roadWaterTex = Create2DTexture!float(GL_R32F, TotalSamples, TotalSamples, roadTmp.ptr);
        roadDistanceTex = Create2DTexture(GL_R32F, TotalSamples, TotalSamples);
        roadRoadTex = Create2DTexture(GL_R32F, TotalSamples, TotalSamples);
        FillTexture(roadRoadTex, 0.0, 0, 0, 0);
    }

    void deinitGenerateLife() {
        roadCompute.destroy();
        DeleteTextures(roadHeightTex, roadWaterTex, roadDistanceTex, roadRoadTex);
        roadTmp = null;
    }

    static immutable roadComputeShader = q{
        #version 430
        layout(local_size_x = 16 , local_size_y = 16, local_size_z = 1) in;

        layout(binding=0, r32f) readonly uniform image2D height;
        layout(binding=1, r32f) readonly uniform image2D water;
        layout(binding=2, r32f) uniform image2D distance;
        layout(binding=3, r32f) uniform image2D road;
        uniform ivec2 origin;
        uniform ivec2 startPos;
        uniform ivec2 endPos;
        uniform ivec2 size;
        uniform float SampleIntervall;


        float computeDistance(ivec2 from, float myHeight, float myWater, float myRoad, float myDist) {
            float slope = (myHeight - imageLoad(height, from).x) / SampleIntervall;
            slope = abs(slope);
            float distance = 1 + 4.0 * slope + 6.0 * myWater;
            if(myRoad != 0.0) {
                return distance * 0.5;
            } else {
                return distance * myDist;
            }
        }

        bool inside(ivec2 pos) {
            return pos.x >= 0 && pos.y >= 0
                && pos.x < size.x && pos.y < size.y;
        }

        void main() {
            ivec2 myPos = origin + ivec2(gl_GlobalInvocationID.xy);
            float myHeight = imageLoad(height, myPos).x;
            float myWater = imageLoad(water, myPos).x;
            float myRoad = imageLoad(road, myPos).x;

            float myDistance = imageLoad(distance, myPos).x;
            float oldDistance = myDistance;
            ivec2[8] dirs = ivec2[8](ivec2( 1, 1),
                                     ivec2( 1, 0),
                                     ivec2( 1,-1),
                                     ivec2( 0, 1),
                                     ivec2( 0,-1),
                                     ivec2(-1, 1),
                                     ivec2(-1, 0),
                                     ivec2(-1,-1)
                                     );

            for(int idx = 0; idx < 8; idx++) {
                if(myPos == startPos) {
                    imageStore(distance, myPos, vec4(0.0));
                    myDistance = 0.0;
                }
                memoryBarrierImage();
                ivec2 dir = dirs[idx];
                ivec2 otherPos = myPos + dirs[idx];
                if(inside(otherPos)) {
                    float value = imageLoad(distance, otherPos).x;
                    value += computeDistance(otherPos, myHeight, myWater, myRoad, length(vec2(dir.x, dir.y)));
                    myDistance = min(myDistance, value);
                }
            }

            if(myDistance < oldDistance) {
                imageStore(distance, myPos, vec4(myDistance));
            }
        }
    };

    void render() {

        HMap height = new HMap;
        scope(exit) {
            height.destroy();
        }
        height.depth = WorldSize;
        height.width = WorldSize;

        roadTmp.convertArray(heightMaps.heightData);
        uint heightTex = Create2DTexture!float(GL_R32F, TotalSamples, TotalSamples, roadTmp.ptr);
        roadTmp.convertArray(heightMaps.soilData);
        uint soilTex = Create2DTexture!float(GL_R32F, TotalSamples, TotalSamples, roadTmp.ptr);
        roadTmp.convertArray(heightMaps.waterData);
        uint waterTex = Create2DTexture!float(GL_R32F, TotalSamples, TotalSamples, roadTmp.ptr);
        scope(exit) {
            DeleteTextures(heightTex, soilTex, waterTex);
        }
        uint[3] texes = makeStackArray(heightTex, soilTex, waterTex);
        
        height.loadTexture(texes, TotalSamples, TotalSamples);
        height.setColor(vec3f(0.4, 0.7, 0.3));

        bool done = false;
        Camera camera = new Camera;
        camera.speed *= 7;
        camera.farPlane *= 25;
        //camera.setPosition(vec3d(WorldSize / 3.0, -(WorldSize / 5.0), WorldSize / 3.0));
        //camera.setTargetDir(vec3d(0.1, 0.7, -0.4));
        camera.setPosition(vec3d(18166.7, 17122.6, -947.274));
        camera.setTargetDir(vec3d(-0.638903, 0.42497, -0.641251));
        //camera.mouseMoveEnabled = false;
        //camera.printPosition = true;


        auto roadShader = new ShaderProgram!();
        roadShader.compileVertex(roadVertShader);
        roadShader.compileFragment(roadFragShader);
        roadShader.link();
        scope(exit) {
            roadShader.destroy();
        }

        renderLoop(
            camera, 
            { return false; },
            {
                //height.render(camera, true);
                height.render(camera);
                glLineWidth(5.0);
                roadShader.use();
                roadShader.uniform.transform = camera.getProjectionMatrix * camera.getViewMatrix;
                roadShader.uniform.cellSize = vec2f(SampleIntervall);

                glEnableVertexAttribArray(0); glError();

                foreach(road ; roads) {
                    glVertexAttribIPointer(0u, 2, GL_INT, vec2i.sizeof, road.points.ptr); glError();
                    //glDrawElements(GL_LINES, cast(uint)roadEdges.length * 2, GL_UNSIGNED_INT, cast(void*)0);
                    glDrawArrays(GL_LINE_STRIP, 0, cast(int)road.points.length); glError();
                }
                glDisableVertexAttribArray(0); glError();

                roadShader.use(false);
                glLineWidth(1.0);
            }
        );
    }

    float evaluateVillageScore(vec2i pos) {
        vec2f slopeVect = heightMaps.getSampleSlope(pos);
        float slope = slopeVect.getLength();
        float minSlope = max(0.33, slope);
        float slopeScore = 3.0 / minSlope;

        int waterCount = 0;
        foreach(x, y ; Range2D(pos.x - WaterKernelSize / 2, pos.x + WaterKernelSize / 2,
                               pos.y - WaterKernelSize / 2, pos.y + WaterKernelSize / 2)) {
            auto waterLevel = heightMaps.getWaterValueClamp(x, y);
            if(waterLevel > 0.2) {
                waterCount++;
            }
        }
        if(heightMaps.getWaterValueClamp(pos.x, pos.y) > 0.2) return 0.0; // Cant live in water
        waterCount = min(waterCount, 5);
        float waterScore = waterCount / 5.0;

        return slopeScore * waterScore;
    }

}




