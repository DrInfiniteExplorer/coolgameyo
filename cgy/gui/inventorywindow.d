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

import world.sizes;
import world.block;
import world.sector;
import random.random;
import pos;
import settings;
import statistics;
import util.util;
import util.rect;
import entities.entity;
import inventory;

class InventoryWindow : GuiElementWindow {
    GuiSystem guiSystem;
    HyperUnitControlInterfaceInputManager ofDOOM;
	GuiElementListBox listBox;
    GuiElementComboBox comboBox;
	
    this(GuiSystem g, HyperUnitControlInterfaceInputManager DOOM, Inventory* inventory) {
        guiSystem = g;
		ofDOOM = DOOM;
        super(guiSystem, Rectd(vec2d(0.25, 0.25), vec2d(0.5, 0.5)), "Inventory window~~~!", true, true);
		
		
        new GuiElementButton(this, Rectd(vec2d(0.75, 0.9), vec2d(0.2, 0.10)), "Back", &onBack);
		listBox = new GuiElementListBox(this, Rectd(vec2d(0.5, 0.0), vec2d(0.5, 0.80)), 30);
        inventory.listBox = &listBox;

        comboBox = new GuiElementComboBox(this, Rectd(vec2d(0.1, 0.1), vec2d(0.3, 0.09)));
        comboBox.addItem("Item 1");
        comboBox.addItem("Ett till");
        comboBox.addItem("Wololooo");
        comboBox.addItem("Sista");
        comboBox.addItem("First!", 0);

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

     

