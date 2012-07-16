
module graphics.image;

import std.algorithm;
import std.conv;
import std.exception;
import std.string;

import derelict.devil.il;

import graphics.ogl;
import util.util;
import util.rect;


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
            enforce(0, "error loading image " ~ filename);
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

    void clear(ubyte r, ubyte g, ubyte b, ubyte a) {
        ubyte[4] rgba = [r, g, b, a];
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
        start.X = clamp(start.X, 0, imgWidth-1);
        end.X = clamp(end.X, 0, imgWidth-1);
        start.Y = clamp(start.Y, 0, imgHeight-1);
        end.Y = clamp(end.Y, 0, imgHeight-1);

        if(end.X < start.X) {
            swap(start, end);
        }
        if(start.X == end.X) {
            if(end.Y < start.Y) {
                swap(start, end);
            }
            foreach(y ; start.Y .. end.Y) {
                vec3ub* ptr = cast(vec3ub*) (imgData.ptr + 4*( start.X + imgWidth * y));
                *ptr = col;
            }
        }
        else if(start.Y == end.Y) {
            foreach(x ; start.X .. end.X) {
                vec3ub* ptr = cast(vec3ub*) (imgData.ptr + 4*( x + imgWidth * start.Y));
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
            while(start.getDistanceFromSQ(end) != 0) {
                start = pt.convert!int;
                set(start.X, start.Y);
                pt += dir;
                iter++;
                if(iter >= maxIter) return;
            }
        }
    }

    void fromGLTex(uint tex) {
        int width, height;

        glBindTexture(GL_TEXTURE_2D, tex);
        glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width);
        glError();
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height);
        glError();

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
    

    void setPixel(int x, int y, int r, int g, int b, int a=0) {
        //y = imgHeight - y -1;
        imgData[4*(x + y * imgWidth) + 0] = cast(ubyte)clamp(r, 0, 255);
        imgData[4*(x + y * imgWidth) + 1] = cast(ubyte)clamp(g, 0, 255);
        imgData[4*(x + y * imgWidth) + 2] = cast(ubyte)clamp(b, 0, 255);
        imgData[4*(x + y * imgWidth) + 3] = cast(ubyte)clamp(a, 0, 255);
    }

    void setPixel(int x, int y, ubyte[4] pixel) {
        //y = imgHeight - y -1; // Why was this at all?
        imgData[4*(x + y * imgWidth) .. 4*(x + y * imgWidth) + 4] = pixel;
    }

    void getPixel(int x, int y, ref ubyte r, ref ubyte g, ref ubyte b, ref ubyte a) {
        y = imgHeight - y -1;
        r = imgData[4*(x + y * imgWidth) + 0];
        g = imgData[4*(x + y * imgWidth) + 1];
        b = imgData[4*(x + y * imgWidth) + 2];
        a = imgData[4*(x + y * imgWidth) + 3];
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
        const char* ptr = toStringz(filename);
        ilEnable(IL_FILE_OVERWRITE);
        ilError();
        ilSaveImage(ptr);
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
        auto color = _color.convert!float() * (1.0/255.0);
        for(int i=0; i < imgData.length; i+=4){
            imgData[i+0] *= color.X;
            imgData[i+1] *= color.Y;
            imgData[i+2] *= color.Z;
        }
    }

    int opApply(scope int delegate(int x, int y, ref ubyte r, ref ubyte g, ref ubyte b, ref ubyte a) Do) {
        const iters = imgWidth * imgHeight;
        foreach(idx ; 0 .. iters) {
            if(Do(idx % imgWidth, idx / imgWidth,
                  imgData[idx*4+0], 
                  imgData[idx*4+1], 
                  imgData[idx*4+2], 
                  imgData[idx*4+3])) {
                return 1;
            }
        }
        return 0;
    }


}
