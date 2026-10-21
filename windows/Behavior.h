#pragma once
namespace huhu {
// Monotonic seconds. The resting silhouette keeps jump motion from creating entries.
struct Behavior {
    bool inside=false,thinkPending=false;
    int jumpsPending=0;
    double nextGreeting=0,nextThink=0;
    void cancel() {jumpsPending=0;thinkPending=false;}
    int update(double now,bool over,bool enabled,bool busy,double delay,int jumps,bool interacting=false) {
        bool entered=over && !inside; inside=over;
        if(nextThink==0 || !enabled || busy || interacting || over) nextThink=now+delay;
        if(!enabled || interacting || !over) cancel();
        if(!enabled || busy || interacting) return -1;
        if(entered && now>=nextGreeting) {
            nextGreeting=now+8; nextThink=now+delay;
            jumpsPending=jumps==3?2:1;thinkPending=true;return 4;
        }
        if(jumpsPending>0) {--jumpsPending;return 4;}
        if(thinkPending) {thinkPending=false;return 7;}
        if(!over && now>=nextThink) {nextThink=now+delay;return 7;}
        return -1;
    }
};
// Track successive screen coordinates, including one-pixel reversals.
struct DragDirection {
    int previousX=0,row=1;
    void reset(int x) {previousX=x;row=1;}
    int update(int x) {
        if(x!=previousX) row=x<previousX?2:1;
        previousX=x;return row;
    }
};
}
