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
// Keep the old direction through small wobbles. The anchor follows the furthest
// point in that direction, so a slow reversal need not cross the original press.
struct DragDirection {
    int anchorX=0,row=1,threshold=8;
    bool determined=false;
    void reset(int x,int distance=8) {
        anchorX=x;row=1;threshold=distance>0?distance:1;determined=false;
    }
    int update(int x) {
        if(!determined) {
            if(x==anchorX) return row;
            row=x<anchorX?2:1;anchorX=x;determined=true;
        } else if(row==1) {
            if(x>anchorX) anchorX=x;
            else if(anchorX-x>=threshold) {row=2;anchorX=x;}
        } else {
            if(x<anchorX) anchorX=x;
            else if(x-anchorX>=threshold) {row=1;anchorX=x;}
        }
        return row;
    }
};
}
