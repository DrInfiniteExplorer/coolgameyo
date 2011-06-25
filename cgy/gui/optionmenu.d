



module gui.optionmenu;

import std.conv;

import main;

import gui.mainmenu;
import gui.guisystem.button;
import gui.guisystem.checkbox;
import gui.guisystem.editbox;
import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.window;

import settings;

class OptionMenu : GuiElementWindow {
    GuiElement guiSystem;
    GuiElementCheckBox vsync;
    GuiElementCheckBox mipmap;
    GuiElementCheckBox wireframe;
    GuiElementCheckBox renderinvalid;
    MainMenu main;
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Options Menu~~~!", false, false);
//*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "Settings yeah!");     
        vsync = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.15), vec2d(0.3, 0.05)), "Disable vsync?", &onVsync);
        vsync.setChecked(renderSettings.disableVSync);
        
        mipmap = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.20), vec2d(0.3, 0.05)), "Interpolate mipmap levels?", &onMipmap);
        mipmap.setChecked(renderSettings.mipLevelInterpolate);

        wireframe = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.25), vec2d(0.3, 0.05)), "Render wireframe?", &onWireframe);
        wireframe.setChecked(renderSettings.renderWireframe);

        renderinvalid = new GuiElementCheckBox(this, Rectd(vec2d(0.10, 0.30), vec2d(0.3, 0.05)), "Render invalid tiles?", &onInvalid);
        renderinvalid.setChecked(renderSettings.renderInvalidTiles);
        
        new GuiElementEditbox(this, Rectd(vec2d(0.10, 0.35), vec2d(0.3, 0.05)), "Render invalid tiles?",);
        
        auto butt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.50), vec2d(0.3, 0.10)), "Back", &onBack);
        
  
        main = m;
    }
    
    override void destroy() {
        saveSettings();        
        super.destroy();
    }
    
    void onBack(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        main.setVisible(true);
        destroy();
    }    
    
    void onVsync(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        renderSettings.disableVSync = vsync.getChecked();
    }
    void onMipmap(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        renderSettings.mipLevelInterpolate = mipmap.getChecked();
    }
    void onWireframe(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        renderSettings.renderWireframe = wireframe.getChecked();
    }
    void onInvalid(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        renderSettings.renderInvalidTiles = renderinvalid.getChecked();
    }
}

     

