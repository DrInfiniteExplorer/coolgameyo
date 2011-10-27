module gui.inventorywindow;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import main;
import gui.mainmenu;
import gui.all;
import graphics.image;

import gui.unitcontrol;

import worldparts.sizes;
import worldparts.block;
import worldparts.sector;
import random.random;
import pos;
import settings;
import statistics;
import util.util;
import util.rect;
import entity;
import inventory;

class InventoryWindow : GuiElementWindow {
    GuiSystem guiSystem;
    HyperUnitControlInterfaceInputManager ofDOOM;
	GuiElementListBox listBox;
	
    this(GuiSystem g, HyperUnitControlInterfaceInputManager DOOM, Inventory* inventory) {
        guiSystem = g;
		ofDOOM = DOOM;
        super(guiSystem, Rectd(vec2d(0.25, 0.25), vec2d(0.5, 0.5)), "Inventory window~~~!", true, true);
		
		
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.9), vec2d(0.2, 0.10)), "Back", &onBack);
		listBox = new GuiElementInventoryListBox(this, Rectd(vec2d(0.0, 0.0), vec2d(1.0, 0.80)), 5, inventory);
		//listBox.addItem("First!");
		//listBox.addItem("Wololoo");
        setVisible(false);
    }
    
	void onOpenInventory() {
		if (getVisible()){
			setVisible(false);
			guiSystem.setEventDump(ofDOOM);
		}
		else{
			setVisible(true);
			guiSystem.setEventDump(null);
		}
	}
	
	override void onWindowClose() {
		onBack();
	}
	
    void onBack() {
		setVisible(false);
		guiSystem.setEventDump(ofDOOM);
    }
     
        
}

     

