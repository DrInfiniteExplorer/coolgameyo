module random.combine;

import random.valuesource;

// Combine!("+")
// Combine!("a < 0 ? a : b"
// Combine!("sin(a)*cos(b)"

alias Combine!("a+b") CombineAdd;
alias Combine!("a-b") CombineSub;
alias Combine!("a*b") CombineMul;
alias Combine!("a/b") CombineDiv;
alias Combine!("a < b ? b : a") CombineMax;
alias Combine!("a > b ? b : a") CombineMin;


//TODO: Kika på std.functinal.binaryFun och stjäl all kod.

final class Combine(string operation) : ValueSource {
    ValueSource source;
    ValueSource source2;

    this(ValueSource s, ValueSource s2) {
        source = s;
        source2 = s2;
    }

    override double getValue3(vec3d pos) {

        double a = source.getValue3(pos);
        double b = source2.getValue3(pos);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }
    override double getValue2(vec2d pos) {
        double a = source.getValue2(pos);
        double b = source2.getValue2(pos);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }
    override double getValue(double x) {
        double a = source.getValue(x);
        double b = source2.getValue(x);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }    
}

