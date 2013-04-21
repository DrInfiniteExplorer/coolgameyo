module gui.guisystem.scrollbar;




import std.algorithm;
import std.conv;
import std.stdio;
import std.traits;

import gui.guisystem.guisystem;
import gui.guisystem.text;

import graphics._2d.rect;
import util.util;
import util.rect;

/*

     ___
    |   |
    |   |
    |   |
    |   |
    |   |
    |   |
    |___|  <-- amountScroll  ____
    |///|                     /\
    |///|                      |
    |///|                    scrollBar
    |///|                      |
    |///| <-- totalScroll    _\/_

*/

//For now only just vertical
class GuiElementScrollBar : GuiElement {

    auto scrollWidth = 16;

    int totalScroll;
    int amountScroll;
    int scrollBar;

    this(GuiElement parent) {
        super(parent);
        onMove();
        totalScroll = 100;
        scrollBar = 50;
        amountScroll = 25;
    }    

    bool moving = false;
    override void onMove() {
        if(moving) return;
        moving = true;
        scope(exit) moving = false;
        setRelativeRect(Rectd(0,0,1,1));
        auto abs = getAbsoluteRect();
        abs.start.x += (abs.size.x - scrollWidth);
        abs.size.x = scrollWidth;
        setAbsoluteRect(abs);
        super.onMove();
    }

    override void render() {
        //Render background, etc, etc.
        renderRect(absoluteRect, vec3f(0.75, 0.75, 0.75)); //Background color
        renderOutlineRect(absoluteRect, vec3f(0.0, 0.0, 0.0));

        auto abs = absoluteRect;
        auto rect = abs;
        rect.size.y = scrollWidth;
        renderRect(rect, vec3f(0.1));
        rect.start.y += abs.size.y - scrollWidth;
        renderRect(rect, vec3f(0.1));

        int totalScrollSize = abs.size.y - 2 * scrollWidth;

        float percentScrollBar = cast(float)scrollBar / cast(float)totalScroll;
        int scrollBarHeight = cast(int)(totalScrollSize * percentScrollBar);
        auto scrollableHeight = totalScrollSize - scrollBarHeight;

        float percentScrolled = cast(float)amountScroll / cast(float)(totalScroll - scrollBar);
        int scrollBarStart = cast(int)(percentScrolled * scrollableHeight);

        rect.size.y = scrollBarHeight;
        rect.start.y = abs.start.y + scrollWidth + scrollBarStart;

        renderRect(rect.diff(3, 0, -4, 0), vec3f(0.3));



        super.render();
    }

    override GuiEventResponse onEvent(GuiEvent e) {
        /*
        if (e.type == GuiEventType.MouseClick) {
            auto m = &e.mouseClick;
            if(m.left) {
                if (m.down) {
                    if(absoluteRect.isInside(m.pos)) {
                        pushedDown = true;
                        auto fAbs = absoluteRect.convert!double;
                        auto fPos = m.pos.convert!double();
                        //TODO: Figure out why the following lines causes a compiler crash but the once above dont
                        //auto fAbs = absoluteRect.convert!float();
                        //auto fPos = m.pos.convert!float();
                        auto relative = fAbs.getRelative(fPos);
                        repositionSlider(relative.x);
                        return GuiEventResponse.Accept;
                    }                    
                } else {
                    pushedDown = false;
                    return GuiEventResponse.Accept;
                }
            }
        } else if (e.type == GuiEventType.MouseMove) {
            if (pushedDown) {
                auto m = &e.mouseMove;
                auto fAbs = absoluteRect.convert!double;
                auto fPos = m.pos.convert!double();
                auto relative = fAbs.getRelative(fPos);
                repositionSlider(relative.x);
                return GuiEventResponse.Accept;
            }
        }
        */
        return super.onEvent(e);
    }
}
