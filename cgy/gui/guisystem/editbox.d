
module gui.guisystem.editbox;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;

//TODO: Make this a public import in some gui-module.
import derelict.sdl.sdl;


import graphics._2d.rect;
import graphics.font;
import gui.guisystem.guisystem;
import gui.guisystem.text;
import util.util;
import util.rect;



class GuiElementEditbox : public GuiElement {
    alias bool delegate(char ch) ValidCharFilter;
    void delegate(string) onEnter; //When enter is pressed.
    ValidCharFilter filter; //Return true to allow!
    
    int startMarker, stopMarker;
    size_t maxLength;
    string content;
    StringTexture text;
    bool password;
    this(GuiElement parent) {
        super(parent);
    }
    this(GuiElement parent, Rectd relative, string str)
    in{
        enforce(parent !is null, "Cant use this constructor without a parent!");
        enforce(parent.getFont() !is null, "Cant use this constructor if parent doesnt have a font!");
    }
    body{        
        super(parent);
        setRelativeRect(relative);
        setText(str);
        filter = &filterNone;
    }
    
    override void destroy() {
        super.destroy();
        text.destroy();
    }

    void setOnEnter(void delegate(string) cb) {
        onEnter = cb;
    }

    void setPassword(bool pass) {
        password = pass;
        setText(content);
    }
    
    void setNumbersOnly(bool enable) {
        if (enable) {
            filter = &filterNumber;
        } else {
            filter = null;
        }
    }
    
    void setMaxLength(size_t max) {
        maxLength = max;
    }
    
    bool filterNone(char ch) {
        return true;
    }
    bool filterNumber(char ch) {
        return -1 != std.string.indexOf(digits, ch);
    }
    
    string getText() {
        return content;
    }
        
    void setText(string str) {
        content = str;
        if (text is null) {
            text = new StringTexture(font);
            text.setTransparent(true);
        }
        if (password) {
            str = "*".replicate(str.length);
            text.setText(str);
        } else {
            text.setText(str);
        }
    }
    
    int getPixelFromPos(size_t pos) {
        vec2i charSize = font.glyphSize();
        return 2 + pos * charSize.x;
    }
    size_t determineCharPos(vec2i pos) {
        vec2i relative = pos - absoluteRect.start - 2;
        vec2i charSize = font.glyphSize();
        relative.x += charSize.x / 2;
        int slot = relative.x / charSize.x;
        return max(0, min(slot, content.length));
    }    
    
    override void render(){
        renderRect(absoluteRect, vec3f(1, 1, 1));
        renderOutlineRect(absoluteRect, vec3f(0, 0, 0));
        auto inner = absoluteRect.diff(vec2i(2, 2), vec2i(-2, -2));
        
        auto markerColor = vec3f(0.5, 0.5, 0.5);
        //Render marking
        if (startMarker != stopMarker) {
            //markerColor = vec3f(0.0, 0.0, 0.0);
            auto start = startMarker;
            auto stop = stopMarker;
            if (start > stop) {
                swap(start, stop);
            }
            auto marked = absoluteRect.diff(vec2i(0, 2), vec2i(0, -2));
            auto dx = getPixelFromPos(start);
            marked.start.x += dx;
            marked.size.x = getPixelFromPos(stop)-dx;    
            
            renderRect(marked, hasFocus ?   vec3f(0.25, 0.25, 0.75) :
                                            vec3f(0.5, 0.5, 0.5) );
            //Figure out how to translate this to a rect :)
        }
        text.render(inner);
        if (hasFocus) {
            auto dx = getPixelFromPos(startMarker);
            auto mark = absoluteRect.diff(vec2i(dx, 3), vec2i(0,-3));
            mark.size.x = 1;
            renderRect(mark, markerColor);
        }
        
        super.render();
    }
        
