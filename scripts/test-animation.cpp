#include "../windows/Animation.h"
#include <iostream>
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
    std::cout<<"Animation timing, loop boundaries and all16 gaze sectors passed.\n";
}
