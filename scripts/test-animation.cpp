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
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,2,false)==4,"Two jumps then think at 100");
      check(behavior.update(100.2,true,true,true,20,3,false)==-1,"Two jumps then think at 100.2");
      check(behavior.update(100.85,true,true,false,20,3,false)==4,"Two jumps then think at 100.85");
      check(behavior.update(101.1,true,true,true,20,3,false)==-1,"Two jumps then think at 101.1");
      check(behavior.update(101.7,true,true,false,20,3,false)==7,"Two jumps then think at 101.7");
      check(behavior.update(130,true,true,false,20,3,false)==-1,"Two jumps then think at 130");
      check(behavior.update(131,false,true,false,20,2,false)==-1,"Two jumps then think at 131");
      check(behavior.update(132,true,true,false,20,2,false)==4,"Two jumps then think at 132");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,3,false)==4,"Three jumps then think at 100");
      check(behavior.update(100.85,true,true,false,20,2,false)==4,"Three jumps then think at 100.85");
      check(behavior.update(101.7,true,true,false,20,2,false)==4,"Three jumps then think at 101.7");
      check(behavior.update(102.55,true,true,false,20,2,false)==7,"Three jumps then think at 102.55");
      check(behavior.update(130,true,true,false,20,2,false)==-1,"Three jumps then think at 130");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,3,false)==4,"Leave cancels and cooldown holds at 100");
      check(behavior.update(100.2,false,true,true,20,3,false)==-1,"Leave cancels and cooldown holds at 100.2");
      check(behavior.update(101,false,true,false,20,3,false)==-1,"Leave cancels and cooldown holds at 101");
      check(behavior.update(102,true,true,false,20,3,false)==-1,"Leave cancels and cooldown holds at 102");
      check(behavior.update(103,true,true,false,20,3,false)==-1,"Leave cancels and cooldown holds at 103");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,3,false)==4,"Disable cancels at 100");
      check(behavior.update(100.2,true,false,true,20,3,false)==-1,"Disable cancels at 100.2");
      check(behavior.update(101,true,true,false,20,3,false)==-1,"Disable cancels at 101");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,3,false)==4,"Drag cancels at 100");
      check(behavior.update(100.2,true,true,true,20,3,true)==-1,"Drag cancels at 100.2");
      check(behavior.update(101,true,true,false,20,3,false)==-1,"Drag cancels at 101");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,false,true,false,20,2,false)==-1,"Idle and resume at 100");
      check(behavior.update(119,false,true,false,20,2,false)==-1,"Idle and resume at 119");
      check(behavior.update(120,false,true,false,20,2,false)==7,"Idle and resume at 120");
      check(behavior.update(121,false,true,true,20,2,false)==-1,"Idle and resume at 121");
      check(behavior.update(140,false,true,false,20,2,false)==-1,"Idle and resume at 140");
      check(behavior.update(141,false,true,false,20,2,false)==7,"Idle and resume at 141");
      check(behavior.update(142,false,false,false,20,2,false)==-1,"Idle and resume at 142");
      check(behavior.update(200,false,false,false,20,2,false)==-1,"Idle and resume at 200");
      check(behavior.update(201,false,true,false,20,2,false)==-1,"Idle and resume at 201");
      check(behavior.update(220,false,true,false,20,2,false)==7,"Idle and resume at 220");
    }
    { huhu::Behavior behavior;
      check(behavior.update(100,true,true,false,20,3)==4,"Manual override setup");
      behavior.cancel();
      check(behavior.update(101,true,true,false,20,3)==-1,"Manual override cancels queued moves");
    }
    huhu::DragDirection drag;
    drag.reset(100);
    check(drag.update(90)==2,"Initial left drag");
    for(int x:{91,89,92,88,93,87,94,90,87})
        check(drag.update(x)==2,"Jitter must preserve left direction");
    for(int x=88;x<95;++x)
        check(drag.update(x)==2,"Slow reversal accumulates without premature switch");
    check(drag.update(95)==1,"Eight pixel right reversal before original press position");
    check(drag.update(95)==1,"Vertical motion preserves right");
    check(drag.update(120)==1,"Right anchor follows the drag");
    for(int x=119;x>112;--x)
        check(drag.update(x)==1,"Slow left reversal retains right below threshold");
    check(drag.update(112)==2,"Eight pixel left reversal above original press position");
    for(int x:{113,111,114,110,115,109,116,109})
        check(drag.update(x)==2,"Jitter after reversal must preserve left");
    drag.reset(100,16);
    check(drag.update(120)==1,"High DPI initial direction");
    check(drag.update(105)==1,"High DPI scales the buffer");
    check(drag.update(104)==2,"High DPI reversal at scaled threshold");
    drag.reset(100);
    check(drag.update(100)==1,"New drag resets direction");
    check(drag.update(99)==2,"New drag can initially move left");

    std::cout<<"Drag reversals, hover jump/think sequences, cooldown, idle scheduling, suppression, animation timing, loop boundaries and all16 gaze sectors passed.\n";
}
