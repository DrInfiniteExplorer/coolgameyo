

module gui.printscreenmenu;

import std.conv;
import std.file;
import std.regex;
import std.stdio;

import main;

import gui.mainmenu;
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
import graphics.raycastcpu;
import graphics.raycastgpu;

import settings;
import util.httpupload;
import util.rect;
import util.util;
import world.world;

class PrintScreenMenu : GuiElementWindow {
    GuiSystem guiSystem;
    MainMenu main;
    GuiElementButton wikiButt, sendfileButt, fileButt, okButt;
    GuiElementEditbox nameBox;
    GuiEventDump dump;

    Image img;
    this(MainMenu m, World w, Camera c) {
        img = screenCap();
        //computeYourFather(w, img, c);
        main = m;
        guiSystem = cast(GuiSystem)m.getGuiSystem();
        dump = guiSystem.setEventDump(null);

        super(guiSystem, Rectd(vec2d(0.0, 0.0), vec2d(1.0, 1.0)), "Printscreen Menu~~~!", false, false);
        //*
        auto text = new GuiElementText(this, vec2d(0.1, 0.1), "Printscreen yeah~~~!");     

        wikiButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.30), vec2d(0.3, 0.10)), "Wiki", onClick(&onWiki));
        sendfileButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.45), vec2d(0.3, 0.10)), "Sendfile", onClick(&onSendfile));
        fileButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.60), vec2d(0.3, 0.10)), "File", onClick(&onFile));

        //main.setVisible(false);
    }

    override void destroy() {
        guiSystem.setEventDump(dump);
        super.destroy();
    }

    void closeButt() {
        wikiButt.destroy();
        sendfileButt.destroy();
        fileButt.destroy();
    }

    void delegate() onClick(void delegate() cb) {
        return (){
            closeButt();

            nameBox = new GuiElementEditbox(this, Rectd(vec2d(0.10, 0.35), vec2d(0.3, 0.05)), "ImgName.bmp",); //TODO: <-- ending with ,) ?
            fileButt = new GuiElementButton(this, Rectd(vec2d(0.1, 0.60), vec2d(0.3, 0.10)), "Ok", (){cb(); /*main.setVisible(true);*/ destroy();});
        };  
    }

    void onFile() {
        auto str = nameBox.getText();
        img.save(str);
    }
    void onWiki() {
        auto str = nameBox.getText();
        img.save("tmp_img.bmp");        
        auto response = sendFile("luben.se", 80, "/wiki/editbin.php?name="~str, "save", "derpyhooves.lolol", cast(char[]) read("tmp_img.bmp"), "body");
        writeln("File upload: Probably " ~ (response is null) ? "failed" : " success!");
        setCopyString("[[img:"~str~"]]");
    }
    void onSendfile() {
        auto str = nameBox.getText();
        img.save("tmp_img.bmp");
        auto response = sendFile("luben.se", 80, "/sendfile/index.php?upload=true", "file", str, cast(char[]) read("tmp_img.bmp"), "body", "image/png");
        if(response !is null) {
            auto ex = regex(r"File <a href='\?id=(\d+)'>");
            auto m = match(response, ex);
            if (!m.empty) {
                auto id = m.captures[1];
                setCopyString("http://luben.se/sendfile/?id="~id);
            }
        }
    }


}



