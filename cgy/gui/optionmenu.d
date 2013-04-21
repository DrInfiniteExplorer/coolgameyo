



module gui.optionmenu;

import std.conv;
import core.cpuid;

import main;

import gui.mainmenu;
import gui.guisystem.button;
import gui.guisystem.checkbox;
import gui.guisystem.editbox;
import gui.guisystem.guisystem;
import gui.guisystem.slider;
import gui.guisystem.text;
import gui.guisystem.window;
import gui.guisystem.combobox;

import graphics.ogl;

import settings;
import util.util;
import util.rect;

class OptionMenu : GuiElementWindow {
    GuiElement guiSystem;
    CheckBox vsync;
    CheckBox mipmap;
    CheckBox wireframe;
    CheckBox renderinvalid;
    GuiElementSlider!float sensX, sensY;
    GuiElementComboBox smoothSetting;
    GuiElementComboBox raycastSetting;

    GuiElementSlider!int maxThreads;


    MainMenu main;
    this(MainMenu m) {
        main = m;
        guiSystem = m.getGuiSystem();
        
        super(guiSystem, Rectd(vec2d(0.1, 0.1), vec2d(0.8, 0.8)), "Options Menu~~~!", false, false);
//*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "Settings yeah!");     
        vsync = new CheckBox(this, Rectd(vec2d(0.10, 0.15), vec2d(0.3, 0.05)), "Enable vsync?", &onVsync);
        vsync.setChecked(renderSettings.enableVSync);
        
        mipmap = new CheckBox(this, Rectd(vec2d(0.10, 0.20), vec2d(0.3, 0.05)), "Interpolate mipmap levels?", &onMipmap);
        mipmap.setChecked(renderSettings.mipLevelInterpolate);

        wireframe = new CheckBox(this, Rectd(vec2d(0.10, 0.25), vec2d(0.3, 0.05)), "Render wireframe?", &onWireframe);
        wireframe.setChecked(renderSettings.renderWireframe);

        renderinvalid = new CheckBox(this, Rectd(vec2d(0.10, 0.30), vec2d(0.3, 0.05)), "Render invalid tiles?", &onInvalid);
        renderinvalid.setChecked(renderSettings.renderInvalidTiles);
        
        sensX = new GuiElementSlider!float(this, Rectd(vec2d(0.10, 0.40), vec2d(0.3, 0.05)), controlSettings.mouseSensitivityX, 0.25, 5.0, &onMouseX);
        sensY = new GuiElementSlider!float(this, Rectd(vec2d(0.10, 0.45), vec2d(0.3, 0.05)), controlSettings.mouseSensitivityY, 0.25, 5.0, &onMouseY);

        maxThreads = new typeof(maxThreads)(this, Rectd(vec2d(sensY.rightOf + 0.025, 0.45), vec2d(0.3, 0.05)), g_maxThreadCount, 1, core.cpuid.threadsPerCPU, &onMaxThread);
        
        // Was only to test out the gui element
        //new GuiElementEditbox(this, Rectd(vec2d(0.10, 0.35), vec2d(0.3, 0.05)), "Render invalid tiles?",);

        auto smoothText = new GuiElementText(this, vec2d(0.1, sensY.bottomOf+0.05), "Shading style");
        smoothSetting = new GuiElementComboBox(this, Rectd(smoothText.rightOf+0.05, sensY.bottomOf+0.05, 0.3, 0.05), &onSmoothChange);
        smoothSetting.addItem("Flat shading");
        smoothSetting.addItem("Smooth shading");
        smoothSetting.addItem("Plol shading");
        smoothSetting.selectItem(renderSettings.smoothSetting);

        auto raycastText = new GuiElementText(this, vec2d(0.1, smoothSetting.bottomOf+0.05), "Raycast every # of pixels");
        raycastSetting = new GuiElementComboBox(this, Rectd(raycastText.rightOf+0.05, smoothSetting.bottomOf+0.05, 0.3, 0.05), &onRayCastChange);
        raycastSetting.addItem("0");
        raycastSetting.addItem("1");
        raycastSetting.addItem("2");
        raycastSetting.addItem("3");
        raycastSetting.addItem("4");
        raycastSetting.addItem("5");
        raycastSetting.selectItem(renderSettings.raycastPixelSkip);

        auto resolutionText = new GuiElementText(this, vec2d(raycastText.leftOf, raycastSetting.bottomOf+0.05), "Resolution");
        raycastSetting = new GuiElementComboBox(this, Rectd(resolutionText.rightOf+0.05, resolutionText.topOf, 0.3, 0.05), &onResolutionChange);
        raycastSetting.addItem("800x600");
        raycastSetting.addItem("1400x900");
        raycastSetting.selectItem(renderSettings.windowWidth == 800 ? 0 : 1);




        auto butt = new PushButton(this, Rectd(vec2d(0.1, raycastSetting.bottomOf + 0.05), vec2d(0.3, 0.10)), "Back", &onBack);
        
        smoothSetting.bringToFront;
  
        main = m;
    }
    
    override void destroy() {
        saveSettings();        
        super.destroy();
    }
    
    void onBack() {
        main.setVisible(true);
        destroy();
    }    
    
    void onVsync(bool down, bool abort) {
        if(down || abort) {
            return;
        }
        auto val = vsync.getChecked();
        renderSettings.enableVSync = val;
        enableVSync(val);
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
    void onMouseX(float x) {
        controlSettings.mouseSensitivityX = x;
    }
    void onMouseY(float y) {
        controlSettings.mouseSensitivityY = y;
    }
    void onMaxThread(int y) {
        g_maxThreadCount = y;
    }

    void onSmoothChange(int selectedIndex) {
        renderSettings.smoothSetting = selectedIndex;
    }

    void onRayCastChange(int selectedIndex) {
        renderSettings.raycastPixelSkip = selectedIndex;
    }

	void onResolutionChange(int selectedIndex) {
		bool changed = false;
        if(selectedIndex == 0) {
			changed = renderSettings.windowWidth != 800;
			renderSettings.windowWidth = 800;
			renderSettings.windowHeight = 600;
		} else {
			changed = renderSettings.windowWidth == 800;
			renderSettings.windowWidth = 1400;
			renderSettings.windowHeight = 900;
		} 
		saveSettings();
		if(changed) RestartCoolGameYo();
    }

    
}

     

