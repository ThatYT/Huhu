#pragma once
#include <array>
#include <cmath>
#include <vector>

namespace huhu {
inline constexpr std::array<int, 11> counts{6,8,8,4,5,8,6,6,6,8,8};
inline const std::array<std::vector<double>, 9> timing{{
    {.28,.11,.11,.14,.14,.32}, {.12,.12,.12,.12,.12,.12,.12,.22},
    {.12,.12,.12,.12,.12,.12,.12,.22}, {.14,.14,.14,.28}, {.14,.14,.14,.14,.28},
    {.14,.14,.14,.14,.14,.14,.14,.24}, {.15,.15,.15,.15,.15,.26},
    {.12,.12,.12,.12,.12,.22}, {.15,.15,.15,.15,.15,.28}
}};
inline double length(int row) { double result=0; for(auto t:timing.at(row)) result+=t; return result; }
inline int frame(double elapsed,int row) {
    double phase=std::fmod(elapsed,length(row));
    for(int i=0;i<int(timing.at(row).size());++i) { if(phase<timing[row][i]) return i; phase-=timing[row][i]; }
    return 0;
}
// Screen coordinates: y increases downward. Zero means above Huhu.
inline int direction(double dx,double dy) {
    constexpr double pi=3.14159265358979323846;
    double angle=std::atan2(dx,-dy);
    if(angle<0) angle+=2*pi;
    return int(std::lround(angle/(pi/8)))%16;
}
}
