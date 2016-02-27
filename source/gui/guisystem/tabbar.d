module gui.guisystem.tabbar;

import std.exception;

import gui.all;
import cgy.util.util;
import cgy.util.rect;

class TabBar : GuiElement {

    SimpleElementButton[] buttons;

    this(T...)(GuiElement parent, Rectd pos, T t) if( (T.length % 2) == 0 ) {
        super(parent);
        setRelativeRect(pos);

        SimpleElementButton selected;

        double width = 2 * pos.widthOf / T.length;
        foreach(idx, item ; t) {
            static if( (idx % 2) == 0) {
                auto label = t[idx];
                auto cb = t[idx+1];
                double x = width * idx / 2;
                buttons ~= new SimpleElementButton(this, Rectd(x, 0, width, 1), label,
                                        (void delegate() cb) {
                                            return (SimpleElementButton b) {
                                                if(selected !is null) {
                                                    selected.setColor(b.getColor());
                                                }
                                                selected = b;
                                                b.setColor(vec3f(1, 0, 0));
                                                cb();
                                            };
                                        }(cb));
            }
        }
    }

    void select(int idx) {
        auto butt = buttons[idx];
        if(butt !is null) {
            butt.onPushed(true, false);
            butt.onPushed(false, false);
        }
    }
}



