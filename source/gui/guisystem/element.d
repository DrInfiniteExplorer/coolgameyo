

module gui.guisystem.element;

import std.algorithm;
import std.range;
import std.conv;
import std.stdio;

import gui.guisystem.guisystem;

import graphics._2d.image;
import graphics.font;
import settings;
public import cgy.util.rect;
import cgy.math.vector : vec2d;


enum GuiEventResponse {
    Accept,
    Reject,
    Ignore
};

abstract class InputEvent
{
    double timestamp;
};

class MouseMove : InputEvent
{
    this(double a_timestamp) { timestamp = a_timestamp; }
    vec2i pos;
    vec2i delta;
    vec2i reposition;
    bool applyReposition;
};

class MouseClick : InputEvent {
    this(double a_timestamp) { timestamp = a_timestamp; }
    bool left; //Otherwise right?
    bool right; //Otherwise right?
    bool middle; //Otherwise right?

    bool down;
    vec2i pos;
};
class MouseWheel : InputEvent {
    this(double a_timestamp) { timestamp = a_timestamp; }
    float amount;
}

class KeyboardEvent : InputEvent{
    this(double a_timestamp) { timestamp = a_timestamp; }
    int SdlSym;
    int SdlMod;
    bool pressed;
    int repeat;
    char ch;
}

class FocusOffEvent : InputEvent {};
class FocusOnEvent : InputEvent {};
class HoverOffEvent : InputEvent {};
class HoverOnEvent : InputEvent {};


class GuiElement {

    alias bool delegate(GuiElement, MouseClick) MouseClickCallback;
    protected MouseClickCallback mouseClickCB;

    protected GuiSystem guiSystem;
    private GuiElement[] children;
    protected GuiElement parent;

    protected Rectd relativeRect;
    protected Recti absoluteRect;
    protected Font font;

    private bool _visible = true;
    private bool _selectable = true;
    private bool _enabled = true;
    
    this(GuiElement parent) {
        //Uh, yeah! make sure that if parent == null then we are a GuiSystem.
        if (parent) {
            setParent(parent);
            font = parent.font;        

            if (cast(GuiSystem)parent !is null) {
                guiSystem = cast(GuiSystem)parent;
            } else {
                guiSystem = parent.guiSystem;
            }
        }
    }
    
    void destroy() {
        looseFocus();
        while (children.length > 0) {
            children[0].destroy(); //Proper chilredn should remove themselfves from this array.
        }
        setParent(null);
        //Release resources
    }
    
    GuiElement getParent() {
        return parent;
    }

    GuiElement getNext() {
        if(children.length) {
            return children[0];
        }
        auto next = parent.getNextSibling(this);
        if(next !is null) {
            return next;
        }
        auto node = parent;
        while(node !is null && node.parent !is null) {
            next = node.parent.getNextSibling(node);
            if(next) return next;
            node = node.parent;
        }
        return null;
    }

    private GuiElement getNextSibling(GuiElement child) {
        foreach (idx, ch; children) {
            if (ch is child) {
                if (idx+1 == children.length) {
                    return null;
                }
                return children[idx+1];
            }
        }
        return null;
    }
    
    GuiElement getGuiSystem() {
        return guiSystem;
    }
    
    void setParent(GuiElement p) {
        if (parent) {
            parent.removeChild(this);
        }
        
        if (p) {
            p.addChild(this);
        }
    }
    
    void removeChild(GuiElement e){
        children = children.remove(countUntil(children, e));
        e.parent = null;
    }
    void addChild(GuiElement e) {
        if (e.parent) {
            e.setParent(this);
        } else {
            e.parent = this;
            children ~= e;
        }
    }
    
    void setFocus(GuiElement e)
    in {
        assert(guiSystem !is null, "Element missing guisystem; cant set focus!");
    } body {
        guiSystem.setFocus(e);
    }
    
    GuiElement getFocusElement()
    in {
        assert(guiSystem !is null, "Element missing guisystem; cant set focus!");
    } body {
        return guiSystem.getFocusElement();
    }
    
    bool hasFocus() @property {
        return this is getFocusElement();
    }

    //Note: not a OnLooseFocus but more "Relinquish focus from this element!"
    // Use GuiEvent e.type == GuiEventType.FocusOff instead
    void looseFocus() {
        foreach (child; children) {
            child.looseFocus();
        }
        if (hasFocus()) {
            setFocus(parent);
        }
    }

    void cycleFocus()
    in {
        assert(guiSystem !is null, "Element missing guisystem; cant cycle focus!");
    } body {
        return guiSystem.cycleFocus();
    }

    bool isInside(vec2i pos) {
        return absoluteRect.isInside(pos);
    }
    
    void setRelativeRect(Rectd r) {
        relativeRect = r;
        getAbsoluteRect();
        onMove();
    }
    
    void setAbsoluteRect(Recti r) {
        if (parent is null) return;

        absoluteRect = r;
        auto parentScreenRelative = parent.getScreenRelativeRect();
        
        auto screenRect = Rectd(vec2d(0,0), vec2d(renderSettings.windowWidth, renderSettings.windowHeight));
        auto screenRelative = screenRect.getSubRectInv(r.convert!double);
        relativeRect = parentScreenRelative.getSubRectInv(screenRelative);
        onMove();
    }
    
    Rectd getRelativeRect() {
        return relativeRect;
    }
    
    Rectd getScreenRelativeRect() {
        if (parent !is null) {
            auto p = parent.getScreenRelativeRect();
            return p.getSubRect(relativeRect);
        }
        return relativeRect;
    }
    
