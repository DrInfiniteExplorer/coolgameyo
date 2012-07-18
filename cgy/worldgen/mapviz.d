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

        Image getTemperatureImage() {
            return temperatureMap.toImage(-30, 50, true, colorSpline(temperatureSpline));
        }

        Image getWindImage() {
            return windMap.toImage(0.0, 1.2, true, colorSpline(temperatureSpline));
        }
        Image getMoistureImage() {
            return moistureMap.toImage(-10, 100, true);
        }

        Image getClimateImage(Image climateTypes, bool areaBorders = false) {
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
    }

    MapVisualizer getVisualizer() {
        return new MapVisualizer;
    }

}
