module gui.debuginfo;

import core.cpuid : threadsPerCPU;


import gui.all;
import util.memory : getMemoryUsage;
import util.util;
import worldstate.block : getBlockMemorySize;

immutable SAMPLE_LIMIT = 256;
__gshared ulong[SAMPLE_LIMIT] memorySamples;
__gshared ulong[SAMPLE_LIMIT] memoryBlockSamples;
__gshared float[SAMPLE_LIMIT] CPUSamples;

shared static this() {
    memorySamples[] = 0;
    memoryBlockSamples[] = 0;
    CPUSamples[] = 0.0;
}

// Should be elsewhere
__gshared ulong lastUs = 0;
__gshared ulong lastTotal = 0;
float getCPUUtilization() {

    import windows : FILETIME, GetProcessTimes, GetCurrentProcess;
    FILETIME creation, exit;
    FILETIME kernel;
    FILETIME user;
    GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user);

    ulong ulKernel = *cast(ulong*)&kernel;
    ulong ulUser = *cast(ulong*)&user;

    ulong total = ulKernel + ulUser;

    ulong diff = total - lastTotal;
    lastTotal = total;

    ulong nowUs = utime();
    ulong diffUs = (nowUs - lastUs) * threadsPerCPU;
    lastUs = nowUs;

    //filetime == X * 100ns = X * 0.1us

    ulong processInUs = diff / 10;

    float percentage = cast(float)processInUs / cast(float)diffUs;
    return percentage;
}

void sampleMemory() {
    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        memorySamples[idx] = memorySamples[idx+1];
    }
    memorySamples[$-1] = getMemoryUsage();

    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        memoryBlockSamples[idx] = memoryBlockSamples[idx+1];
    }
    memoryBlockSamples[$-1] = getBlockMemorySize();

}

void sampleCPU() {
    foreach(idx ; 0 .. SAMPLE_LIMIT-1) {
        CPUSamples[idx] = CPUSamples[idx+1];
    }
    CPUSamples[$-1] = getCPUUtilization();
}


void sampleEverything() {
    sampleMemory();
    sampleCPU();
}


class DebugInfo : GuiElement {

    GuiElementSimpleGraph!ulong memoryGraph;
    GuiElementSimpleGraph!ulong memoryBlockGraph;
    GuiElementSimpleGraph!float CPUGraph;

    this(GuiElement parent) {
        super(parent);
        setRelativeRect(Rectd(0.0, 0.0, 1.0, 1.0));

        memoryGraph = new typeof(memoryGraph)(this, Rectd(0.1, 0, 0.6, 0.25), false);
        memoryBlockGraph = new typeof(memoryGraph)(this, memoryGraph.getRelativeRect, true);
        memoryBlockGraph.setColor(vec3f(0, 1, 0));

        CPUGraph = new typeof(CPUGraph)(this, Rectd(memoryGraph.leftOf, memoryGraph.bottomOf, memoryGraph.widthOf, memoryGraph.heightOf), false);
    }

    bool destroyed = false;
    ~this(){
        BREAK_IF(!destroyed);
    }

    override void destroy() {
        destroyed = true;
    }

    float sampleTime = 0.0f;
    override void tick(float dTime) {
        sampleTime += dTime;
        if(sampleTime > 1.0f) {
            sampleTime -= 1.0f;
            sampleEverything();

            auto memMax = cast(ulong)(reduce!max(memorySamples)*1.1);
            memoryGraph.setData(memorySamples, 0, memMax);
            memoryBlockGraph.setData(memoryBlockSamples, 0, memMax);

            CPUGraph.setData(CPUSamples, 0.0, 1.0);
        }
    }

    



}
