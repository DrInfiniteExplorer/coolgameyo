

module gui.loadscreen;

import gui.all;

class LoadScreen : GuiElementWindow {
    GuiSystem guiSystem;
    
    GuiElementProgressBar loading;

    this(GuiSystem g) {
        guiSystem = g;
        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), "Loading screen~~~!", false, false);

        loading = new GuiElementProgressBar(this, Rectd(0.1, 0.3, 0.8, 0.1), "Loading", 100, 0);
    }
    
    override void destroy() {        
        super.destroy();        
    }    
        

}

     
