
module inventory;

import std.exception;
import std.stdio;

import json;
import util.util;
import world;
import clan;
import entity;

class Inventory {
	Entity[] inventory;
	
	this(){
		inventory.length = 5;
	}
	
	void addToInventory(Entity entity, int quantity=1) {
		int i = 0;
		while (i < inventory.length && !(inventory[i] is null)) {
			i++;
		}
		if (i == inventory.length){
			inventory.length += 5;
		}
		inventory[i] = entity;
		Entity[] inventorya = inventory;
	}
}


