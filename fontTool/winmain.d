module winmain;

import core.runtime;

//Bad behaviour if using both this and the more complete win32.windows.
//import std.c.windows.windows;
import std.conv;
import std.exception;
import std.file;
import std.json;
import std.stdio;
import std.string;

//import win32.windows : CreateCompatibleBitmap, SIZE, GetTextExtentPoint32A, HANDLE;
import win32.windows;
import derelict.devil.il;
import derelict.devil.ilut;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    void exceptionHandler(Throwable e)
    {
        throw e;
    }

    try
    {
        Runtime.initialize(&exceptionHandler);

        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);

        Runtime.terminate(&exceptionHandler);
    }
    catch (Throwable o)    // catch any uncaught exceptions
    {
        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;    // failed
    }

    return result;
}



int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    DerelictIL.load();
    ilInit();
//    DerelictILUT.load();

    string outFontName = "courier";
    string outFormat = ".tif";
    string fontName = "Courier";
    bool bold = false;
    bool italic = false;
    bool aa = true;
    int fontHeight = 18;
    int glyphStart = 0;
    int glyphEnd = 255;
    int textureWidth  = 512;
    int textureHeight = 512;

    HDC screenDC = GetDC(null);
    HDC memDC = CreateCompatibleDC(screenDC);

    const char* fontNamePtr = toStringz(fontName);

    HFONT font = CreateFontA(fontHeight, 0,
                            0, 0,
                            bold ? FW_BOLD : 0,
                            italic ? TRUE : FALSE,
                            FALSE, //underline
                            FALSE, //strikeout
                            ANSI_CHARSET, //charset
                            OUT_DEFAULT_PRECIS, //precision
                            CLIP_DEFAULT_PRECIS, //clip precision
                            aa ? ANTIALIASED_QUALITY : DEFAULT_QUALITY, //maybe try cleartype or else non-aa as default may do aa?
                            DEFAULT_PITCH, //Pitch and font-family (used for auto-determining font if not available)
                            fontNamePtr);
    if(null == font){
        throw new Exception("Could not create font of type: " ~ fontName);
    }

    HFONT oldFont = SelectObject(memDC, font);
    SetTextAlign(memDC, TA_LEFT | TA_TOP | TA_NOUPDATECP);

    int glyphCount = glyphEnd-glyphStart+1;
    writeln("glyphCount: ", glyphCount);

    //Determine max width, height of all characters in range.
    int maxWidth = 0;
    int maxHeight = 0;
    foreach( i ; glyphStart .. glyphEnd+1) {
        const(char) c = to!(const(char))(i);
        SIZE size;
        ABC abc;
        int width, height;
        GetTextExtentPoint32A(memDC, &c, 1, &size);

        if(GetCharABCWidthsA(memDC, c, c, &abc)) {
            size.cx = abc.abcB;
        }
        maxWidth  = max(maxWidth, size.cx);
        maxHeight = max(maxHeight, size.cy);
    }

    writeln("maxWidth(glyph) :", maxWidth );
    writeln("maxHeight(glyph):", maxHeight);

    int glyphsPerRow = textureWidth / maxWidth;
    int glyphsPerCollumn = textureHeight / maxHeight;
    int rowCount = (glyphCount / glyphsPerRow) + ((glyphCount % glyphsPerRow == 0) ? 0 : 1);
    int textureSlices = (rowCount / glyphsPerCollumn) + ((rowCount % glyphsPerCollumn == 0) ? 0 : 1);

    writeln("Glyphs per row    : ", glyphsPerRow);      //Per texture slice
    writeln("Glyphs per collumn: ", glyphsPerCollumn);  //Per texture slice
    writeln("Row count         : ", rowCount);          //Total row count
    writeln("Texture slices    : ", textureSlices);

    enforce(textureSlices == 1, "Implement multiple texture slices :):):):):):)");

    HBITMAP bitmap = CreateCompatibleBitmap(screenDC, textureWidth, textureHeight);
    HBITMAP oldBitmap = SelectObject(memDC, bitmap);

    int xPos = 0;
    int yPos = 0;
    SetTextColor(memDC, 0x00FFFFFF); //white
    SetBkColor(memDC, 0);
    foreach( i ; glyphStart .. glyphEnd + 1) {
        const(char) c = to!(const(char))(i);

        TextOutA(memDC, xPos, yPos, &c, 1);
        xPos += maxWidth;
        if(xPos + maxWidth > textureWidth) {
            yPos += maxHeight;
            xPos = 0;
        }
    }

    /+
    {
        fontName:"asd",
        fontSize:42,
        glyphStart:0, glyphEnd:255,
        glyphWidth:9, glyphHeight:18
        glyphsPerRow:56, glyphsPerCollumn:56,
        antiAliased:false, bold:false, italic:false,
        textureFile:"lol.bmp", textureWidth:512, textureHeight:512,
        textureSlices:1,
        //glyphMap:{'A':{x,y}, ...} ? may implement later, maybe. yeaaaah.
    }
    +/
    JSONValue[string] root;
    root["fontName"] = JSON(fontName);
    root["fontSize"] = JSON(fontHeight);
    root["glyphStart"] = JSON(glyphStart);
    root["glyphEnd"] = JSON(glyphEnd);
    root["glyphWidth"] = JSON(maxWidth);
    root["glyphHeight"] = JSON(maxHeight);
    root["glyphsPerRow"] = JSON(glyphsPerRow);
    root["glyphsPerCollumn"] = JSON(glyphsPerCollumn);
    root["antiAliased"] = JSON(aa);
    root["bold"] = JSON(bold);
    root["italic"] = JSON(italic);
    root["textureFile"] = JSON(outFontName ~ outFormat);
    root["textureWidth"] = JSON(textureWidth);
    root["textureHeight"] = JSON(textureHeight);
    root["textureSlices"] = JSON(textureSlices);

    auto jsonRoot = JSON(root);
    auto jsonString = toJSON(&jsonRoot);
    writeln(jsonString);

    std.file.write(outFontName ~ ".json", jsonString);



    debug BitBlt(screenDC, 0, 0, textureWidth, textureHeight, memDC, 0, 0, SRCCOPY);

    BITMAPINFOHEADER bmInfo;
    bmInfo.biSize = bmInfo.sizeof;
    bmInfo.biWidth = textureWidth;
    bmInfo.biHeight = textureHeight;
    bmInfo.biPlanes = 1;
    bmInfo.biBitCount = 32;
    bmInfo.biCompression = BI_RGB;
    bmInfo.biSizeImage = 0;
    bmInfo.biXPelsPerMeter = 0;
    bmInfo.biYPelsPerMeter = 0;
    bmInfo.biClrUsed = 0;
    bmInfo.biClrImportant = 0;
    ubyte[] data;
    data.length = ((textureWidth * bmInfo.biBitCount + 31) / 32) * 4 * textureHeight;

    //"The bitmap identified by the hbmp parameter must not be selected into a device context when the application calls this function."

    SelectObject(memDC, oldBitmap);
    if(textureHeight != GetDIBits(memDC, bitmap,
                      0u, cast(uint)textureHeight,
                      cast(void*)data.ptr,
                      cast(BITMAPINFO*)&bmInfo,
                      DIB_RGB_COLORS)){
        writeln(GetLastError());
        throw new Exception("Could not get DIBits!");
    }

    ubyte *pPixel = data.ptr;
    foreach(cnt ; 0 .. textureWidth*textureHeight){
        int r = pPixel[0];
        int g = pPixel[1];
        int b = pPixel[2];
        pPixel[3] = 255;
        pPixel[3] = to!ubyte((r+g+b)/3);
        if(pPixel[3] != 0) {
            writeln(r, " ", g, " ", b, " ", pPixel[3]);
        }
        pPixel += 4;
    }

    debug{
        foreach( cnt ; 0 .. glyphCount) {
            int x = (cnt % glyphsPerRow)*maxWidth;
            int y = (cnt / glyphsPerRow)*maxHeight;
            y = textureHeight - y - 1;
            pPixel = data.ptr;
            pPixel += x * 4;
            pPixel += y * 4 * textureWidth;
            pPixel[0] = 255;
            pPixel[1] = 0;
            pPixel[2] = 0;
        }
    }

    {
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
        ilTexImage(textureWidth, textureHeight, 1, 4, IL_RGBA, IL_UNSIGNED_BYTE, data.ptr);
        ilError();
        string filename = outFontName ~ outFormat;
        const char* ptr = toStringz(filename);
        ilEnable(IL_FILE_OVERWRITE);
        ilError();
        ilSave(IL_TYPE_UNKNOWN, ptr);
        ilError();
    }



    SelectObject(memDC, oldFont);
    DeleteObject(font);
    DeleteObject(bitmap);
    ReleaseDC(NULL, memDC);
    ReleaseDC(NULL, screenDC);

//    DerelictILUT.unload();
    DerelictIL.unload();

    return 0;
}


void ilError(string file = __FILE__, int line = __LINE__){
    debug{
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

JSONValue JSON(string str) {
    JSONValue ret;
    ret.type = JSON_TYPE.STRING;
    ret.str = str;
    return ret;
}

JSONValue JSON(long i) {
    JSONValue ret;
    ret.type = JSON_TYPE.INTEGER;
    ret.integer = i;
    return ret;
}

JSONValue JSON(bool b) {
    JSONValue ret;
    ret.type = b ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
    //ret.str = str;
    return ret;
}

JSONValue JSON(real r) {
    JSONValue ret;
    ret.type = JSON_TYPE.FLOAT;
    ret.floating = r;
    return ret;
}



JSONValue JSON(JSONValue[] v) {
    JSONValue ret;
    ret.type = JSON_TYPE.ARRAY;
    ret.array = v;
    return ret;
}

JSONValue JSON(JSONValue[string] o) {
    JSONValue ret;
    ret.type = JSON_TYPE.OBJECT;
    ret.object = o;
    return ret;
}



