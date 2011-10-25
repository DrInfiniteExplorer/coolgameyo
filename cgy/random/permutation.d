module random.permutation;


import util.util;
import random.random;
import random.randsource;


mixin template Permutation(alias SIZE) {
import std.conv;
import util.math;
    uint[] permutations;
    
    void initPermutations(RandSourceUniform rsu) {
        permutations.length = SIZE;
        uint[] src;
        src.length = SIZE;
        foreach( i ; 0 .. SIZE){
            src[i] = i;
        }
        foreach( i ; 0 .. SIZE-1){
            uint idx = rsu.get!uint(0, SIZE-i-1);
            permutations[i] = src[idx];
            src[idx] = src[SIZE-i-1];
        }
        permutations[SIZE-1] = src[0];
    }
    
    uint Perm(int i) {
        return permutations[posMod(i, SIZE)]; //Move posmod to getValue, cast to uint, then use % ?
    }
    
    uint Index(int i, int j, int k) {
        return Perm( i + Perm(j + Perm(k)));
    }
    uint Index(int i, int j) {
        return Perm( i + Perm(j));
    }
    uint Index(int i) {
        return Perm( i );
    }
    
    uint Index(double x, double y, double z) {
        return Index(to!int(x), to!int(y), to!int(z));
    }
    uint Index(double x, double y) {
        return Index(to!int(x), to!int(y));
    }
    uint Index(double x) {
        return Index(to!int(x));
    }
    
}



class PermMap(uint SIZE = 128) : ValueSource {
    double[SIZE] PRNs;
    mixin Permutation!SIZE;

    this(RandSourceUniform rsu) {
        initPermutations(rsu);
        foreach(ref p ; PRNs) {
            p = rsu.getValue(0, 0);
        }
    }
    
    double getValue(double x, double y, double z) {
        return PRNs[Index(x, y, z)];
    }
    double getValue(double x, double y) {
        return PRNs[Index(x, y)];
    }
    double getValue(double x) {
        return PRNs[Index(x)];
    }
};
