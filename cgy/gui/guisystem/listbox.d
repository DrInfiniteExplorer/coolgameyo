

module gui.guisystem.listbox;

import std.stdio;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;
import entity;
import inventory;

class GuiElementListBox : public GuiElement {
	private struct RowItem{
		Recti rect;
		GuiElementText text;
		
		void whyyyyyyy(GuiElementListBox asdf) { // Detta ar en konstruktor
			rect = Recti();
			text = new GuiElementText(asdf, vec2d(0, 0), "");
		}
	};
    int nrOfRows;
	int rowHeight;
	RowItem[] rows;
	
	int selectedIndex;
	int nrOfItems = 0;
	
    this(GuiElement parent, Rectd relative, int _nrOfRows) {
        super(parent);
        setRelativeRect(relative);
		nrOfRows = _nrOfRows;
		rowHeight = cast(int)(absoluteRect.size.Y / nrOfRows);
		rows = new RowItem[nrOfRows];
		for (int i = 0; i < nrOfRows; i++){
			rows[i].whyyyyyyy(this);
		}
    }
    
	public void addItem(string str) {
		rows[nrOfItems].rect = Recti(absoluteRect.start.X, absoluteRect.start.Y + nrOfItems * rowHeight,
										absoluteRect.size.X, rowHeight);
		rows[nrOfItems].text = new GuiElementText(this, vec2d(0, 0), str);
		rows[nrOfItems].text.setAbsoluteRect(rows[nrOfItems].rect); 
		nrOfItems++;
	}
	
	public void removeItem(string str) {
		for (int i = 0; i < nrOfItems; i++) {
			if (rows[i].text.getText() == str) {
				for (int a = i; a < nrOfItems; a++){
					rows[a] = rows[a+1];
				}
				return;
			}
		}
	}
    
    override void render() {
        //Render background, etc, etc.
        
		renderRect(absoluteRect, vec3f(0.7, 0.7, 0.7));
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
		
		renderRect(rows[selectedIndex].rect, vec3f(0.7, 0.7, 0.9));
		for (int i = 0; i < nrOfItems; i++) {
			renderOutlineRect(rows[i].rect, vec3f(0.0, 0.0, 0.0));
		}
        
        super.render();
    }
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
						for (int i = 0; i < nrOfRows; i++) {
							if (rows[i].rect.isInside(m.pos)) {
								selectedIndex = i;
							}
						}
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    
                }
            }
        }
        return super.onEvent(e);
    }
}

class GuiElementInventoryListBox : GuiElementListBox {
	Inventory* inventory;
	
    this(GuiElement parent, Rectd relative, int _nrOfRows, Inventory* inv) {
        super(parent, relative, _nrOfRows);
        inventory = inv;
    }
	
	override void render() {
		for (int i = 0; i < rows.length && i < inventory.inventory.length; i++){
			rows[i].text.setText(inventory.inventory[i] is null ? "" : inventory.inventory[i].type.displayName);
			rows[i].rect = Recti(absoluteRect.start.X, absoluteRect.start.Y + i * rowHeight,
								 absoluteRect.size.X, rowHeight);
			rows[i].text.setAbsoluteRect(rows[i].rect); 
		}
		super.render();
	}
}