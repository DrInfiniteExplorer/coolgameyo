module gui.guisystem.listbox;

import std.stdio;
import std.exception;

import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.scrollbar;

import graphics._2d.rect;
import util.util;
import util.rect;
import inventory;

class GuiElementListBox : public GuiElement {

	int selectedIndex = -1; // -1 is no item selected
    string[] items;
    int rowHeight;

    int scrollAmount = 0;
    int canScrollAmount = 0;

	GuiElementText text;
    GuiElementScrollBar scrollBar;

    alias void delegate(int index) SelectionChangedCallback;
    private SelectionChangedCallback selectionChangedCallback;

    alias void delegate(int index) DoubleClickCallback;

    private DoubleClickCallback doubleClickCallback;


    this(GuiElement parent, Rectd relative, int _rowHeight, SelectionChangedCallback cb = null) {
        super(parent);
        setRelativeRect(relative);
        selectionChangedCallback = cb;
		rowHeight = _rowHeight;
        text = new GuiElementText(this, vec2d(0, 0), "");
        text.setVisible(false); //Manual rendering
        scrollBar = new GuiElementScrollBar(this);
        scrollBar.setVisible(false);
    }



    string getSelectedItemText() {
        if (selectedIndex == -1) return ""; // Maybe throw error instead??
        return items[selectedIndex];
    }
    int getSelectedItemIndex() {
        return selectedIndex;
    }
    string getItemText(int index) {
        if(index >= items.length || index < 0) {
            msg("Trying to get item text for non existant index derp");
            return null;
        }
        return items[index];
    }
    void selectAny() {
        if(items.length) {
            selectItem(0);
        }
    }

    // Returns the first occurance of text
    int getIndex(string text) {
        foreach(idx, str ; items) {
            if(str == text) return idx;
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
        items[index] = text;
    }

    int addItem(string str, int index) {
        if(index < 0) {
            index = items.length;
        }
        if (index > items.length) {
            index = items.length;
        }
        if (index == items.length) {
            items.length += 1;
        }

        for (int i = items.length-1; i > index; i--) {
            items[i] = items[i-1];
        }

        items[index] = str;
        updateScroll();
        return index;
    }
	int addItem(string str) {
        return addItem(str, -1);
	}
    void removeItem(string item) {
        removeItem(getIndex(item));
    }
    void removeItem(int index) {
            enforce(index < items.length, "ListBox error: Tried to remove out of index");
        if (index < selectedIndex) {
            selectedIndex--;
        }
        else if (index == selectedIndex) {
            selectedIndex = -1;
        }
        for (int a = index; a+1 < items.length; a++){
            items[a] = items[a+1];
        }
        items.length -= 1;
        updateScroll();
    }

    void clear() {
        items.length = 0;
        updateScroll();
    }

    int getItemCount() const {
        return items.length;
    }
    
    void setDoubleClickCallback(DoubleClickCallback cb) {
        doubleClickCallback = cb;
    }

    void updateScroll() {
        auto height = getAbsoluteRect.size.Y;
        auto neededHeight = items.length * rowHeight;
        import std.algorithm : max;
        canScrollAmount = max(0, neededHeight - height);
        if(canScrollAmount) {
            msg("Make code to scroll so the selected item is in view");
            scrollBar.setVisible(true);
            scrollBar.amountScroll = 0;
            scrollBar.totalScroll = items.length;
            scrollBar.scrollBar = absoluteRect.size.Y / rowHeight;
        } else {
            scrollAmount = 0;
            scrollBar.setVisible(false);
        }
    }

    override void render() {
        //Render background, etc, etc.
        
		renderRect(absoluteRect, vec3f(0.7, 0.7, 0.7));
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
		
        if (selectedIndex != -1) {
        }
        auto height = getAbsoluteRect.size.Y;
		foreach(idx, item ; items) {
            auto rect = getTextRect(idx);
            auto pos = rect.start;
            auto relativeHeight = pos.Y - absoluteRect.start.Y;
            if(relativeHeight < 0) {
                //msg("Culled for being to early");
                continue;
            }
            if(relativeHeight + rowHeight > height) {
                //msg("Culled for being to late");
                continue;
            }
            if(idx == selectedIndex) {
                renderRect(rect, vec3f(0.7, 0.7, 0.9));
            }
            text.setPosition(pos);
            text.setText(items[idx]);
            text.render();
            renderOutlineRect(rect, vec3f(0));
		}
        
        super.render();
    }
    
    double lastClickTime = -double.max;
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left && m.down) {
                if(absoluteRect.isInside(m.pos)) {
					foreach(idx, item ; items) {
						if (getTextRect(idx).isInside(m.pos)) {
                            if(selectedIndex == idx && 
                                (e.eventTimeStamp - lastClickTime) < getDoubleClickTime() &&
                                doubleClickCallback !is null) {
                                    doubleClickCallback(selectedIndex);
                            } else {
    							selectItem(idx);
                            }
						}
					}
                    lastClickTime = e.eventTimeStamp;

                    return GuiEventResponse.Accept;
                }                    
            } else if((m.wheelUp || m.wheelDown) && canScrollAmount) {
                import std.algorithm : min, max;
                auto wheelAmount = 4 * rowHeight;
                scrollAmount -= (m.wheelUp ? wheelAmount : -wheelAmount);
                scrollAmount = max(0, min(canScrollAmount, scrollAmount));
                scrollBar.amountScroll = scrollAmount / rowHeight;
            }
        }
        return super.onEvent(e);
    }

    private Recti getTextRect(int idx) {
        return Recti(absoluteRect.start.X, absoluteRect.start.Y + idx * rowHeight - scrollAmount,
                     absoluteRect.size.X, rowHeight);
    }
}
