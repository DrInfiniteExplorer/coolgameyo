module cgy.util.singleton;


mixin template Singleton(string modifier = "__gshared") {
    mixin("static " ~ modifier ~ " typeof(this) s_Instance = null;");

    static getInstance() {
        if(s_Instance is null) {
            /*
            import std.conv : emplace;
            import cgy.util.memory : allocateBlob;
            alias typeof(this) T;
            pragma(msg, T.sizeof);
            pragma(msg, T.stringof);
            auto ptr = allocateBlob(1, T.sizeof);
            return emplace!(T)(ptr);
            /*/
            s_Instance = new typeof(this);
            //*/
        }
        return s_Instance;
    }

    static opCall() {
        return getInstance();
    }
}

