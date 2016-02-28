module gui.guisystem.imagecache;

import cgy.json;
import graphics.image : Image;
import graphics.ogl;
import cgy.math.vector;
import cgy.debug_.debug_ : BREAK_IF;
import cgy.opengl.textures;
import cgy.opengl.error : glError;


final class ImageCache {

    uint[string] textures; // Indexed by name

    this() {
        loadImageDefinitions("gui/borders.json");
    }

    bool destroyed = false;
    ~this() {
        BREAK_IF(!destroyed);
    }

    void destroy() {
        uint[] texes = textures.values;
        DeleteTextures(texes);
        textures = null;
        destroyed = true;
    }

    uint getImage(string name) {
        if(name in textures) {
            return textures[name];
        }
        return 0;
    }

    void loadImage(string path, string name, string wrapMode, vec2i origin = vec2i(0,0), vec2i size = vec2i(0, 0)) {
        BREAK_IF(!!(name in textures));
        Image img;
        if(size.x + size.y == 0) {
            img = Image(path);
        } else {
            img = Image(path, origin, size);
        }
        auto tex = img.toGLTex(0);
        textures[name] = tex;

        glBindTexture(GL_TEXTURE_2D, tex); glError();
        auto mode = (wrapMode == "clamp") ? GL_CLAMP_TO_EDGE : GL_REPEAT;
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, mode); glError();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, mode); glError();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR); glError();
        if(g_glVersion < 3.0){
            glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
            glError();
        } else {
            glGenerateMipmap(GL_TEXTURE_2D); glError();
        }

        glBindTexture(GL_TEXTURE_2D, 0); glError();
        img.destroy();

        Image image;
        image.fromGLTex(tex);
        img.save("derp.png");

    }

    void loadImageDefinitions(string path) {
        auto rootValue = loadJSON(path);
        foreach(value ; rootValue.asArray) {
            string imgPath;
            string name;
            string wrapMode = "clamp";
            vec2i origin = vec2i(0,0);
            vec2i size = vec2i(0,0);
            value.readJSONObject("path", &imgPath,
                                 "name", &name,
                                 "wrap", &wrapMode,
                                 "origin", &origin,
                                 "size", &size);
            loadImage(imgPath, name, wrapMode, origin, size);
        }
    }


}


