#include "../windows/Animation.h"
#include <iostream>
#include "../windows/Behavior.h"
#include <cstdlib>
void check(bool condition,const char* message) {if(!condition){std::cerr<<message<<'\n';std::exit(1);}}
int main() {
    int total=0;for(int n:huhu::counts) total+=n;
    check(total==73,"Expected 73 frames");
    constexpr double pi=3.14159265358979323846;
    for(int d=0;d<16;++d) {
        double angle=d*pi/8;
        check(huhu::direction(std::sin(angle)*100,-std::cos(angle)*100)==d,"Incorrect gaze sector");
    }
    check(huhu::direction(-.01,-100)==0,"Wraparound near up failed");
    for(int row=0;row<9;++row) {
        double elapsed=0;
        for(int frame=0;frame<huhu::counts[row];++frame) {
            check(huhu::frame(elapsed+huhu::timing[row][frame]*.5,row)==frame,"Wrong timed frame");
            elapsed+=huhu::timing[row][frame];
        }
        check(huhu::frame(elapsed+.001,row)==0,"Loop restart failed");
    }
    huhu::Behavior behavior;
    check(behavior.update(100,false,true,false,20,false)==-1,"Initial idle");
    check(behavior.update(119,false,true,false,20,false)==-1,"No early thought");
    check(behavior.update(120,false,true,false,20,false)==7,"Idle thought");
    check(behavior.update(121,false,true,true,20,false)==-1,"Busy inhibits");
    check(behavior.update(122,true,true,false,20,false)==3,"Hover waves");
    check(behavior.update(140,true,true,false,20,true)==-1,"Stationary hover never repeats");
    check(behavior.update(141,false,true,false,20,false)==-1,"Leave");
    check(behavior.update(142,true,true,false,20,true)==4,"New entry jumps");
    check(behavior.update(143,false,true,false,20,false)==-1,"Leave again");
    check(behavior.update(144,true,true,false,20,true)==-1,"Cooldown inhibits");
    check(behavior.update(145,false,false,false,20,false)==-1,"Hidden paused or reduced motion inhibits");
    check(behavior.update(200,false,false,false,20,false)==-1,"Disabled time not idle");
    check(behavior.update(201,false,true,false,20,false)==-1,"No catchup on resume");
    check(behavior.update(220,false,true,false,20,false)==7,"Fresh idle after resume");
    check(behavior.update(221,true,true,true,20,false)==-1,"Dragging does not greet");
    check(behavior.update(222,true,true,false,20,false)==-1,"No delayed greeting after drag");
    check(behavior.update(223,false,true,true,20,false)==-1,"Manual animation resets idle");
    check(behavior.update(242,false,true,false,20,false)==-1,"No early thought after manual animation");
    check(behavior.update(243,false,true,false,20,false)==7,"Think after fresh idle");
    std::cout<<"Hover, cooldown, idle scheduling, suppression, animation timing, loop boundaries and all16 gaze sectors passed.\n";
}
