module util.traits;


import std.traits : ParameterTypeTuple;

// Implementera ett template för att få alla variabel-medlemmar ur en klass.


// Tries to call a function with X parameters. If it failes, tries to
//  
auto tryCall(alias Func, Us...)(Us us) {
    alias ParameterTypeTuple!Func PTT;
    static if( is(PTT == Us)) {
        return Func(us);
    } else static if (PTT.length == 1) {
        return Func( PTT[0](us) );
    } else static if(Us.length == 1 && is(Us[0] == struct)) {
        return Func(us[0].tupleof);
    } else {
        pragma(msg, "Sorry cant call this func like that :( Maybe make things more confusing with recursive herpiderps?");
        static assert(0);
    }
}

T DownwardDelegate(T)(scope T t) if( is(T == delegate)) {
    return t;
}
