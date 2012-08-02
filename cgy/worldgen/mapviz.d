module worldgen.mapviz;


mixin template MapViz() {

    final class MapVisualizer {
        Image getHeightmapImage() {
            return heightMap.toImage(worldMin, worldMax, true, (double v) {
                double[4] ret;
                ret[] = v;
                if(v < 0.3) ret[0..1] = 0;
                return ret;
            });
        }
        Image getShadedHeightmapImage() {
            auto shadedMap = new ValueMap(Dim, Dim);

            shadedMap.fill((double x, double y) {
                double grad = 0.0;
                if(heightMap.get(cast(int)x, cast(int) y) <= 0.0 ) {
                    return 10;
                }
                auto dir = vec2d(-1, 0);
                grad = dir.dotProduct(heightMap.upwindGradient(x, y, dir.X, dir.Y)) * 0.05;
                return 4 + grad;

            }, Dim, Dim);

            return shadedMap.toImage(-10, 100, true);
        }

        Image getTemperatureImage() {
            return temperatureMap.toImage(-30, 50, true, colorSpline(temperatureSpline));
        }

        Image getWindImage() {
            return windMap.toImage(0.0, 1.2, true, colorSpline(temperatureSpline));
        }
        Image getMoistureImage() {
            return moistureMap.toImage(-10, 100, true);
        }


        Image getClimateImage(Image climateTypes = Image("climateMap.bmp"), bool areaBorders = false) {
            Image climateMap = Image(null, Dim, Dim);
            foreach(x, y, ref r, ref g, ref b, ref a ; climateMap) {
                auto height = heightMap.get(x, y);
                if(height <= 0) {
                    r = g = a = 0;
                    b = 96;
                    continue;
                }
                auto moisture = moistureMap.get(x, y);
                auto temp = temperatureMap.get(x, y);

                //int heightIdx = clamp(cast(int)(height*4 / worldMax), 0, 3);
                int tempIdx = clamp(cast(int)((temp-temperatureMin)*4 / temperatureRange), 0, 3);
                int moistIdx = clamp(cast(int)(moisture*4.0/10.0), 0, 3);
                //msg(tempIdx, " ", temp-world.temperatureMin);

                climateTypes.getPixel(3-tempIdx, 3-moistIdx, r, g, b, a);
            }

            if(areaBorders) {
                drawAreaBorders(climateMap, false);
            }
            return climateMap;
        }

        Image getAreaImage(Image climateTypes, bool renderAreaBorders, bool renderAllBorders) {
            Image areaMap = Image(null, Dim, Dim);
            foreach(x, y, ref r, ref g, ref b, ref a ; areaMap) {
                int cellId = areaVoronoi.identifyCell(vec2d(x, y));
                auto area = areas[cellId];

                bool isSea = area.isSea;
                int moistIdx = area.moisture;
                int tempIdx = area.temperature;
                if(isSea) {
                    r = g = a = 0;
                    b = 0;
                    continue;
                }
                auto height = heightMap.get(x, y);
                if(height <= 0) {
                    r = g = a = 0;
                    b = 96;
                    continue;
                }

                climateTypes.getPixel(3-tempIdx, 3-moistIdx, r, g, b, a);

            }
            if(renderAreaBorders || renderAllBorders) {
                drawAreaBorders(areaMap, !renderAllBorders);
            }
            return areaMap;
        }


        Image getRegionImage(bool renderRegionBorders) {
            Image regionMap = Image(null, Dim, Dim);
            foreach(x, y, ref r, ref g, ref b, ref a ; regionMap) {
                int cellId = areaVoronoi.identifyCell(vec2d(x, y));
                auto area = areas[cellId];
                int regionId = area.region.regionId;
                int regionCount = regions.length;
                colorize(regionId, regionCount, r, g, b);
                continue;
            }

            if(renderRegionBorders) {
                drawAreaBorders(regionMap, true);
            }
            return regionMap;
        }

        void drawAreaBorders(Image image, bool onlyRegions) {
            foreach(edge ; areaVoronoi.poly.edges) {
                auto start = edge.getStartPoint();
                auto end = edge.getEndPoint();

                auto height1 = heightMap.getValue(start.pos.X, start.pos.Y);
                auto height2 = heightMap.getValue(end.pos.X, end.pos.Y);
                if(height1 <= 0 || height2 <= 0) {
                    continue;
                }
                int site1 = edge.halfLeft.left.siteId;
                int site2 = edge.halfRight.left.siteId;
                if(onlyRegions) {
                    if((areas[site1].climateType) == (areas[site2].climateType)) continue;
                }
                image.drawLine(start.pos.convert!int, end.pos.convert!int, vec3i(0));
            }
        }

        //Eventually think well, and implement rendering with opengl instead.
        Image generateMap(string type)(TileXYPos tilePos, size_t diameter) {
            //Figure out what level of detail / up to what layer of features we want to display.
            int level = 4; //HARD CODED SHIT :D
            for(int i = 1; i < 5; i++) {

                if(mapScale[i] > diameter) {
                    level = i-1;
                    break;
                }
            }

            static if(type == "Shaded") {
                auto min = tilePos.value - vec2i(diameter / 2);

                auto diam = vec2i(diameter).convert!double;
                auto asd = new ValueMap(Dim, Dim);
                auto shadedMap = new ValueMap(Dim, Dim);
                auto step = vec2d(diameter / 400.0, 0).convert!int;


                asd.fill((double x, double y) {
                    auto dX = cast(double)x / 400.0;
                    auto dY = cast(double)y / 400.0;

                    auto tp = min + (diam * vec2d(dX, dY)).convert!int;

                    auto val = getValueInterpolated(level, TileXYPos(tp));
                    return val;

                }, Dim, Dim);

                shadedMap.fill((double x, double y) {
                    double grad = 0.0;
                    if(asd.get(cast(int)x, cast(int) y) <= 0.0 ) {
                        return 10;
                    }
                    auto dir = vec2d(-1, 0);
                    grad = dir.dotProduct(asd.upwindGradient(x, y, dir.X, dir.Y)) * 0.5;
                    grad = asd.getValue(x, y) / 100;
                    //grad = -(asd.getValue(x, y) - asd.getValue(x-1, y)) * 0.25;
                    return 4 + grad;

                }, Dim, Dim);

                return shadedMap.toImage(-10, 100, true);
            } else {
                auto radius = vec2i(diameter / 2);
                TileXYPos min = tilePos.value - radius;
                TileXYPos max = tilePos.value + radius;
                auto diam = vec2i(diameter).convert!double;
            
                Image img = Image(null, 400, 400);
                foreach(int x, int y, ref ubyte r,ref ubyte g, ref ubyte b, ref ubyte a; img) {
                    auto dX = cast(double)x / 400.0;
                    auto dY = cast(double)y / 400.0;
                    auto tp = min.value + (diam * vec2d(dX, dY)).convert!int;
                    auto val = getValueInterpolated(level, TileXYPos(tp));
                    //msg(val);
                }
                return img;
            }
        }
    }

    MapVisualizer getVisualizer() {
        return new MapVisualizer;
    }

}