    GuiEventResponse handleChar(int sdlSym, char ch) {

        if( (sdlSym == SDLK_RETURN) && onEnter !is null) {
            onEnter(content);
            return GuiEventResponse.Accept;
        }
        if( sdlSym == SDLK_TAB) {
            cycleFocus();
            return GuiEventResponse.Accept;
        }

        bool delet = (sdlSym == SDLK_DELETE);
        bool erase = (ch == 8) || (sdlSym == SDLK_BACKSPACE);
        bool insert = (ch != 0) && !erase && !delet && filter(ch);
        if (maxLength != 0) {
            insert = insert && content.length < maxLength;
        }
        
        if (!erase && !insert && !delet) {
            return GuiEventResponse.Ignore;
        }
        if (startMarker != stopMarker) {
            //Delete range between
            if (startMarker > stopMarker) {
                swap(startMarker, stopMarker);
            }
            content.replaceInPlace(startMarker, stopMarker, "");
            //setText(content[0 .. startMarker] ~ content[stopMarker .. $-1]);
            setText(content);
            if(!insert) {
                stopMarker = startMarker;
                return GuiEventResponse.Accept;
            }
        }
        if (delet && startMarker < content.length) {
            content.replaceInPlace(startMarker, startMarker+1, "");
        }
        if (erase && startMarker != 0) {
            content.replaceInPlace(startMarker-1, startMarker, "");
            startMarker--;
        }
        if (insert) {
            insertInPlace(content, startMarker, cast(immutable(char))ch);
            startMarker++;
        }
        stopMarker = startMarker;
        setText(content);
        return GuiEventResponse.Accept;
    }
    
    
    bool handleMove(int sdlSym, int sdlMod) {        
        bool moved;
        if (sdlSym == SDLK_RIGHT) {
            if (sdlMod & KMOD_CTRL) {
                bool inWhitespace, foundWhitespace;
                foreach(pos ; startMarker .. content.length) {
                    auto ch = content[pos];
                    startMarker = pos+1;
                    inWhitespace = -1 != std.string.indexOf(std.string.whitespace, ch);
                    if(inWhitespace){ foundWhitespace = true; }
                    if(foundWhitespace && !inWhitespace) {
                        startMarker = pos;
                        break;
                    }
                }
            } else {
                startMarker = min(content.length, startMarker+1);
            }
            moved = true;
        } else if (sdlSym == SDLK_LEFT) {
            if (sdlMod & KMOD_CTRL) {
                bool inWhitespace, foundText;
                auto tmp = startMarker;   
                foreach(i ; 0 .. tmp) {
                    auto pos = tmp-i-1;
                    msg(i, " ",tmp, " ", pos);
                    auto ch = content[pos];
                    startMarker = pos;
                    inWhitespace = -1 != std.string.indexOf(std.string.whitespace, ch);
                    if(!inWhitespace){ foundText = true; }
                    if(foundText && inWhitespace) {
                        startMarker = pos+1;
                        break;
                    }
                }
            } else {
                startMarker = max(0, startMarker-1);
                writeln(startMarker);
            }
            moved = true;
        } else if (sdlSym == SDLK_HOME || (sdlSym == SDLK_KP7 && !(sdlMod & KMOD_NUM))) {
            startMarker = 0;
            moved = true;
        } else if (sdlSym == SDLK_END || (sdlSym == SDLK_KP1 && !(sdlMod & KMOD_NUM))) {
            startMarker = content.length;
            moved = true;
        }
        if (moved && !(sdlMod & KMOD_SHIFT)) {
            stopMarker = startMarker;
        }
        
        if (sdlSym == SDLK_x && sdlMod & KMOD_CTRL){
            if (startMarker != stopMarker) {
                auto start = min(startMarker, stopMarker);
                auto stop = max(startMarker, stopMarker);
                setCopyString(content[start .. stop]);
                handleChar(SDLK_DELETE, 0);
            }
            return true;
        }
        if (sdlSym == SDLK_c && sdlMod & KMOD_CTRL){
            if (startMarker != stopMarker) {
                auto start = min(startMarker, stopMarker);
                auto stop = max(startMarker, stopMarker);
                setCopyString(content[start .. stop]);
            }
            return true;
        }
        if (sdlSym == SDLK_v && sdlMod & KMOD_CTRL) {
            string str;
            if (getCopyString(str)){
                if (startMarker != stopMarker) {
                    handleChar(SDLK_DELETE, 0);
                }
                foreach(ch ; str) {
                    handleChar(0, ch);
                }
            }           
            return true;
        }
        if (sdlSym == SDLK_a && sdlMod & KMOD_CTRL) {
            startMarker = content.length;
            stopMarker = 0;
            return true;
        }
        return false;
    }
        
    private bool selecting;
    
    override GuiEventResponse onEvent(GuiEvent e) {
        if (e.type == GuiEventType.Keyboard) {
            auto kb = e.keyboardEvent;
            if (kb.pressed) {
                //Also handles ctrl+c etc
                if(handleMove(kb.SdlSym, kb.SdlMod)) {
                    return GuiEventResponse.Accept;
                }
                return handleChar(kb.SdlSym, kb.ch);
                
            }
        }
        if (e.type == GuiEventType.MouseClick) {
            auto m = e.mouseClick;
            if (m.left && m.down) {
                size_t stop = determineCharPos(m.pos);
                startMarker = stop;
                stopMarker = stop;
                selecting = true;
            }
            //TODO: Add checking so that we pressed down inside this editbox as well.
            if (m.left && !m.down) {
                selecting = false;                
            }
        }
        //Maybe reposition stop with data from releaseevent as well?
        if (e.type == GuiEventType.MouseMove && selecting) {
            auto m = e.mouseMove;
            size_t start = determineCharPos(m.pos);
            startMarker = start;
        }
        return super.onEvent(e);
    }
}

//A bit of a hack. It relies on the fact that we use no clipping when drawing outside of our parents.
//Maybe set clipping up as a property of parents?
class GuiElementLabeledEdit : GuiElementEditbox {
    GuiElementText label;
    this(GuiElement parent, Rectd relative, string _label, string str) {
         // ~ " " to make space between label/edit in a simpel manner xD
        label = new GuiElementText(parent, relative.start, _label ~ " ");
        auto labelRect = label.getRelativeRect();
        relative.start.x += labelRect.size.x;
        
        label.setRelativeRect(Rectd(0,0,1,1).getSubRectInv(labelRect));
        super(parent, relative, str);
        label.setParent(this);
    }
    
    
}
