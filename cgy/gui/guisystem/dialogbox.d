module gui.guisystem.dialogbox;

import std.algorithm;
import std.array;
import std.exception;
import std.range;

import gui.all;

import util.util;
import util.rect;

class DialogBox : GuiElementWindow {
    GuiElement guiSystem;
    GuiElement creator;


    alias void delegate(string) SingleAnswerDelegate;
    alias void delegate() MultiAnswerDelegate;

    GuiElementText message;

    this(T...)(GuiElement _creator, string title, string _message, T t) {
        creator = _creator;
        guiSystem = creator.getGuiSystem();

        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1, 1)), title, true, false);

        static if(is(t[1] : SingleAnswerDelegate)) {
            enum singleAnswer = true;
            auto options = array(split(t[0], "|"));
            auto callback = t[1];
        } else {
            enum singleAnswer = false;

            string[] options;
            MultiAnswerDelegate[] callbacks;
            foreach(item ; t) {
                static if(is(typeof(item) : string)) {
                    options ~= item;
                } else {
                    callbacks ~= item;
                }
            }
            enforce(options.length == callbacks.length, "Length of options and callbacks not the same!");
        }


        // Make the message and find out how big it is in relation to the screen.
        message = new GuiElementText(this, vec2d(0.0), _message);
        auto messageSize = message.getRelativeRect();

        //Take this and pad it 30%
        auto dialogSize = messageSize.pad(messageSize.widthOf * 0.3, messageSize.heightOf * 0.3);
        //auto barArea = barArea; //This is the size ofthe bar area. The height is used to determine extra window height for the bar and some free space.
        dialogSize = dialogSize.pad(0, barArea.heightOf * 6);

        //Now center this relative to a rect that is 0,0,1,1 big.
        dialogSize = relativeRect.centerRect(dialogSize);
        setRelativeRect(dialogSize);

        //The dialog is now sized and positioned.

        auto a = Recti(vec2i(0, clientAreaAbsolute.topOf + message.getSize().Y / 2 ), message.getSize());
        auto newRect = clientAreaAbsolute.centerRect(a, true, false);
        message.setAbsoluteRect(newRect);
        

        double buttonStartY = message.bottomOf + barArea.heightOf;
        double buttonHeight = clientArea.heightOf - buttonStartY;
        double padding = 0.1;
        double width = 1.0 - 2*padding;
        double basicWidth = width / (2*options.length + max(0, options.length-1));

        foreach(idx, option ; options) {
            auto x = padding + basicWidth*3*idx;
            new GuiElementButton(this, Rectd(x, buttonStartY, 2*basicWidth, buttonHeight), option, 
                (int idx, string s){
                    return {
                        static if(singleAnswer) {
                            callback(s);
                        } else {
                            callbacks[idx]();
                        }
                        destroy();
                    };
                }(idx, option)
            );

        }



        //GuiElementButton




    }





}

