
module graphics.image;

import std.algorithm;
import std.conv;
import std.exception;
import std.string;

import derelict.devil.il;
import derelict.devil.ilu;

import cgy.debug_.debug_ : BREAK_IF;

import cgy.opengl.textures;
import graphics.ogl;
import cgy.logger.log : LogError;
import cgy.math.math;
import cgy.math.vector;
import cgy.opengl.error : glError;
import cgy.util.rect;
import cgy.util.util : makeStackArray, msg;

import cgy.debug_.debug_ : BREAKPOINT;


void ilError(string file = __FILE__, int line = __LINE__) {
    //debug
    {
        uint err = ilGetError();
        string str;
        switch(err){
        case IL_NO_ERROR:
            return;
        case IL_INVALID_ENUM:
            str = "IL ERROR: Invalid enum"; break;
        case IL_INVALID_VALUE:
            str = "IL ERROR: Invalid value"; break;
        case IL_OUT_OF_MEMORY:
            str = "IL ERROR: Out of memory"; break;
        default:
            str = "Got unrecognized il error; "~ to!string(err);
            break;
        }
        auto derp = file ~ to!string(line) ~ "\n" ~str;
        LogError(derp);
        BREAKPOINT;
        assert(0, derp);
    }
}


struct Image {
    string filename;
    int imgWidth;
    int imgHeight;
    ubyte[] imgData;

    this(string filename) {
        this(filename, vec2i(0, 0), vec2i(int.max, int.max));
    }
    this(string _filename, vec2i offset, vec2i size) {
        filename = _filename;
        BREAK_IF(filename is null);
        BREAK_IF(filename.length == 0);

        uint ilImgID;
        ilGenImages(1, &ilImgID); ilError();
        scope(exit) ilDeleteImages(1, &ilImgID);
        ilBindImage(ilImgID); ilError();
        ilEnable(IL_ORIGIN_SET); ilError();
        ilSetInteger(IL_ORIGIN_MODE, IL_ORIGIN_UPPER_LEFT); ilError();

        auto cString = toStringz(filename);
        if (ilLoad(IL_TYPE_UNKNOWN, cString) == IL_FALSE) {
            enforce(0, "error loading image " ~ filename);
        }
        ilError();

        imgWidth = min(ilGetInteger(IL_IMAGE_WIDTH)- offset.x, size.x);
        imgHeight = min(ilGetInteger(IL_IMAGE_HEIGHT)- offset.y, size.y);

        imgData = new ubyte[](4*imgWidth*imgHeight);

        ilCopyPixels( offset.x, offset.y, 0, imgWidth, imgHeight, 1, IL_RGBA, IL_UNSIGNED_BYTE, imgData.ptr);
        ilError();
    }

    this(ubyte *data, uint width, uint height) {
        imgData.length = 4*width*height;
        if(data !is null) {
            imgData[] = data[0..imgData.length];
        }
        imgWidth = width;
        imgHeight = height;
    }

    void destroy() {
        imgWidth = 0;
        imgHeight = 0;
        delete imgData;
        imgData = null;
        filename = null;
    }

    void clear(ubyte r, ubyte g, ubyte b, ubyte a) {
        ubyte[4] rgba = makeStackArray(r, g, b, a);
        (cast(ubyte[4][]) imgData)[] = rgba;
    }

    //Copies a rectangle of data from img to this
    void blit(uint toX, uint toY, Image img, uint fromX, uint fromY, uint width, uint height) {
        enforce(0 <= toX && toX < imgWidth, "bad Image.blit.toX");
        enforce(0 <= toY && toY < imgHeight, "bad Image.blit.toY");
        enforce(0 <= fromX && fromX < img.imgWidth, "bad Image.blit.fromX");
        enforce(0 <= fromY && fromY < img.imgHeight, "bad Image.blit.fromY");
        enforce(0 < width && width <= imgWidth && width <= img.imgWidth, "bad Image.blit.width");
        enforce(0 < height && height <= imgHeight && height <= img.imgHeight, "bad Image.blit.height");
        ubyte* toPtr = imgData.ptr;
        toPtr += 4*toX;
        ubyte* frPtr = img.imgData.ptr;
        frPtr += 4*fromX;
        //We seem to have forgotten about the Y variables :P
        foreach(y ; 0 .. height){
            foreach(x ; 0 .. width){
                toPtr[4*x+0] = frPtr[4*x+0];
                toPtr[4*x+1] = frPtr[4*x+1];
                toPtr[4*x+2] = frPtr[4*x+2];
                toPtr[4*x+3] = frPtr[4*x+3];
            }
            toPtr += 4*imgWidth;
            frPtr += 4*img.imgWidth;
        }
    }

