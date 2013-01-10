module util.gc;
//
//import std.c.stdio : printf;
//
//import core.memory;
//import core.thread;
//
//import util.util;
//
//alias BlkInfo_ BlkInfo;
//
//shared uint maxThreadIndex = 0;
//int thisThreadIndex = -1;
//shared int[Thread] threadToIndex;
//shared int[] gcHookEnabled;
//shared int[] gcHookEnabledSize;
//shared int[] gcMallocDebug;
//
//shared uint totalReservedMemory = 0;
//
//alias core.thread.thread_suspendAll suspendAll;
//alias core.thread.thread_resumeAll resumeAll;;
//
//static this() {
//    suspendAll();
//    remove();
//    thisThreadIndex = maxThreadIndex++;
//    threadToIndex[Thread.getThis()] = thisThreadIndex;
//    gcHookEnabled ~= 0;
//    gcHookEnabledSize ~= 0;
//    gcMallocDebug ~= 0;
//    if(installed) install();
//    resumeAll();
//}
//
//void enableGCHook() {
//    gcHookEnabled[thisThreadIndex] += 1;
//}
//void setGCHookSize(int size) {
//    gcHookEnabledSize[thisThreadIndex] = size;
//}
//void disableGCHook() {
//    BREAK_IF(gcHookEnabled[thisThreadIndex] == 0);
//    gcHookEnabled[thisThreadIndex] -= 1;
//}
//void enableMallocDebug() {
//    gcMallocDebug[thisThreadIndex] += 1;
//}
//void disableMallocDebug() {
//    BREAK_IF(gcMallocDebug[thisThreadIndex] == 0);
//    gcMallocDebug[thisThreadIndex] -= 1;
//}
//
//bool shouldBlock() {
//    if(thisThreadIndex == -1) return false;
//    return gcHookEnabled[thisThreadIndex] != 0;
//}
//bool debugMalloc() {
//    if(thisThreadIndex == -1) return false;
//    return gcMallocDebug[thisThreadIndex] != 0;
//}
//
//struct Proxy
//{
//    extern (C) void function() gc_enable;
//    extern (C) void function() gc_disable;
//    extern (C) void function() gc_collect;
//    extern (C) void function() gc_minimize;
//
//    extern (C) uint function(void*) gc_getAttr;
//    extern (C) uint function(void*, uint) gc_setAttr;
//    extern (C) uint function(void*, uint) gc_clrAttr;
//
//    extern (C) void*   function(size_t, uint) gc_malloc;
//    extern (C) BlkInfo function(size_t, uint) gc_qalloc;
//    extern (C) void*   function(size_t, uint) gc_calloc;
//    extern (C) void*   function(void*, size_t, uint ba) gc_realloc;
//    extern (C) size_t  function(void*, size_t, size_t) gc_extend;
//    extern (C) size_t  function(size_t) gc_reserve;
//    extern (C) void    function(void*) gc_free;
//
//    extern (C) void*   function(void*) gc_addrOf;
//    extern (C) size_t  function(void*) gc_sizeOf;
//
//    extern (C) BlkInfo function(void*) gc_query;
//
//    extern (C) void function(void*) gc_addRoot;
//    extern (C) void function(void*, size_t) gc_addRange;
//
//    extern (C) void function(void*) gc_removeRoot;
//    extern (C) void function(void*) gc_removeRange;
//} 
//
//extern (C) {
//    void* gc_getProxy();
//    void gc_setProxy(void* p);
//    void gc_clrProxy();
//}
//
//__gshared Proxy derp;
//__gshared Proxy* orig;
//
//
//
//shared static this() {
//    orig = cast(Proxy*)gc_getProxy();
//    foreach(member ; __traits(allMembers, Proxy)) {
//        mixin("derp." ~ member ~ " = &CGY" ~ member ~ ";\n");
//    }
//}
//
//import std.c.stdio : printf;
//
//__gshared bool installed;
//void installGCHook() {
//    BREAK_IF(installed);
//    install();
//    installed = true;
//}
//
//void removeGCHook() {
//    BREAK_IF(!installed);
//    remove();
//    installed = false;
//}
//
//__gshared bool installing;
//__gshared bool hookedUp;
//private void install() {
//    if(hookedUp) return;
//    suspendAll();
//        installing = true;
//        gc_setProxy(&derp); //Will call some functions. installing is to keep track of that and ignore the calls.
//        hookedUp = true;
//        installing = false;
//    resumeAll();
//}
//
//private void remove() {
//    if(!hookedUp) return;
//    suspendAll();
//    installing = true;
//    gc_clrProxy();
//    installing = false;
//    hookedUp = false;
//    resumeAll();
//}
//
//void halt(int q) {
//    if(shouldBlock()) {
//        if(q >= gcHookEnabledSize[thisThreadIndex]) {
//            asm { int 3; }
//        }
//    }
//}
//
//extern (C) void CGYgc_enable() {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    orig.gc_enable();
//    install();
//}
//extern (C) void CGYgc_disable(){
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    orig.gc_disable();
//    install();
//}
//extern (C) void CGYgc_collect() {
//    printf("collecting!!!!\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
//    suspendAll();
//    scope(exit) resumeAll();
//    asm { int 3; }
//    remove();
//    orig.gc_collect();
//    install();
//}
//extern (C) void CGYgc_minimize() {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    orig.gc_minimize();
//    install();
//}
//
//extern (C) uint CGYgc_getAttr(void* p) {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    return orig.gc_getAttr(p);
//    
//}
//extern (C) uint CGYgc_setAttr(void* q, uint w) {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    return orig.gc_setAttr(q, w);
//}
//extern (C) uint CGYgc_clrAttr(void* q, uint w) {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    return orig.gc_clrAttr(q, w);
//}
//
//extern (C) void*   CGYgc_malloc(size_t q, uint w) {
//    halt(q);
//
//    typeof(return) ret;
//    {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    ret = orig.gc_malloc(q, w);
//    totalReservedMemory += orig.gc_sizeOf(ret);
//    }
//    if(debugMalloc()) {
//        printf("Malloc: %d\t-> %d\n", q,  totalReservedMemory/1024);
//    }
//    return ret;
//    
//}
//extern (C) BlkInfo CGYgc_qalloc(size_t q, uint w) {
//    halt(q);
//    typeof(return) ret;
//    {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    ret = orig.gc_qalloc(q, w);
//    totalReservedMemory += orig.gc_sizeOf(ret.base);
//    }
//    if(debugMalloc()) {
//        printf("qalloc: %d\t-> %d\n", q, totalReservedMemory/1024);
//    }
//    return ret;
//    
//}
//extern (C) void*   CGYgc_calloc(size_t q, uint w) {
//    halt(q);
//    typeof(return) ret;
//    {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    ret = orig.gc_calloc(q, w);
//    totalReservedMemory += orig.gc_sizeOf(ret);
//    }
//    if(debugMalloc()) {
//        printf("calloc: %d\t-> %d\n", q, totalReservedMemory/1024);
//    }
//    return ret;    
//}
//extern (C) void*   CGYgc_realloc(void* q, size_t w, uint ba) {
//    halt(w);
//    typeof(return) ret;
//    {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//
//    if(q) {
//        totalReservedMemory -= orig.gc_sizeOf(q);
//    }
//    ret = orig.gc_realloc(q, w, ba);
//    totalReservedMemory += orig.gc_sizeOf(ret);
//    }
//    if(debugMalloc()) {
//        printf("realloc: %d\t-> %d\n", q, totalReservedMemory/1024);
//    }
//    return ret;
//    
//}
//extern (C) size_t  CGYgc_extend(void* q, size_t w, size_t e) {
//    halt(w);
//    typeof(return) ret;
//    {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    if(q) {
//        totalReservedMemory -= orig.gc_sizeOf(q);
//    }
//    ret = orig.gc_extend(q, w, e);
//    totalReservedMemory += orig.gc_sizeOf(q);
//    }
//    if(debugMalloc()) {
//        printf("extend: %d\t-> %d\n", q, totalReservedMemory/1024);
//    }
//    return ret;
//    
//}
//extern (C) size_t  CGYgc_reserve(size_t q) {
//    halt(q);
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    return orig.gc_reserve(q);
//    
//}
//extern (C) void    CGYgc_free(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//    remove();
//    scope(exit) install();
//    totalReservedMemory -= orig.gc_sizeOf(q);
//    return orig.gc_free(q);
//    
//}
//
//extern (C) void*   CGYgc_addrOf(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        remove();
//        scope(exit) install();
//        return orig.gc_addrOf(q);
//    
//}
//extern (C) size_t  CGYgc_sizeOf(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        remove();
//        scope(exit) install();
//        return orig.gc_sizeOf(q);
//    
//}
//
//extern (C) BlkInfo CGYgc_query(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        remove();
//        scope(exit) install();
//        return orig.gc_query(q);
//    
//}
//
//extern (C) void CGYgc_addRoot(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        if(installing) return;
//        remove();
//        scope(exit) install();
//        return orig.gc_addRoot(q);
//    
//}
//extern (C) void CGYgc_addRange(void* q, size_t w) {
//    suspendAll();
//    scope(exit) resumeAll();
//        if(installing) return;
//        remove();
//        scope(exit) install();
//        return orig.gc_addRange(q, w);
//    
//}
//
//extern (C) void CGYgc_removeRoot(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        if(installing) return;
//        remove();
//        scope(exit) install();
//        return orig.gc_removeRoot(q);
//    
//}
//extern (C) void CGYgc_removeRange(void* q) {
//    suspendAll();
//    scope(exit) resumeAll();
//        if(installing) return;
//        remove();
//        scope(exit) install();
//        return orig.gc_removeRange(q);
//    
//}
//
