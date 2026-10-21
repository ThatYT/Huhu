#pragma once
namespace huhu {
// Monotonic seconds. A stable resting silhouette prevents animation motion from
// manufacturing pointer entries. Busy/disabled time never counts as idle.
struct Behavior {
    bool inside=false;
    double nextGreeting=0,nextThink=0;
    int update(double now,bool over,bool enabled,bool busy,double delay,bool jump) {
        bool entered=over && !inside; inside=over;
        if(nextThink==0 || !enabled || busy || over) nextThink=now+delay;
        if(!enabled || busy) return -1;
        if(entered && now>=nextGreeting) {
            nextGreeting=now+8; nextThink=now+delay; return jump?4:3;
        }
        if(!over && now>=nextThink) {nextThink=now+delay;return 7;}
        return -1;
    }
};
}
