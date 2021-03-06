module gui.guisystem.combobox;

import std.stdio;
import std.exception;

import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.listbox;

import graphics._2d.rect;
import cgy.util.util;
import cgy.util.rect;

//TODO: Remake this, so that a new window is spawned when one selects, instead of hacking with sizes ;)

class GuiElementComboBox : GuiElement {
	private struct RowItem{
		Recti rect;
		GuiElementText text;
	};
    RowItem[] rows;
	
	int selectedIndex = -1; // -1 is no item selected
	int nrOfItems = 0;
    bool droppedDown = false;

    GuiElementText currentText;
    Recti droppedDownRect;
    Recti mainElementRect;
    Recti separatorRect;
    static const int separatorHeight = 2;
    int rowHeight;
    
    alias void delegate(int index) SelectionChangedCallback;
    private SelectionChangedCallback selectionChangedCallback;


    // maxDropDownLength is measured in nr of items
    this(GuiElement parent, Rectd relative, SelectionChangedCallback cb = null) {
        super(parent);
        setRelativeRect(relative);
        selectionChangedCallback = cb;
        mainElementRect = absoluteRect;
        droppedDownRect = absoluteRect;
        rowHeight = absoluteRect.size.y;
        
        currentText = new GuiElementText(this, vec2d(0, 0), "");
        currentText.setAbsoluteRect(absoluteRect);

        rows = new RowItem[0];
        onMove();
    }

    void setSelectionCallback(SelectionChangedCallback cb) {
        selectionChangedCallback = cb;  
    }

    public string getSelectedItemText() {
        if (selectedIndex == -1) return ""; // Maybe throw error instead??
        return rows[selectedIndex].text.getText();
    }
    public int getSelectedItemIndex() {
        return selectedIndex;
    }
    public string getText(int index) {
        return rows[index].text.getText();
    }

    // Returns the first occurance of text
    public int getIndex(string text) {
        for (int i = 0; i < nrOfItems; i++) {
            if (rows[i].text.getText() == text) {
                return i;
            }
        }
        return -1;
    }

    public void selectItem(string item) {
        selectItem(getIndex(item));
    }
    public void selectItem(int index) {
            selectedIndex = index;
        currentText.setText(rows[index].text.getText());
        if (selectionChangedCallback !is null) {
            selectionChangedCallback(index);
        }
    }
    public void setText(int index, string text) {
        rows[index].text.setText(text);
    }

    public void addItem(string str, int index) {
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
        updateRowTextPos(index);

        rows[index].text.setVisible(droppedDown);

        nrOfItems++;
        updateDroppedDownRect();
    }
	public void addItem(string str) {
        addItem(str, nrOfItems);
	}
    public void removeItem(int index) {
        enforce(index < nrOfItems, "ComboBox error: Tried to remove out of index");
        if (index < selectedIndex) {
            selectedIndex--;
        }
        else if (index == selectedIndex) {
            selectedIndex = -1;
        }
        for (int a = index; a < nrOfItems; a++){
            rows[a] = rows[a+1];
        }
        nrOfItems--;
        updateDroppedDownRect();
    }


    override void onMove() {
        absoluteRect = getAbsoluteRect();
        mainElementRect.start.x = absoluteRect.start.x;
        mainElementRect.start.y = absoluteRect.start.y;
        separatorRect =  Recti(mainElementRect.start.x, mainElementRect.start.y + mainElementRect.size.y,
                               mainElementRect.size.x, separatorHeight);
        updateDroppedDownRect();
        for (int i = 0; i < nrOfItems; i++) {
            updateRowTextPos(i);
        }
        super.onMove();
    }

    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.7, 0.7, 0.7));
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));
        
        if (droppedDown) {
            if (selectedIndex != -1) renderRect(rows[selectedIndex].rect, vec3f(0.7, 0.7, 0.9));
            renderRect(separatorRect, vec3f(0.3, 0.3, 0.3));
            for (int i = 0; i < nrOfItems; i++) {
                renderOutlineRect(rows[i].rect, vec3f(0.0, 0.0, 0.0));
            }
        }

        super.render();
    }

    override GuiEventResponse onEvent(InputEvent e) {
        if (auto m = cast(MouseClick)e ) {
            if(m.left) {
                if (m.down) {
                    if(mainElementRect.isInside(m.pos)) {
						setDroppedDown(!droppedDown);
                        return GuiEventResponse.Accept;
                    }
                    else if(absoluteRect.isInside(m.pos)) {
                        for (int i = 0; i < nrOfItems; i++) {
							if (rows[i].rect.isInside(m.pos)) {
                                setDroppedDown(false);
								selectItem(i);
                                return GuiEventResponse.Accept;
							}
						}
                    }
                }
            }
        }
        else if (cast(FocusOffEvent) e) {
            setDroppedDown(false);
        }
        return super.onEvent(e);
    }



    private void updateDroppedDownRect() {
        droppedDownRect = Recti(mainElementRect.start.x, mainElementRect.start.y,
                                mainElementRect.size.x, mainElementRect.size.y * (nrOfItems+1) + separatorHeight);
    }

    private void updateRowTextPos(int index) {
        rows[index].rect = Recti(mainElementRect.start.x, mainElementRect.start.y + (index+1) * rowHeight + separatorHeight,
                                 mainElementRect.size.x, rowHeight);
        rows[index].text.setAbsoluteRect(rows[index].rect); 
        /*auto buttonSize = buttonText.getSize();
        auto newTextRect = absoluteRect.centerRect(Recti(vec2i(0, 0), buttonSize));
        buttonText.setAbsoluteRect(newTextRect);*/
    }

    private void setDroppedDown(bool down) {
        droppedDown = down;
        for (int i = 0; i < nrOfItems; i++) {
            rows[i].text.setVisible(down);
        }
        setAbsoluteRect(down ? droppedDownRect : mainElementRect);
        bringToFront();
    }
}

//A bit of a hack. It relies on the fact that we use no clipping when drawing outside of our parents.
//Maybe set clipping up as a property of parents?
class GuiElementLabeledComboBox : GuiElementComboBox {
    GuiElementText label;
    this(GuiElement parent, Rectd relative, string _label, SelectionChangedCallback cb = null) {
        // ~ " " to make space between label/edit in a simpel manner xD
        label = new GuiElementText(parent, relative.start, _label ~ " ");
        auto labelRect = label.getRelativeRect();
        relative.start.x += labelRect.size.x;

        //These lines commented out because when combobox expanded it borks things.
        //label.setRelativeRect(Rectd(0,0,1,1).getSubRectInv(labelRect));
        super(parent, relative, cb);
        //label.setParent(this);
    }


}