    //TODO: Make this retardedly much faster :D
    // And retardedly much less retarded :P
    void drawLine(vec2i start, vec2i end, vec3i color) {
        vec3ub col = color.convert!ubyte;
        start.x = clamp(start.x, 0, imgWidth-1);
        end.x = clamp(end.x, 0, imgWidth-1);
        start.y = clamp(start.y, 0, imgHeight-1);
        end.y = clamp(end.y, 0, imgHeight-1);

        if(end.x < start.x) {
            swap(start, end);
        }
        if(start.x == end.x) {
            if(end.y < start.y) {
                swap(start, end);
            }
            foreach(y ; start.y .. end.y) {
                vec3ub* ptr = cast(vec3ub*) (imgData.ptr + 4*( start.x + imgWidth * y));
                *ptr = col;
            }
        }
        else if(start.y== end.y) {
            foreach(x ; start.x .. end.x) {
                vec3ub* ptr = cast(vec3ub*) (imgData.ptr + 4*( x + imgWidth * start.y));
                *ptr = col;
            }
        } else {
            void set(int x, int y) {
                BREAK_IF(x < 0);
                BREAK_IF(y < 0);
                BREAK_IF(x >= imgWidth);
                BREAK_IF(y >= imgHeight);
                scope(failure) BREAKPOINT;
                vec3ub* ptr = cast(vec3ub*) (imgData.ptr + 4*( x + imgWidth * y));
                *ptr = col;
            }
            vec2d pt = start.convert!double;
            vec2d dir = end.convert!double - pt;
            auto step = 0.1;
            auto maxIter = cast(int) dir.getLength() / step;
            dir.setLength(step);
            int iter = 0;
            while(start.getDistanceSQ(end) != 0) {
                start = pt.convert!int;
                set(start.x, start.y);
                pt += dir;
                iter++;
                if(iter >= maxIter) return;
            }
        }
    }