    Recti getAbsoluteRect() {
        auto screenRelative = getScreenRelativeRect();
        auto screenRect = Rectd(vec2d(0,0), vec2d(renderSettings.windowWidth, renderSettings.windowHeight));
        absoluteRect = screenRect.getSubRect(screenRelative).convert!int;
        return absoluteRect;
    }
    
    void renderBorder(int borderSize, bool fillMiddle) {
        uint topLeft =      guiSystem.imageCache.getImage("border_topleft");
        uint top =          guiSystem.imageCache.getImage("border_top");
        uint topRight =     guiSystem.imageCache.getImage("border_topright");
        uint right =        guiSystem.imageCache.getImage("border_right");
        uint bottomRight =  guiSystem.imageCache.getImage("border_bottomright");
        uint bottom =       guiSystem.imageCache.getImage("border_bottom");
        uint bottomLeft =   guiSystem.imageCache.getImage("border_bottomleft");
        uint left =         guiSystem.imageCache.getImage("border_left");

        Recti abs = getAbsoluteRect();

        vec2i borderSizeV = vec2i(borderSize);
        Recti tl = Recti(abs.topLeft,                               borderSizeV);
        Recti tr = Recti(abs.topRight    - vec2i(borderSize, 0),    borderSizeV);
        Recti br = Recti(abs.bottomRight - borderSizeV,             borderSizeV);
        Recti bl = Recti(abs.bottomLeft  - vec2i(0, borderSize),    borderSizeV);
        topLeft.renderTransparentImage(tl);
        topRight.renderTransparentImage(tr);
        bottomRight.renderTransparentImage(br);
        bottomLeft.renderTransparentImage(bl);

        Recti leftR   = Recti(tl.bottomLeft, bl.topRight   - tl.bottomLeft);
        Recti topR    = Recti(tl.topRight,   tr.bottomLeft - tl.topRight);
        Recti rightR  = Recti(tr.bottomLeft, br.topRight   - tr.bottomLeft);
        Recti bottomR = Recti(bl.topRight,   br.bottomLeft - bl.topRight);

        float horiScale = cast(float)topR.size.x / borderSize;
        float vertScale = cast(float)leftR.size.y / borderSize;

        vec2f _0 = vec2f(0.0f);
        top.renderTransparentImage(topR, Rectf(_0, vec2f(horiScale, 1.0f)));
        bottom.renderTransparentImage(bottomR, Rectf(_0, vec2f(horiScale, 1.0f)));
        left.renderTransparentImage(leftR, Rectf(_0, vec2f(1.0f, vertScale)));
        right.renderTransparentImage(rightR, Rectf(_0, vec2f(1.0f, vertScale)));

        if (fillMiddle) {
            uint middle = guiSystem.imageCache.getImage("border_middle");
            middle.renderTransparentImage(Recti(tl.bottomRight, br.topLeft - tl.bottomRight), Rectf(vec2f(0.0f), vec2f(horiScale, vertScale)));
        }



    }
    
    void render() {
        if (!isVisible) return;
        foreach (child; children) {
            if (child.isVisible) {
                child.render();
            }
        }
    }
    
    //Do things such as animating or controlling unit motion, derp etc
    void tick(float dTime) {
        foreach (child; children) {
            child.tick(dTime);
        }
    }
    
    GuiEventResponse onEvent(InputEvent e){
        if( auto m = cast(MouseClick)e) {
            if (mouseClickCB !is null) {
                if (mouseClickCB(this, m)) {
                    return GuiEventResponse.Accept;
                }
            }
        }

        return GuiEventResponse.Ignore;
    }    
    
    void onMove() {
        absoluteRect = getAbsoluteRect();
        foreach (child; children) {
            child.onMove();
        }
    }

    GuiElement getElementFromPoint(vec2i pos, bool all = false){
        if (isVisible && isInside(pos)) {
            foreach (child; retro(children)) {
                auto ret = child.getElementFromPoint(pos);
                if (ret !is null) {
                    return ret;
                }
            }
            if (all || isSelectable) {
                return this;
            }
        }
        return null;
    }
    
    void setFont(Font f) {
        font = f;
    }
    Font getFont() {
        return font;
    }
    
    // Invisibility ->
    //   Looses focus
    //   Not rendered
    //   Still ticks
    //   getElementFromPoint depends on visibility
    void setVisible(bool enable) {
        if (_visible && !enable) {
            looseFocus();
        }
        _visible = enable;
    }
    bool isVisible() const @property{
        return _visible;
    }

    // Used by buttons!
    void setEnabled(bool enable) {
        _enabled = enable;
    }
    bool isEnabled() const @property {
        return _enabled;
    }
    
    // getElementFromPoint depends on selectable!
    // cycleFocus depends on selectable!
    void setSelectable(bool v) {
        _selectable = v;
    }
    bool isSelectable() const @property {
        return _selectable;
    }
    
    void bringToFront(bool uncursive = false) { //True to bring element and all parents to front.
        setParent(parent);
        if (uncursive) {
            parent.bringToFront();
        }
    }

    void setMouseClickCallback(MouseClickCallback cb) {
        mouseClickCB = cb;
    }
    
    double rightOf() const @property { return relativeRect.rightOf(); }
    double leftOf() const @property { return relativeRect.leftOf(); }
    double topOf() const @property { return relativeRect.topOf(); }
    double bottomOf() const @property { return relativeRect.bottomOf(); }
    double widthOf() const @property { return relativeRect.widthOf(); }
    double heightOf() const @property { return relativeRect.heightOf(); }
}
