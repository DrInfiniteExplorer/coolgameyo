module gui.worldview;

import std.conv;
import std.exception;

import graphics.image;

import gui.mainmenu;
import gui.all;
import gui.guisystem.button;
//import worldgen.worldgen;
//import worldgen.newgen;
import util.util;
import util.rect;

import random.catmullrom;
import random.randsource;


import statistics;
import worldgen.maps;


class WorldMenu : GuiElementWindow {
    GuiElement guiSystem;
    GuiElement creator;

    GuiElementImage heightImg;
    GuiElementImage moistureImg;
    GuiElementImage temperatureImg;

    GuiElementImage windImg;

    GuiElementImage voronoiImg;
    Image voronoiImage;
    bool renderEveryCell = false;
    bool renderRegions = false;
    bool renderRegionBorders = false;

    GuiElementImage climateMapImg;
    Image climateMap;
    bool renderClimateBorders = false;

    //The map used to visualize climate types.
    GuiElementImage climateTypesImg;
    Image climateTypes;

    bool zoomed;
    Rectd oldPos;

    WorldMap worldMap;
    WorldMap.MapVisualizer mapViz;
    int seed;

    this(GuiElement _creator) {
        creator = _creator;
        guiSystem = creator.getGuiSystem();


        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "World Mapexperiment Menu~~~!", false, false);

        heightImg = new GuiElementImage(this, Rectd(clientArea.leftOf, clientArea.topOf, 0.3, 0.3));
        temperatureImg = new GuiElementImage(this, Rectd(heightImg.rightOf, heightImg.topOf, 0.3, 0.3));
        moistureImg = new GuiElementImage(this, Rectd(temperatureImg.rightOf, temperatureImg.topOf, 0.3, 0.3));

        windImg = new GuiElementImage(this, Rectd(heightImg.leftOf, heightImg.bottomOf, 0.3, 0.3));
        voronoiImg = new GuiElementImage(this, Rectd(windImg.rightOf, windImg.topOf, 0.3, 0.3));
        climateMapImg = new GuiElementImage(this, Rectd(voronoiImg.rightOf, voronoiImg.topOf, 0.3, 0.3));

        heightImg.setMouseClickCallback(&zoomImage);
        moistureImg.setMouseClickCallback(&zoomImage);
        temperatureImg.setMouseClickCallback(&zoomImage);

        windImg.setMouseClickCallback(&zoomImage);
        voronoiImg.setMouseClickCallback(&zoomImage);
        climateMapImg.setMouseClickCallback(&zoomImage);
        climateMap = Image(null, Dim, Dim);

        voronoiImage = Image(null, Dim, Dim);

        worldMap = new WorldMap(880128);
        worldMap.generate();
        mapViz = worldMap.getVisualizer();

        auto button = new PushButton(this, Rectd(vec2d(0.75, 0.75), vec2d(0.2, 0.10)), "Back", &onBack);

        auto seedEdit = new GuiElementLabeledEdit(this, Rectd(windImg.leftOf, windImg.bottomOf, 0.2, 0.05), "seed", to!string(worldMap.worldSeed));
        seedEdit.setOnEnter((string value) {
            seed = to!int(value);
            redraw(true);
        });

        auto randomButton = new PushButton(this, Rectd(seedEdit.leftOf, seedEdit.bottomOf, 0.2, 0.10), "Random", {
            auto rand = new RandSourceUniform(seed);
            seed = rand.get(int.min, int.max);
            seedEdit.setText(to!string(seed));
            redraw(true);
        });

        auto saveImagesButton = new PushButton(this, Rectd(randomButton.leftOf, randomButton.bottomOf, 0.2, 0.1), "Save images", {
            heightImg.saveImage("worldview_height.bmp");
            temperatureImg.saveImage("worldview_temperature.bmp");
            moistureImg.saveImage("worldview_moisture.bmp");
            windImg.saveImage("worldview_wind.bmp");
            voronoiImg.saveImage("worldview_voronoi.bmp");
            climateMapImg.saveImage("worldview_climates.bmp");
        });


        climateTypesImg = new GuiElementImage(this, Rectd(saveImagesButton.leftOf, saveImagesButton.bottomOf, saveImagesButton.heightOf, saveImagesButton.heightOf));
        climateTypes = Image("climateMap.bmp");
        climateTypesImg.setImage(climateTypes);


