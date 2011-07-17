
module graphics.image;

import std.algorithm;
import std.conv;
import std.exception;
import std.string;

import derelict.devil.il;

import graphics.ogl;
import util;

void ilError(string file = __FILE__, int line = __LINE__) {
    debug {
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

        uint ilImgID;
        ilGenImages(1, &ilImgID);
        ilError();
        scope(exit) ilDeleteImages(1, &ilImgID);
        ilBindImage(ilImgID);
        ilError();
        ilEnable(IL_ORIGIN_SET);
        ilError();
        ilSetInteger(IL_ORIGIN_MODE, IL_ORIGIN_UPPER_LEFT);
        ilError();

        auto cString = toStringz(filename);
        if (ilLoad(IL_TYPE_UNKNOWN, cString) == IL_FALSE) {
            assert(0, "error loading image " ~filename);
        }
        ilError();

        imgWidth = min(ilGetInteger(IL_IMAGE_WIDTH)- offset.X, size.X);
        imgHeight = min(ilGetInteger(IL_IMAGE_HEIGHT)- offset.Y, size.Y);
        imgData.length = 4*imgWidth*imgHeight;
        ilCopyPixels( offset.X, offset.Y, 0, imgWidth, imgHeight, 1, IL_RGBA, IL_UNSIGNED_BYTE, imgData.ptr);
        ilError();
    }

    this(ubyte *data, uint width, uint height) {
        imgData.length = 4*width*height;
        if(data !is null)
            imgData[] = data[0..imgData.length];
        imgWidth = width;
        imgHeight = height;
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

    uint toGLTex(uint tex){
        int width, height;
        debug scope(exit){
            auto tmp = Image(null, imgWidth, imgHeight);
            glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, tmp.imgData.ptr);
            glError();
            tmp.save("derp.png");
        }
        if(tex) {
            glBindTexture(GL_TEXTURE_2D, tex);
            glError();
            glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_WIDTH, &width);
            glError();
            glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_HEIGHT, &height);
            glError();
            if(width == imgWidth && height == imgHeight){
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, imgWidth, imgHeight, GL_RGBA, GL_UNSIGNED_BYTE, imgData.ptr);
                glError();
                return tex;
            }
        }
        if(tex) glDeleteTextures(1, &tex);
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glError();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glError();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glError();
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, imgWidth, imgHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imgData.ptr);
        glError();
        return tex;
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
/*
        int i=0;
        foreach(ref c ; imgData){
            i+=10;
            c = cast(char)(i);
        }
*/
        ilTexImage(imgWidth, imgHeight, 1, 4, IL_RGBA, IL_UNSIGNED_BYTE, imgData.ptr);
        //ilSetPixels( 0, 0, 0, imgWidth, imgHeight, 1, IL_BGRA, IL_UNSIGNED_BYTE, imgData.ptr);
        ilError();
        const char* ptr = toStringz(filename);
        ilEnable(IL_FILE_OVERWRITE);
        ilError();
        ilSave(IL_BMP, ptr);
        ilError();
    }

    void tint(vec3i _color)
    in{
        assert(_color.X>=0 && _color.X <=255, "Bad color sent to Image.tint");
        assert(_color.Y>=0 && _color.Y <=255, "Bad color sent to Image.tint");
        assert(_color.Z>=0 && _color.Z <=255, "Bad color sent to Image.tint");
    }
    body{
        if(_color == vec3i(255, 255, 255)){
            return;
        }
        auto color = util.convert!float(_color) * (1.0/255.0);
        for(int i=0; i < imgData.length; i+=4){
            imgData[i+0] *= color.X;
            imgData[i+1] *= color.Y;
            imgData[i+2] *= color.Z;
        }
    }
}
