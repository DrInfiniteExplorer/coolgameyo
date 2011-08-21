

module gui.loadscreen;

import gui.all;
import statistics;

class LoadScreen : GuiElementWindow {
    GuiSystem guiSystem;
    
    bool showLoading;
    GuiElementProgressBar heightMaps;
    GuiElementProgressBar graphRegions;
    GuiElementProgressBar floodFill;
    GuiElementProgressBar loadSave;

    this(GuiSystem g) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "Loading screen~~~!", false, false);

        heightMaps = new GuiElementProgressBar(guiSystem, Rectd(0.1, 0.0, 0.8, 0.05), "Generating heightmaps", 100, 0);        
        graphRegions = new GuiElementProgressBar(guiSystem, Rectd(0.1, 0.1, 0.8, 0.05), "Building geometry", 100, 0);        
        floodFill = new GuiElementProgressBar(guiSystem, Rectd(0.1, 0.2, 0.8, 0.05), "Floodfilling..", 100, 0);        
        loadSave = new GuiElementProgressBar(guiSystem, Rectd(0.1, 0.2, 0.8, 0.05), "..", 100, 0);        
        
        showLoading = false;
        setSelectable(false);
    }
    
    void setLoading(bool val) {
        showLoading = val;
    }
    
    override void tick(float dTime) {
        auto todo = g_Statistics.HeightmapsToDo;
        heightMaps.setVisible(todo != 0);
        heightMaps.setMax(todo);
        heightMaps.setProgress(g_Statistics.HeightmapsDone);

        todo = g_Statistics.GraphRegionsToDo;
        graphRegions.setVisible(todo != 0);
        graphRegions.setMax(todo);
        graphRegions.setProgress(g_Statistics.GraphRegionsDone);

        todo = g_Statistics.FloodFillToDo;
        floodFill.setVisible(todo != 0);
        floodFill.setMax(todo);
        floodFill.setProgress(g_Statistics.FloodFillDone);
        
        todo = g_Statistics.SaveGameToDo;
        if(todo != 0) { loadSave.setTitle("Saving.."); }
        loadSave.setVisible(todo != 0);
        loadSave.setMax(todo);
        loadSave.setProgress(g_Statistics.SaveGameDone);

        todo = g_Statistics.LoadGameToDo;
        if(todo != 0) { loadSave.setTitle("Loading.."); }
        loadSave.setVisible(todo != 0);
        loadSave.setMax(todo);
        loadSave.setProgress(g_Statistics.LoadGameDone);

        super.tick(dTime);
    }

/*    
    override GuiEventResponse onEvent(GuiEvent e){
        if (e.type == GuiEventType.FocusOn) {
            return GuiEventResponse.Reject;
        }
        return super.onEvent(e);
    }
*/    
    
    override void render() {
        if (showLoading) {
            super.render();
        }
    }
    
    override void destroy() {
        super.destroy();        
    }    
        

}

     
