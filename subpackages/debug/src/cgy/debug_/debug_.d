module cgy.debug_.debug_;

void BREAK_IF(uint doBreak) {
    if(doBreak) {
        asm { int 3; }
    }
}
void BREAKPOINT() {
    asm { int 3; }
}
