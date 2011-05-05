

module graphics.font;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
//import std.json;
import std.stdio;
import std.string;

import derelict.opengl.gl;

import graphics.renderer;
import graphics.ogl;
import graphics.texture;
import graphics.shader;
import util;

struct FontVertex{
    vec2f vertPos;
    vec2f texCoord;
};

uint FontVert_texCoord_offset = FontVertex.texCoord.offsetof;

class FontShader {
    static FontShader fs;
    static opCall() {
        if(fs is null){
            fs = new FontShader();
        }
        return fs;
    }

    ShaderProgram program;
    int vertAttribLocation;
    int texAttribLocation;
    int posUniformLocation;
    int texUniformLocation;
    private this(){
        program = new ShaderProgram("shaders/fontShader.vert", "shaders/fontShader.frag");
        vertAttribLocation = program.getAttribLocation("position");
        texAttribLocation = program.getAttribLocation("texcoord");
        posUniformLocation = program.getUniformLocation("offset");
        texUniformLocation = program.getUniformLocation("tex");
        auto a = program.getUniformLocation("viewportInv");
        program.use();
        program.setUniform(texUniformLocation, 1); //Font will always reside in texture unit 1 yeaaaah!
        program.setUniform(a, vec2f(1.0/renderSettings.windowWidth, 1.0/renderSettings.windowHeight));
    }

    ~this(){
        enforce(posUniformLocation == -1, "FontShader.destroy not called!");
    }

    void destroy() {
        program.use(false);
        program.destroy();
        posUniformLocation = -1;
        fs = null;
    }

    void render(vec2f offset, uint vbo, uint charCount){
        //glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        glDepthMask(0);
        program.use();
        offset.Y = renderSettings.windowHeight - offset.Y;
        program.setUniform(posUniformLocation, offset);
        glEnableVertexAttribArray(vertAttribLocation);
        glError();
        glEnableVertexAttribArray(texAttribLocation);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glError();
        glVertexAttribPointer(vertAttribLocation, 2, GL_FLOAT, GL_FALSE, FontVertex.sizeof, null /* offset in vbo */);
        glError();
        glVertexAttribPointer(texAttribLocation, 2, GL_FLOAT, GL_FALSE, FontVertex.sizeof, cast(void*)FontVert_texCoord_offset/* offset in vbo */);
        glError();
        glDrawArrays(GL_QUADS, 0, 4*charCount);
        glError();

        glDisableVertexAttribArray(texAttribLocation);
        glError();
        glDisableVertexAttribArray(vertAttribLocation);
        glError();
        program.use(false);
        glDepthMask(1);
        glDisable(GL_BLEND);
        glEnable(GL_DEPTH_TEST);
    }
}

class StringTexture {

    Font font;
    uint texId;
    uint vbo;
    uint charCount;
    vec2i position;

    this(Font font) {
        this.font = font;
        texId = font.texId;
    }

    ~this() {
        enforce(vbo == 0);
    }

    void setText(string text) {
        if(vbo){
            destroy();
        }

        FontVertex[] vertices;
//        int cnt = 0;
        foreach(cnt, ch ; text) {
            vertices ~= font.getQuad(ch, vec2i(cnt, 0));
            //cnt++;
        }
        charCount = text.length;

        glGenBuffers(1, &vbo);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glError();
        auto size = FontVertex.sizeof * vertices.length;
        glBufferData(GL_ARRAY_BUFFER, size, vertices.ptr, GL_STATIC_DRAW);
        glError();
    }

    void setPosition(vec2i pos) { position = pos; }
    void setPositionI(vec2i pos) { position = pos * vec2i(font.glyphSize); }

    void render() {
        glActiveTexture(GL_TEXTURE1);
        glError();
        glBindTexture(GL_TEXTURE_2D, texId);
        glError();
        FontShader().render(util.convert!float(position), vbo, charCount);
    }

