module gui.statistics;

import std.conv;

import derelict.sdl2.sdl;

import main;
import game;
import graphics._2d.rect;
import gui.all;
import gui.unitcontrol;
import gui.optionmenu;
import gui.random.randommenu;
import gui.newgamemenu;
import settings;
import cgy.util.statistics;
import cgy.util.util;
import cgy.util.rect;

class StatisticsWindow : GuiElement {

    alias GuiElementSimpleGraph!(long) LongGraph;
    LongGraph geometryBuildGraph;
    LongGraph geometryUploadGraph;
    LongGraph geometryTaskGraph;

    this(GuiElement parent) {
        super(parent);
        setRelativeRect(Rectd(0,0,1,1));
        geometryBuildGraph = new LongGraph(this, Rectd(0, 0.50, 0.5, 0.15), true);
        geometryUploadGraph = new LongGraph(this, Rectd(0, 0.65, 0.5, 0.15), true);
        geometryTaskGraph = new LongGraph(this, Rectd(0, 0.80, 0.5, 0.15), true);
    }
    
    override void tick(float dTime) {
        geometryBuildGraph.setData(g_Statistics.getBuildGeometry());
        geometryUploadGraph.setData(g_Statistics.getGRUploadTime());
        geometryTaskGraph.setData(g_Statistics.getMakeGeometryTasks());

    }

    override void destroy() {
        super.destroy();
    }
    
    override GuiEventResponse onEvent(InputEvent e) {
        if(cast(FocusOnEvent) e) {
                return GuiEventResponse.Reject;
        }
        return super.onEvent(e);
    }

}

     






