module gui.guisystem.listbox;

import std.stdio;
import std.exception;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;
import inventory;

class GuiElementListBox : public GuiElement {

	private struct RowItem{
		Recti rect;
		GuiElementText text;
	};
	RowItem[] rows;
	
	int selectedIndex = -1; // -1 is no item selected
	int nrOfItems = 0;
    int rowHeight;

    alias void delegate(int index) SelectionChangedCallback;
    private SelectionChangedCallback selectionChangedCallback;

    alias void delegate(int index) DoubleClickCallback;

    private DoubleClickCallback doubleClickCallback;


    this(GuiElement parent, Rectd relative, int _rowHeight, SelectionChangedCallback cb = null) {
        super(parent);
        setRelativeRect(relative);
        selectionChangedCallback = cb;
		rowHeight = _rowHeight;
		rows = new RowItem[0];
    }



    string getSelectedItemText() {
        if (selectedIndex == -1) return ""; // Maybe throw error instead??
        return rows[selectedIndex].text.getText();
    }
    int getSelectedItemIndex() {
        return selectedIndex;
    }
    string getItemText(int index) {
        return rows[index].text.getText();
    }

    // Returns the first occurance of text
    int getIndex(string text) {
        for (int i = 0; i < nrOfItems; i++) {
            if (rows[i].text.getText() == text) {
                return i;
            }
        }
        return -1;
    }

    void selectItem(int index) {
        selectedIndex = index;
        if (selectionChangedCallback !is null) {
            selectionChangedCallback(index);
        }
    }
    void setText(string text, int index) {
        rows[index].text.setText(text);
    }

    void addItem(string str, int index) {
        if(index < 0) {
            index = nrOfItems;
        }
        if (index > nrOfItems) {
            index = nrOfItems;
        }
        if (nrOfItems == rows.length) {
            rows.length += 1;
        }

        for (int i = nrOfItems; i > index; i--) {
            rows[i] = rows[i-1];
        }

        rows[index].text = new GuiElementText(this, vec2d(0, 0), str);
        nrOfItems++;
        foreach(idx ; index .. nrOfItems) {
            updateRowTextPos(idx);
        }
    }
	void addItem(string str) {
        addItem(str, nrOfItems);
	}
    void removeItem(int index) {
        enforce(index < nrOfItems, "ListBox error: Tried to remove out of index");
        if (index < selectedIndex) {
            selectedIndex--;
        }
        else if (index == selectedIndex) {
            selectedIndex = -1;
        }
        rows[index].text.destroy();
        nrOfItems--;
        for (int a = index; a < nrOfItems; a++){
            rows[a] = rows[a+1];
            updateRowTextPos(a);
        }
    }

    void clear() {
        while(nrOfItems != 0) {
            removeItem(nrOfItems-1);
        }
    }

    int getItemCount() const {
        return nrOfItems;
    }
    
    void setDoubleClickCallback(DoubleClickCallback cb) {
        doubleClickCallback = cb;
    }



    override void render() {
        //Render background, etc, etc.
        
		renderRect(absoluteRect, vec3f(0.7, 0.7, 0.7));
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
		
        if (selectedIndex != -1) renderRect(rows[selectedIndex].rect, vec3f(0.7, 0.7, 0.9));
		for (int i = 0; i < nrOfItems; i++) {
			renderOutlineRect(rows[i].rect, vec3f(0.0, 0.0, 0.0));
		}
        
        super.render();
    }
    
    double lastClickTime = -double.max;
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
						for (int i = 0; i < nrOfItems; i++) {
							if (rows[i].rect.isInside(m.pos)) {
                                if(selectedIndex == i && 
                                   e.eventTimeStamp - lastClickTime < getDoubleClickTime() &&
                                   doubleClickCallback !is null) {
                                            doubleClickCallback(selectedIndex);
                                } else {
    								selectItem(i);
                                }
							}
						}
                        lastClickTime = e.eventTimeStamp;

                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    //Released mouse
                }
            }
        }
        return super.onEvent(e);
    }

    private void updateRowTextPos(int index) {
        rows[index].rect = Recti(absoluteRect.start.X, absoluteRect.start.Y + index * rowHeight,
                                 absoluteRect.size.X, rowHeight);
        rows[index].text.setAbsoluteRect(rows[index].rect); 
    }
}
