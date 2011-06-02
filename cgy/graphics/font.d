

module graphics.font;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.stdio;
import std.string;

import derelict.opengl.gl;

import graphics.renderer;
import graphics.ogl;
import graphics.texture;
import graphics.shader;
import util;

import settings;

static import json;

struct FontVertex{
    vec2f vertPos;
    vec2f texCoord;
};

struct FontQuad {
    FontVertex[4] v;
}

uint FontVert_texCoord_offset = FontVertex.texCoord.offsetof;

class FontShader {
    static FontShader fs;
    static opCall() {
        if(fs is null){
            fs = new FontShader();
        }
        return fs;
    }

    
    alias ShaderProgram!("position", "texcoord", "offset", "tex", "viewportInv") FontShaderProgram;
    FontShaderProgram program;
    private this(){
        program = new FontShaderProgram("shaders/fontShader.vert", "shaders/fontShader.frag");
        //vertAttribLocation = program.getAttribLocation("position");
        //texAttribLocation = program.getAttribLocation("texcoord");
        program.bindAttribLocation(0, "position");
        program.bindAttribLocation(1, "texcoord");
        program.link();
        program.offset = program.getUniformLocation("offset");
        program.tex = program.getUniformLocation("tex");
        program.viewportInv = program.getUniformLocation("viewportInv");
        
        program.use();
        program.setUniform(program.tex, 1); //Font will always reside in texture unit 1 yeaaaah!
        program.setUniform(program.viewportInv,
            vec2f(1.0/renderSettings.windowWidth, 1.0/renderSettings.windowHeight)
        );
    }

    ~this(){
        enforce(program.offset == -1, "FontShader.destroy not called!");
    }

    void destroy() {
        program.use(false);
        program.destroy();
        program.offset = -1;
        fs = null;
    }

    void render(vec2f offset, uint vbo, uint charCount){
        //glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        glDepthMask(0);
        program.use();
        offset.Y = renderSettings.windowHeight - offset.Y;
        program.setUniform(program.offset, offset);        
        glEnableVertexAttribArray(0);
        glError();
        glEnableVertexAttribArray(1);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glError();
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, FontVertex.sizeof, null /* offset in vbo */);
        glError();
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, FontVertex.sizeof, cast(void*)FontVert_texCoord_offset/* offset in vbo */);
        glError();
        glDrawArrays(GL_QUADS, 0, 4*charCount);
        glError();

        glDisableVertexAttribArray(0);
        glError();
        glDisableVertexAttribArray(1);
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
    vec2i position;

    FontQuad[] vertices;
    string currentText;

    this(Font font) {
        this.font = font;
        texId = font.texId;
    }

    ~this() {
        enforce(vbo == 0);
    }
    
    void resize(uint length){
        vertices.length = length;
        if(vbo){
            destroy();
        }
        glGenBuffers(1, &vbo);
        glError();
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glError();
        auto size = FontQuad.sizeof * length;
        glBufferData(GL_ARRAY_BUFFER, size, null, GL_STATIC_DRAW);
        glError();
    }

    void setText(string text) {
        if(text == currentText){
            return;
        }
        auto len = text.length;
        bool resized = false;
        if(len > vertices.length){
            resize(len+3);
            resized = true;
        }
        if(len*2 < vertices.length){
            resize(len);
            resized = true;
        }        
        foreach(cnt, ch ; text) {
            vertices[cnt] = font.getQuad(ch, vec2i(cnt, 0));
        }
        if(!resized){
            glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glError();
        }
        currentText = text;
        auto size = FontQuad.sizeof * len;
        glBufferSubData(GL_ARRAY_BUFFER, 0, size, vertices.ptr);
        glError();
    }

    void setPosition(vec2i pos) { position = pos; }
    void setPositionI(vec2i pos) { position = pos * vec2i(font.glyphSize); }

    void render() {
        glActiveTexture(GL_TEXTURE1);
        glError();
        glBindTexture(GL_TEXTURE_2D, texId);
        glError();
        FontShader().render(util.convert!float(position), vbo, currentText.length);
    }

    void destroy() {
        glDeleteBuffers(1, &vbo);
        glError();
        vbo = 0;
    }
};

class Font {

    static struct ConfigData {
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
    }

    ConfigData conf;
    alias conf this;

    uint texId;

    ~this(){
        enforce(texId == 0, "Font.~this texId != 0");
    }

    this(string fontFile)
    in{
        auto lower = tolower(fontFile);
        assert( !endsWith(lower, ".json") && !endsWith(lower, ".png"), "Specify font files without ending!");
    }
    body{
        auto lastIdx = max(lastIndexOf(fontFile, "/"), lastIndexOf(fontFile, "\\"));
        string path = "";
        if(-1 != lastIdx){
            path = fontFile[0 .. lastIdx+1];
        }
        auto content = readText(fontFile ~ ".json");

        json.update(&conf, content);

        auto img = Image(path ~ conf.textureFile);
        texId = img.toGLTex(0);
    }

    vec2i lookup(char ch)
    in{
        assert(conf.glyphStart <= ch && ch <= conf.glyphEnd, "parameter ch not in valid range!");
    }
    body{
        int x = ch % conf.glyphsPerRow;
        int y = ch / conf.glyphsPerRow;
        return vec2i(x,y);
    }

    FontQuad getQuad(char ch, vec2i offset = vec2i(0, 0))
    in{
        assert(conf.glyphStart <= ch && ch <= conf.glyphEnd, "parameter ch not in valid range!");
    }
    body{
        FontQuad quad;
        quad.v[0].vertPos.set(0, 0);
        quad.v[1].vertPos.set(0, -conf.glyphHeight);
        quad.v[2].vertPos.set(conf.glyphWidth, -conf.glyphHeight);
        quad.v[3].vertPos.set(conf.glyphWidth,  0);

        /*ret[0].vertPos.set(0,  0);
        ret[1].vertPos.set(1,  0);
        ret[2].vertPos.set(1, 1);
        ret[3].vertPos.set(0, 1);*/

        quad.v[0].texCoord.set(0, 0);
        quad.v[1].texCoord.set(0, conf.glyphHeight);
        quad.v[2].texCoord.set(conf.glyphWidth, conf.glyphHeight);
        quad.v[3].texCoord.set(conf.glyphWidth, 0);

        auto where = util.convert!float(lookup(ch)) *
            vec2f(conf.glyphWidth, conf.glyphHeight);
        auto invSize = vec2f(1.0/conf.textureWidth, 1.0/conf.textureHeight);

        auto vertOffset = util.convert!float(offset) *
            vec2f(conf.glyphWidth, -conf.glyphHeight);
        foreach(ref vert ; quad.v){
            vert.vertPos += vertOffset;
            vert.texCoord = (vert.texCoord + where)*invSize;
        }
        return quad;
    }

    vec2i glyphSize() const @property {
        return vec2i(conf.glyphWidth, conf.glyphHeight);
    }

    void destroy() {
        throw new Exception("Implement font.destroy!");
    }

}