    void fromGLTex(uint tex) {
        int width, height;

        glBindTexture(GL_TEXTURE_2D, tex); glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width); glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height); glError();


        if(width * height <= 0) {
            msg("ALERT! Image captured is not very interesting, it has 0 area! Making it 1x1");
            imgWidth = 1;
            imgHeight = 1;
            imgData.length = 4;
            return;
        }

        imgWidth = width;
        imgHeight = height;
        imgData.length = 4 * width * height;
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, imgData.ptr);
        glError();
    }

    void fromGLFloatTex(uint tex, float min, float max) {
        int width, height;

        glBindTexture(GL_TEXTURE_2D, tex); glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width); glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height); glError();


        if(width * height <= 0) {
            msg("ALERT! Image captured is not very interesting, it has 0 area! Making it 1x1");
            imgWidth = 1;
            imgHeight = 1;
            imgData.length = 4;
            return;
        }

        imgWidth = width;
        imgHeight = height;
        imgData.length = 4 * width * height;
        float[] flt;
        flt.length = imgData.length;
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_FLOAT, flt.ptr); glError();
        flt[] -= min;
        flt[] *= 255 / (max-min);
        foreach(size_t idx ; 0 .. imgData.length) {
            imgData[idx] = cast(ubyte)flt[idx];
        }
        clearAlpha();
        delete flt;
    }

    void clearAlpha() {
        foreach(size_t idx ; 0 .. imgData.length / 4) {
            imgData[idx * 4 + 3] = 255; // Force alpha to be non see trouhj
        }
    }


    uint toGLTex(uint tex){
        int width, height;
        version(derpderp){
            debug scope(exit){
                auto tmp = Image(null, imgWidth, imgHeight);
                glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, tmp.imgData.ptr);
                glError();
                tmp.save("derp.bmp");
            }
        }
        if(tex) {
            glBindTexture(GL_TEXTURE_2D, tex);
            glError();
            glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width);
            glError();
            glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height);
            glError();
            if(width == imgWidth && height == imgHeight){
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, imgWidth, imgHeight, GL_RGBA, GL_UNSIGNED_BYTE, imgData.ptr);
                glError();
                return tex;
            }
        }
        if(tex) DeleteTextures(tex);
        tex = Create2DTexture!ubyte(GL_RGBA8, imgWidth, imgHeight, imgData.ptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); glError();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glError();
        return tex;
    }
    

    void setPixel(int x, int y, int r, int g, int b, int a=255) {
        imgData[4*(x + y * imgWidth) + 0] = cast(ubyte)clamp(r, 0, 255);
        imgData[4*(x + y * imgWidth) + 1] = cast(ubyte)clamp(g, 0, 255);
        imgData[4*(x + y * imgWidth) + 2] = cast(ubyte)clamp(b, 0, 255);
        imgData[4*(x + y * imgWidth) + 3] = cast(ubyte)clamp(a, 0, 255);
    }

    void setPixel(int x, int y, ubyte[4] pixel) {
        imgData[4*(x + y * imgWidth) .. 4*(x + y * imgWidth) + 4] = pixel[];
    }
    void setPixel(int x, int y, uint pixel) {
        imgData[4*(x + y * imgWidth) .. 4*(x + y * imgWidth) + 4] = (*cast(ubyte[4]*)&pixel)[];
    }

    void getPixel(int x, int y, ref ubyte r, ref ubyte g, ref ubyte b, ref ubyte a) {
        r = imgData[4*(x + y * imgWidth) + 0];
        g = imgData[4*(x + y * imgWidth) + 1];
        b = imgData[4*(x + y * imgWidth) + 2];
        a = imgData[4*(x + y * imgWidth) + 3];
    }
    vec3f getPixel(int x, int y) {
        ubyte r = imgData[4*(x + y * imgWidth) + 0];
        ubyte g = imgData[4*(x + y * imgWidth) + 1];
        ubyte b = imgData[4*(x + y * imgWidth) + 2];
        return vec3i(r, g, b).convert!float / 255.0f;
    }

    void save(string filename){
        uint img;
        ilGenImages(1, &img);
        ilError();
        scope(exit) ilDeleteImages(1, &img);
        ilBindImage(img);
        ilError();
        ilEnable(IL_ORIGIN_SET);
        ilError();
        ilSetInteger(IL_ORIGIN_MODE, IL_ORIGIN_UPPER_LEFT);
        ilError();

        ilTexImage(imgWidth, imgHeight, 1, 4, IL_RGBA, IL_UNSIGNED_BYTE, imgData.ptr);
        ilError();

        //Is DevIL the evil one here or is it file format dependant etc?
        iluFlipImage();
        ilError();

        const char* ptr = toStringz(filename);
        ilEnable(IL_FILE_OVERWRITE);
        ilError();
        ilSaveImage(ptr);
        //ilSave(IL_PNG, ptr);
        ilError();
    }

    void tint(vec3ub _color)
    in{
        assert(_color.x>=0 && _color.x <=255, "Bad color sent to Image.tint");
        assert(_color.y>=0 && _color.y <=255, "Bad color sent to Image.tint");
        assert(_color.z>=0 && _color.z <=255, "Bad color sent to Image.tint");
    }
    body{
        if(_color == vec3ub(255, 255, 255)){
            return;
        }
        auto color = _color.convert!float() * (1.0/255.0);
        for(int i=0; i < imgData.length; i+=4){
            imgData[i+0] = cast(ubyte)(imgData[i+0] * color.x);
            imgData[i+1] = cast(ubyte)(imgData[i+1] * color.y);
            imgData[i+2] = cast(ubyte)(imgData[i+2] * color.z);
        }
    }

    int opApply(scope int delegate(int x, int y, ref ubyte r, ref ubyte g, ref ubyte b, ref ubyte a) Do) {
        const iters = imgWidth * imgHeight;
        int ret;
        foreach(idx ; 0 .. iters) {
            ret = Do(idx % imgWidth, idx / imgWidth,
                     imgData[idx*4+0], 
                     imgData[idx*4+1], 
                     imgData[idx*4+2], 
                     imgData[idx*4+3]);
            if(ret) {
                return ret;
            }
        }
        return 0;
    }

    void flipHorizontal() {
        size_t line1 = 0;
        size_t line2 = imgHeight - 1;
        ubyte[] buff;
        buff.length = imgWidth * 4;
        void swap(size_t l1, size_t l2) {
            size_t stride = imgWidth * 4;
            size_t idx1 = l1 * stride;
            size_t idx2 = l2 * stride;
            buff[] = imgData[idx1 .. idx1 + stride];
            imgData[idx1 .. idx1 + stride] = imgData[idx2 .. idx2 + stride];
            imgData[idx2 .. idx2 + stride] = buff[];
        }
        while(line1 < line2) {
            swap(line1, line2);
            line1++;
            line2--;
        }
    }

}