        auto climate_borders = new CheckBox(this, Rectd(seedEdit.rightOf, seedEdit.topOf, seedEdit.widthOf, seedEdit.heightOf), "Borders on climate map?",
            (bool down, bool abort) {
                if(down || abort) return;
                renderClimateBorders = !renderClimateBorders;
                redraw(false);
            }
        );
        auto voronoi_region_borders = new CheckBox(this, Rectd(climate_borders.leftOf, climate_borders.bottomOf + 0.5 * climate_borders.heightOf, climate_borders.widthOf, climate_borders.heightOf),
            "Regions borders?",
            (bool down, bool abort) {
                if(down || abort) return;
                renderRegionBorders = !renderRegionBorders;
                redraw(false);
            }
        );
        auto voronoi_region_internal_borders = new CheckBox(this, Rectd(voronoi_region_borders.leftOf, voronoi_region_borders.bottomOf, voronoi_region_borders.widthOf, voronoi_region_borders.heightOf),
            "Borders inside regions?",
            (bool down, bool abort) {
                if(down || abort) return;
                renderEveryCell = !renderEveryCell;
                redraw(false);
            }
        );
        auto voronoi_render_regions = new CheckBox(this,
            Rectd(voronoi_region_internal_borders.leftOf, voronoi_region_internal_borders.bottomOf, voronoi_region_internal_borders.widthOf, voronoi_region_internal_borders.heightOf),
            "Render regions only?",
            (bool down, bool abort) {
                if(down || abort) return;
                renderRegions = !renderRegions;
                redraw(false);
            }
        );

        auto saveWorldButton = new PushButton(this, Rectd(voronoi_region_borders.rightOf, voronoi_region_borders.topOf, voronoi_region_borders.widthOf, voronoi_region_borders.heightOf), "Save world", {
            {
                mixin(MeasureTime!("Time to save the world(All in a days work):"));
                worldMap.save();
            }
        });



        redraw(false);

    }

    override void destroy() {
        worldMap.destroy();
        super.destroy();
    }

    bool zoomImage(GuiElement e, GuiEvent.MouseClick mc) {
        if(!mc.down || !mc.left) return false;
        if(e.widthOf == 0.3) {
            if(!zoomed) {
                zoomed = true;
                oldPos = e.getRelativeRect;
                e.setRelativeRect(Rectd(clientArea.leftOf, clientArea.topOf, 0.6, 0.6));
                e.bringToFront();
            }
        } else {
            zoomed = false;
            e.setRelativeRect(oldPos);
        }
        return true;
    };

    void redraw(bool regen) {
        if(regen) {
            worldMap.destroy();
            worldMap = new WorldMap(seed);

            worldMap.generate();
            mapViz = worldMap.getVisualizer();
        }
        heightImg.setImage(mapViz.getHeightmapImage());

        temperatureImg.setImage(mapViz.getTemperatureImage());

        windImg.setImage(mapViz.getWindImage());

        moistureImg.setImage(mapViz.getMoistureImage());



        voronoiImage.clear(0, 0, 0, 0);

/*
        foreach(edge ; worldMap.areaVoronoi.poly.edges) {
            auto start = edge.getStartPoint();
            auto end = edge.getEndPoint();

            auto height1 = worldMap.heightMap.getValue(start.pos.X, start.pos.Y);
            auto height2 = worldMap.heightMap.getValue(end.pos.X, end.pos.Y);
            if(height1 <= 0 || height2 <= 0) {
                continue;
            }
            if(renderClimateBorders) {
                climateMap.drawLine(start.pos.convert!int, end.pos.convert!int, vec3i(0));
            }
            int site1 = edge.halfLeft.left.siteId;
            int site2 = edge.halfRight.left.siteId;
            if(!renderEveryCell) {
                if((worldMap.areas[site1].climateType) == (worldMap.areas[site2].climateType)) continue;
            }
            if(renderRegionBorders || renderEveryCell) {
                voronoiImage.drawLine(start.pos.convert!int, end.pos.convert!int, vec3i(0));
            }
        }
*/
        climateMapImg.setImage(mapViz.getClimateImage(climateTypes, renderClimateBorders));

        if(renderRegions) {
            voronoiImg.setImage(mapViz.getRegionImage(renderRegionBorders));
        } else {
            voronoiImg.setImage(mapViz.getAreaImage(climateTypes, renderRegionBorders, renderEveryCell));
        }



    }

    void onBack() {
        creator.setVisible(true);
        destroy();
    }    

    override void render() {
        super.render();
    }

    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            /*
            auto m = e.mouseClick;
            if (m.left && m.down) {
                size_t stop = determineCharPos(m.pos);
                startMarker = stop;
                stopMarker = stop;
                selecting = true;
            }
            //TODO: Add checking so that we pressed down inside this editbox as well.
            if (m.left && !m.down) {
                selecting = false;                
            }
            */
            msg("derp");
        }

        return super.onEvent(e);
    }
}



