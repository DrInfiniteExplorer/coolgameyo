module random.combine;

import random.random;

// Combine!("+")
// Combine!("a < 0 ? a : b"
// Combine!("sin(a)*cos(b)"

alias Combine!("a+b") CombineAdd;
alias Combine!("a-b") CombineSub;
alias Combine!("a*b") CombineMul;
alias Combine!("a/b") CombineDiv;
alias Combine!("a < b ? b : a") CombineMax;
alias Combine!("a > b ? b : a") CombineMin;

class Combine(string operation) : ValueSource {
    ValueSource source;
    ValueSource source2;

    this(ValueSource s, ValueSource s2) {
        source = s;
        source2 = s2;
    }

    double getValue(double x, double y, double z) {

        double a = source.getValue(x, y, z);
        double b = source2.getValue(x, y, z);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }
    double getValue(double x, double y) {
        double a = source.getValue(x, y);
        double b = source2.getValue(x, y);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }
    double getValue(double x) {
        double a = source.getValue(x);
        double b = source2.getValue(x);

        static if(__traits(compiles, "return " ~ operation ~ ";")) {
            mixin("return " ~ operation ~ ";");
        } else {
            pragma(error, "DERP NOOOOO!!!");
        }
    }    
}

