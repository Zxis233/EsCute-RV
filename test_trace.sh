#!/bin/bash
vvp sim.out 2>&1 | awk '
/MEM|x[0-9]+ +<=/ {
    print $0
}
/85000/ && /WB/ {
    print ">>> CRITICAL TIME 85000 WB STAGE <<<"
    print $0
}
' | head -40
