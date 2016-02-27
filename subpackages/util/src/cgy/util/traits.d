module cgy.util.traits;


import std.traits : ParameterTypeTuple;
import std.typetuple : Filter;

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


const(TypeInfo_Class) isDerivedClass(string base, string derived) {
    bool check(const TypeInfo_Class base, const TypeInfo_Class derived) {
        if(base is derived) {
            return true;
        }
        if(derived.base is null) return false;
        return check(base, derived.base);
    }
    auto baseInfo = TypeInfo_Class.find(base);
    auto derivedInfo = TypeInfo_Class.find(derived);
    return check(baseInfo, derivedInfo) ? derivedInfo : null;
}

BaseType safeFactory(BaseType, alias DerivedType)() {
    auto baseClassName = BaseType.classinfo.name;
    //    pragma(msg, typeof(DerivedType));
    static if( is( typeof(DerivedType) : string)) {
        alias DerivedType derivedClassName;
    } else {
        auto derivedClassName = typeof(DerivedType).classinfo.name;
    }
    auto type = isDerivedClass(baseClassName, derivedClassName);
    if(type is null) {

        return null;
    }
    Object o = type.create();
    enforce(o, "Could not create class of class-type " ~ derivedClassName);
    BaseType t = cast(BaseType) o;
    enforce(t, "Could not cast to base class-type " ~ baseClassName);
    return t;
}

template RealMembers(T) {
    import std.traits : isSomeFunction;
    T t;
    template RealShit(string thing) {
        // Things which have no type are not real things
        static if(!__traits(compiles, typeof(__traits(getMember, t, thing)))) {
            enum RealShit = false;

        // Things which are functions are not real things
        } else static if(isSomeFunction!(typeof(__traits(getMember, t, thing)))) {
            enum RealShit = false;

        // Things which masquerade as real things but are functions are not real things.
        } else static if(isSomeFunction!(typeof(&__traits(getMember, t, thing)))) {
            enum RealShit = false;
        } else {
            enum RealShit = true;
        }
    }
    alias Filter!(RealShit, __traits(allMembers, T)) RealMembers;
}

unittest {
    import cgy.util.pos;
    import cgy.util.util;
    foreach(member ; RealMembers!EntityPos) {
        msg(member);
    }
}

unittest {
    struct A{
        int a, b;
    }
    A a;
    import cgy.util.util : BREAK_IF;
    a.tupleof[0] = 2;
    BREAK_IF(a.a != 2);
}
