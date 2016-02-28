
module cgy.opengl.types;

import derelict.opengl3.gl;

uint TypeToGLTypeEnum(Type)() {
    static if( is(Type == void)) return GL_UNSIGNED_BYTE; // Huerr hurr
    else static if( is(Type == ubyte)) return GL_UNSIGNED_BYTE;
    else static if( is(Type == byte)) return GL_BYTE;
    else static if( is(Type == ushort)) return GL_UNSIGNED_SHORT;
    else static if( is(Type == short)) return GL_SHORT;
    else static if( is(Type == uint)) return GL_UNSIGNED_INT;
    else static if( is(Type == int)) return GL_INT;
    else static if( is(Type == float)) return GL_FLOAT;
    else {
        static assert(0, "Cant produce opengl type enum from type " ~ Type);
    }
}

auto TypeToGLInternalType(Type)() {
    static if( is( Type == float) || is( Type == float[1])) {
        return GL_R32F;
    } else static if( is( Type == float[2])) {
        return GL_RG32F;
    } else static if( is( Type == float[3])) {
        return GL_RGB32F;
    } else static if( is( Type == float[4])) {
        return GL_RGBA32F;
    } else {
        pragma(msg, Type);
        static assert(0, "Type unrecognized!");
    }
    assert(0);
}

uint InternalTypeToFormatType(uint Type) {
    if(Type == GL_RGBA8) return GL_RGBA;
    else if(Type == GL_R16F) return GL_RED;
    else if(Type == GL_R32F) return GL_RED;
    else if(Type == GL_RG16F) return GL_RG;
    else if(Type == GL_RG32F) return GL_RG;
    else if(Type == GL_RGBA16F) return GL_RGBA;
    else if(Type == GL_RGBA32F) return GL_RGBA;
    else {
        asm { int 3; }
        assert(0, "Unknown mapping: " ~ Type.stringof);
    }
}

uint InternalTypeToSize(uint Type) {
    if(Type == GL_RGBA8) return 4;
    else if(Type == GL_R16F) return 2;
    else if(Type == GL_R32F) return 4;
    else if(Type == GL_RG16F) return 4;
    else if(Type == GL_RG32F) return 8;
    else if(Type == GL_RGBA16F) return 8;
    else if(Type == GL_RGBA32F) return 16;
    else {
        asm { int 3; }
        assert(0, "Unknown mapping: " ~ Type.stringof);
    }
}
