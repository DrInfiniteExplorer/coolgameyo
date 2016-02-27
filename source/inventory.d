
module inventory;

import std.exception;
import std.stdio;

import gui.guisystem.listbox;
import cgy.json;
import cgy.util.util;
import worldstate.worldstate;
import clan;
import entities.entity;

class Inventory {
	Entity[] inventory;
    GuiElementListBox *listBox;
	
	this(){
		inventory.length = 5;
	}
	
	void addToInventory(Entity entity, int quantity=1) {
		int i = 0;
		while (i < inventory.length && !(inventory[i] is null)) {
			i++;
		}
        if (inventory[i] is null) {
		    if (i == inventory.length-1){
			    inventory.length += 5;
		    }
		    inventory[i] = entity;
		
            if (listBox !is null) {
                listBox.addItem(entity.type.displayName, i);
            }
        }
        else {
            assert(0, "To implement later. The entity should stay in its previous container (inventory/sector)");
        }
	}
}


