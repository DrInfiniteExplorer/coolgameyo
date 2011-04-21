

module graphics.font;

import std.exception;
import std.file;
import std.json;
import std.string;


import graphics.texture;

class StringTexture {

    Font font;

    this(Font font) {
        this.font = font;
    }

    void setText(string text) {
        font.buildText(text, this);
    }

    void destroy() {
        throw new Exception("Implement");
    }
};

class Font {

    string fontName;
    int fontSize;

    int glyphStart;
    int glyphEnd;
    int glyphWidth;
    int glyphHeight;
    int glyphsPerRow;
    int glyphsPerCollumn;
    bool antiAliased;
    bool bold;
    bool italic;
    string textureFile;
    int textureWidth;
    int textureHeight;
    int textureSlices;

    this(string fontFile) {
        version(all){
            //To be implemented when luben has a working real-parser (as parseJSON fails cause o that)
            enforce(endsWith(tolower(fontFile), ".json"), "Font file specified not json!");
            auto content = readText(fontFile);
            auto root = parseJSON(content);
            enforce(root.type == JSON_TYPE.OBJECT);
            auto map = root.object;
            long getLong(string key) {
                auto pVal = key in map;
                enforce(pVal && pVal.type == JSON_TYPE.INTEGER);
                return pVal.integer;
            }
            int getInt(string key){
                return cast(int) getLong(key);
            }
            string getString(string key) {
                auto pVal = key in map;
                enforce(pVal && pVal.type == JSON_TYPE.STRING);
                return pVal.str;
            }
            bool getBool(string key) {
                auto pVal = key in map;
                enforce(pVal && (pVal.type == JSON_TYPE.FALSE ||pVal.type == JSON_TYPE.TRUE));
                return pVal.type == JSON_TYPE.TRUE;
            }
            glyphStart = getInt("glyphStart");
        }

    }

    void buildText(string text, StringTexture st) {
    }


    void destroy() {
    }

}

