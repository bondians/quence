#include "flibby.h"

top:
        mmove   Intensity, #Lo, #Even
        mmove   Intensity, #Hi, #Odd

        wait    #Time

        mxor	Intensity, #$ff, #$ff

        jmp     top