    void destroy() {
        glDeleteBuffers(1, &vbo);
        vbo = 0;
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

    uint texId;

    ~this(){
        enforce(texId == 0, "Font.~this texId != 0");
    }

    this(string fontFile)
    in{
        auto lower = tolower(fontFile);
        assert( !endsWith(lower, ".xml") && !endsWith(lower, ".png"), "Specify font files without ending!");
    }
    body{
        auto lastIdx = max(lastIndexOf(fontFile, "/"), lastIndexOf(fontFile, "\\"));
        string path = "";
        if(-1 != lastIdx){
            path = fontFile[0 .. lastIdx+1];
        }
        //auto content = readText(fontFile ~ ".json");
        //auto root = parseJSON(content);
        //enforce(root.type == JSON_TYPE.OBJECT);
        //auto map = root.object;
        //long getLong(string key) {
        //    auto pVal = key in map;
        //    enforce(pVal && pVal.type == JSON_TYPE.INTEGER);
        //    return pVal.integer;
        //}
        //int getInt(string key){
        //    return cast(int) getLong(key);
        //}
        //string getString(string key) {
        //    auto pVal = key in map;
        //    enforce(pVal && pVal.type == JSON_TYPE.STRING);
        //    return pVal.str;
        //}
        //bool getBool(string key) {
        //    auto pVal = key in map;
        //    enforce(pVal && (pVal.type == JSON_TYPE.FALSE ||pVal.type == JSON_TYPE.TRUE));
        //    return pVal.type == JSON_TYPE.TRUE;
        //}
        glyphStart = 0;//getInt("glyphStart");
        textureFile = "courier.tif";//getString("textureFile");

        bold = false;//getBool("bold");
        italic = false;//getBool("italic");
        antiAliased = true;//getBool("antiAliased");
        //fontHeight = 18;
        glyphStart = 0;//getInt("glyphStart");;
        glyphEnd = 255;//getInt("glyphEnd");
        textureWidth  = 512;//getInt("textureWidth");
        textureHeight = 512;//getInt("textureHeight");

        glyphWidth = 9;//getInt("glyphWidth");
        glyphHeight = 16;//getInt("glyphHeight");
        glyphsPerRow = 56;//getInt("glyphsPerRow");
        glyphsPerCollumn = 32;//getInt("glyphsPerCollumn");
        textureSlices = 1;//getInt("textureSlices");

        auto img = Image(path ~ textureFile);
        texId = img.toGLTex(0);
    }

    vec2i lookup(char ch)
    in{
        assert(glyphStart <= ch && ch <= glyphEnd, "parameter ch not in valid range!");
    }
    body{
        int x = ch % glyphsPerRow;
        int y = ch / glyphsPerRow;
        return vec2i(x,y);
    }

    FontVertex[4] getQuad(char ch, vec2i offset = vec2i(0, 0))
    in{
        assert(glyphStart <= ch && ch <= glyphEnd, "parameter ch not in valid range!");
    }
    body{
        FontVertex[4] ret;
        ret[0].vertPos.set(0,  0);
        ret[1].vertPos.set(0, -glyphHeight);
        ret[2].vertPos.set(glyphWidth, -glyphHeight);
        ret[3].vertPos.set(glyphWidth,  0);

        /*ret[0].vertPos.set(0,  0);
        ret[1].vertPos.set(1,  0);
        ret[2].vertPos.set(1, 1);
        ret[3].vertPos.set(0, 1);*/

        ret[0].texCoord.set(0, 0);
        ret[1].texCoord.set(0, glyphHeight);
        ret[2].texCoord.set(glyphWidth, glyphHeight);
        ret[3].texCoord.set(glyphWidth, 0);

        auto where = util.convert!float(lookup(ch)) * vec2f(glyphWidth, glyphHeight);
        auto invSize = vec2f(1.0/textureWidth, 1.0/textureHeight);

        auto vertOffset = util.convert!float(offset) * vec2f(glyphWidth, -glyphHeight);
        foreach(ref vert ; ret){
            vert.vertPos += vertOffset;
            vert.texCoord = (vert.texCoord + where)*invSize;
        }
        return ret;
    }

    vec2i glyphSize() const @property {
        return vec2i(glyphWidth, glyphHeight);
    }



    void destroy() {
        throw new Exception("Implement font.destroy!");
    }

}
