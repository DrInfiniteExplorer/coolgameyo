module gui.guisystem.combobox;

import std.stdio;
import std.exception;

import gui.guisystem.guisystem;
import gui.guisystem.text;
import gui.guisystem.listbox;

import graphics._2d.rect;
import util.util;
import util.rect;

class GuiElementComboBox : public GuiElement {
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
    const int separatorHeight = 2;
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
        rowHeight = absoluteRect.size.Y;
        
        currentText = new GuiElementText(this, vec2d(0, 0), "");
        currentText.setAbsoluteRect(absoluteRect);

        rows = new RowItem[0];
        onMove();
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
        if (nrOfItems == rows.length) rows.length = rows.length + 1;
        
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
        if (index < selectedIndex) selectedIndex--;
        else if (index == selectedIndex) selectedIndex = -1;
        for (int a = index; a < nrOfItems; a++){
            rows[a] = rows[a+1];
        }
        nrOfItems--;
        updateDroppedDownRect();
    }


    override void onMove() {
        absoluteRect = getAbsoluteRect();
        mainElementRect.start.X = absoluteRect.start.X;
        mainElementRect.start.Y = absoluteRect.start.Y;
        separatorRect =  Recti(mainElementRect.start.X, mainElementRect.start.Y + mainElementRect.size.Y,
                               mainElementRect.size.X, separatorHeight);
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

    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(mainElementRect.isInside(m.pos)) {
						setDroppedDown(!droppedDown);
                        return GuiEventResponse.Accept;
                    }
                    else if(absoluteRect.isInside(m.pos)) {
                        for (int i = 0; i < nrOfItems; i++) {
							if (rows[i].rect.isInside(m.pos)) {
								selectItem(i);
                                setDroppedDown(false);
                                return GuiEventResponse.Accept;
							}
						}
                    }
                } else {

                }
            }
        }
        else if (e.type == GuiEventType.FocusOff) {
            setDroppedDown(false);
        }
        return super.onEvent(e);
    }



    private void updateDroppedDownRect() {
        droppedDownRect = Recti(mainElementRect.start.X, mainElementRect.start.Y,
                                mainElementRect.size.X, mainElementRect.size.Y * (nrOfItems+1) + separatorHeight);
    }

    private void updateRowTextPos(int index) {
        rows[index].rect = Recti(mainElementRect.start.X, mainElementRect.start.Y + (index+1) * rowHeight + separatorHeight,
                                 mainElementRect.size.X, rowHeight);
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
    }
}