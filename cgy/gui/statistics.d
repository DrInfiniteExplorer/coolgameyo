module gui.statistics;

import std.conv;

import derelict.sdl.sdl;

import main;
import game;
import graphics._2d.rect;
import gui.all;
import gui.unitcontrol;
import gui.optionmenu;
import gui.randommenu;
import gui.newgamemenu;
import settings;
import statistics;

class StatisticsWindow : GuiElement {

    alias GuiElementSimpleGraph!(long) LongGraph;
    LongGraph geometryBuildGraph;
    LongGraph geometryUploadGraph;
    LongGraph geometryTaskGraph;

    this(GuiElement parent) {
        super(parent);
        setRelativeRect(Rectd(0,0,1,1));
        geometryBuildGraph = new LongGraph(this, Rectd(0, 0.50, 0.5, 0.15));
        geometryUploadGraph = new LongGraph(this, Rectd(0, 0.65, 0.5, 0.15));
        geometryTaskGraph = new LongGraph(this, Rectd(0, 0.80, 0.5, 0.15));
    }
    
    override void tick(float dTime) {
        geometryBuildGraph.setData(g_Statistics.getBuildGeometry());
        geometryUploadGraph.setData(g_Statistics.getGRUploadTime());
        geometryTaskGraph.setData(g_Statistics.getMakeGeometryTasks());

    }

    override void destroy() {
        super.destroy();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if(e.type == GuiEventType.FocusOn) {
                return GuiEventResponse.Reject;
        }
        return super.onEvent(e);
    }

}

     






