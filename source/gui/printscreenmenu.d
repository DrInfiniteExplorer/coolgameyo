

module gui.printscreenmenu;

import std.conv;
import std.file;
import std.regex;
import std.stdio;

import main;

import gui.guisystem.button;
import gui.guisystem.checkbox;
import gui.guisystem.editbox;
import gui.guisystem.guisystem;
import gui.guisystem.slider;
import gui.guisystem.text;
import gui.guisystem.window;

import graphics.ogl;
import graphics.image;
import graphics.camera;

import settings;
import util.filesystem : mkdir, rmdir;
import util.httpupload;
import util.rect;
import util.util;
import worldstate.worldstate;

class PrintScreenMenu : GuiElementWindow {
    GuiSystem guiSystem;
    PushButton wikiButt, sendfileButt, fileButt, okButt;
    GuiElementEditbox nameBox;

    bool done = false;

    Image img;
    this(GuiSystem _guiSystem) {
        img = screenCap();

        guiSystem = _guiSystem;

        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1.0, 1.0)), "Printscreen Menu~~~!", false, false);
        //*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "Printscreen yeah~~~!");     

        wikiButt = new PushButton(this, Rectd(vec2d(0.1, 0.30), vec2d(0.3, 0.10)), "Wiki", onClick(&onWiki));
        sendfileButt = new PushButton(this, Rectd(vec2d(0.1, 0.45), vec2d(0.3, 0.10)), "Sendfile", onClick(&onSendfile));
        fileButt = new PushButton(this, Rectd(vec2d(0.1, 0.60), vec2d(0.3, 0.10)), "File", onClick(&onFile));

        //main.setVisible(false);
    }

    override void destroy() {
        super.destroy();
        done = true;
    }

    void closeButt() {
        wikiButt.destroy();
        sendfileButt.destroy();
        fileButt.destroy();
    }

    void delegate() onClick(void delegate() cb) {
        return (){
            closeButt();

            nameBox = new GuiElementEditbox(this, Rectd(vec2d(0.10, 0.35), vec2d(0.3, 0.05)), "ImgName.png",); //TODO: <-- ending with ,) ?
            fileButt = new PushButton(this, Rectd(vec2d(0.1, 0.60), vec2d(0.3, 0.10)), "Ok", (){cb(); /*main.setVisible(true);*/ destroy();});
        };  
    }

    void onFile() {
        auto str = nameBox.getText();
        img.save(str);
    }
    void onWiki() {
        auto str = nameBox.getText();
        mkdir("wiki_tmp");
        img.save("wiki_tmp/" ~ str);        
        auto response = sendFile("luben.se", 80, "/wiki/editbin.php?name="~str, "save", "derpyhooves.lolol", cast(char[]) read("wiki_tmp/" ~ str), "body");
        writeln("File upload: Probably " ~ (response is null) ? "failed" : " success!");
        setCopyString("[[img:"~str~"]]");
        rmdir("wiki_tmp");
    }
    void onSendfile() {
        auto str = nameBox.getText();
        mkdir("wiki_tmp");
        img.save("wiki_tmp/" ~ str);        
        auto response = sendFile("luben.se", 80, "/sendfile/index.php?upload=true", "file", str, cast(char[]) read("wiki_tmp/" ~ str), "body", "image/png");
        if(response !is null) {
            auto ex = regex(r"File <a href='\?id=(\d+)'>");
            auto m = match(response, ex);
            if (!m.empty) {
                auto id = m.captures[1];
                setCopyString("http://luben.se/sendfile/?id="~id);
            }
        }
        rmdir("wiki_tmp");
    }

    bool isDone() {
        return done;
    }

}

void PrintScreen() {
    GuiSystem guiSystem;
    guiSystem = new GuiSystem;
    auto ps = new PrintScreenMenu(guiSystem);

    scope(exit) {
        guiSystem.destroy();
    }
    EventAndDrawLoop!true(guiSystem, null, &ps.isDone);

}

