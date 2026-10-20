#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <gdiplus.h>
#include <algorithm>
#include <cstring>
#include <memory>
#include <string>
#include "Animation.h"
#include "Startup.h"

using namespace Gdiplus;
constexpr wchar_t windowClass[]=L"HuhuDesktopCompanion";
constexpr UINT trayMessage=WM_APP+1;
enum {ShowHide=100,Wave=103,Jump=104,Think=107,Review=108,Ask=106,Shy=105,
      RunRight=101,RunLeft=102,Follow=115,Pause=116,Small=185,Medium=220,Large=260,
      Reset=122,Help=123,Quit=124,Startup=125};

struct App {
    HWND window=nullptr;
    HINSTANCE instance=nullptr;
    IStream* stream=nullptr;
    std::unique_ptr<Bitmap> art;
    NOTIFYICONDATAW tray{};
    HDC memoryDC=nullptr;
    HBITMAP dib=nullptr;
    HGDIOBJ oldBitmap=nullptr;
    void* pixels=nullptr;
    int width=0,height=0,dpi=96,lastRow=-1,lastCol=-1;
    double scale=1.2;
    bool follow=true,paused=false,visible=true,dragging=false,pressed=false,reducedMotion=false;
    int action=-1,dragRow=1;
    POINT press{},original{};
    ULONGLONG started=GetTickCount64(),actionStart=0;
    std::wstring ini;

    ~App() {
        Shell_NotifyIconW(NIM_DELETE,&tray);
        clearSurface(); art.reset(); if(stream) stream->Release();
    }
    bool loadArtwork() {
        HRSRC resource=FindResourceW(instance,MAKEINTRESOURCEW(101),RT_RCDATA);
        if(!resource) return false;
        HGLOBAL data=LoadResource(instance,resource);
        stream=SHCreateMemStream(static_cast<const BYTE*>(LockResource(data)),SizeofResource(instance,resource));
        if(!stream) return false;
        art=std::make_unique<Bitmap>(stream,FALSE);
        return art->GetLastStatus()==Ok && art->GetWidth()==1536 && art->GetHeight()==2288;
    }
    void readSettings() {
        wchar_t path[MAX_PATH]{};
        if(SUCCEEDED(SHGetFolderPathW(nullptr,CSIDL_LOCAL_APPDATA,nullptr,0,path))) {
            std::wstring folder=std::wstring(path)+L"\\Huhu";
            CreateDirectoryW(folder.c_str(),nullptr); ini=folder+L"\\settings.ini";
            int percent=GetPrivateProfileIntW(L"Huhu",L"Scale",120,ini.c_str());
            if(percent==85 || percent==120 || percent==160) scale=percent/100.0;
            follow=GetPrivateProfileIntW(L"Huhu",L"Follow",1,ini.c_str())!=0;
        }
    }
    void save() {
        if(ini.empty() || !window) return;
        RECT rect{}; GetWindowRect(window,&rect);
        for(auto pair:{std::pair<const wchar_t*,int>{L"X",rect.left},{L"Y",rect.top},
                       {L"Scale",int(std::lround(scale*100))},{L"Follow",follow?1:0}}) {
            auto value=std::to_wstring(pair.second);
            WritePrivateProfileStringW(L"Huhu",pair.first,value.c_str(),ini.c_str());
        }
    }
    void readMotionPreference() {
        BOOL enabled=TRUE; SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION,0,&enabled,0); reducedMotion=!enabled;
    }
    void clearSurface() {
        if(memoryDC && oldBitmap) SelectObject(memoryDC,oldBitmap);
        if(dib) DeleteObject(dib);
        if(memoryDC) DeleteDC(memoryDC);
        memoryDC=nullptr; dib=nullptr; oldBitmap=nullptr; pixels=nullptr;
    }
    bool surface() {
        clearSurface(); width=int(std::lround(192*scale*dpi/96.0)); height=int(std::lround(208*scale*dpi/96.0));
        BITMAPINFO info{}; info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
        info.bmiHeader.biWidth=width; info.bmiHeader.biHeight=-height;
        info.bmiHeader.biPlanes=1; info.bmiHeader.biBitCount=32; info.bmiHeader.biCompression=BI_RGB;
        memoryDC=CreateCompatibleDC(nullptr);
        if(!memoryDC) return false;
        dib=CreateDIBSection(memoryDC,&info,DIB_RGB_COLORS,&pixels,nullptr,0);
        if(!dib) {clearSurface();return false;}
        oldBitmap=SelectObject(memoryDC,dib); lastRow=lastCol=-1;
        return true;
    }
    bool render(int row,int column) {
        if(!pixels || !art) return false;
        std::memset(pixels,0,size_t(width)*height*4);
        Bitmap canvas(width,height,width*4,PixelFormat32bppPARGB,static_cast<BYTE*>(pixels));
        {
            Graphics g(&canvas); g.SetCompositingMode(CompositingModeSourceCopy);
            g.SetInterpolationMode(InterpolationModeHighQualityBicubic);
            g.SetPixelOffsetMode(PixelOffsetModeHalf);
            if(g.DrawImage(art.get(),Rect(0,0,width,height),column*192,row*208,192,208,UnitPixel)!=Ok) return false;
        }
        RECT r{}; GetWindowRect(window,&r); POINT position{r.left,r.top},source{0,0}; SIZE size{width,height};
        BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};
        bool result=UpdateLayeredWindow(window,nullptr,&position,&size,memoryDC,&source,0,&blend,ULW_ALPHA)!=FALSE;
        lastRow=row;lastCol=column; return result;
    }
    void tick() {
        if(!visible || paused) return;
        auto now=GetTickCount64(); int row=0,column=0;
        if(dragging) {row=dragRow;column=huhu::frame((now-started)/1000.0,row);}
        else if(action>=0) {
            double elapsed=(now-actionStart)/1000.0;
            if(elapsed<huhu::length(action)) {row=action;column=huhu::frame(elapsed,row);} else action=-1;
        }
        if(row==0) {
            column=huhu::frame((now-started)/1000.0,0);
            if(follow && !reducedMotion) {
                POINT mouse{};GetCursorPos(&mouse);RECT r{};GetWindowRect(window,&r);
                double dx=mouse.x-(r.left+width/2.0),dy=mouse.y-(r.top+height*.38);
                double distance=std::hypot(dx,dy),factor=scale*dpi/96.0;
                if(distance>65*factor && distance<650*factor) {int d=huhu::direction(dx,dy);row=9+d/8;column=d%8;}
            }
        }
        if(reducedMotion) row=column=0;
        if(lastRow!=row || lastCol!=column) render(row,column);
    }
    void play(int row) {paused=false;visible=true;ShowWindow(window,SW_SHOWNOACTIVATE);action=row;actionStart=GetTickCount64();tick();}
    void clamp() {
        MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor);
        RECT r{};GetWindowRect(window,&r);
        int x=std::clamp(int(r.left),int(monitor.rcWork.left),std::max(int(monitor.rcWork.left),int(monitor.rcWork.right)-width));
        int y=std::clamp(int(r.top),int(monitor.rcWork.top),std::max(int(monitor.rcWork.top),int(monitor.rcWork.bottom)-height));
        SetWindowPos(window,HWND_TOPMOST,x,y,width,height,SWP_NOACTIVATE);
    }
    void reset() {
        MONITORINFO monitor{};monitor.cbSize=sizeof(monitor);GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTOPRIMARY),&monitor);
        SetWindowPos(window,HWND_TOPMOST,monitor.rcWork.right-width-40,monitor.rcWork.bottom-height-20,width,height,SWP_NOACTIVATE);
        clamp();save();
    }
    void addTray() {
        tray.cbSize=sizeof(tray);tray.hWnd=window;tray.uID=1;tray.uFlags=NIF_MESSAGE|NIF_ICON|NIF_TIP;
        tray.uCallbackMessage=trayMessage;tray.hIcon=LoadIconW(instance,MAKEINTRESOURCEW(1));
        lstrcpyW(tray.szTip,L"Huhu · 呼呼");Shell_NotifyIconW(NIM_ADD,&tray);
    }
    void command(int id) {
        if(id>=101 && id<=108) {play(id-100);return;}
        switch(id) {
        case ShowHide: visible=!visible;ShowWindow(window,visible?SW_SHOWNOACTIVATE:SW_HIDE);break;
        case Follow:follow=!follow;save();break;
        case Pause:paused=!paused;if(!paused) {started=GetTickCount64();action=-1;}break;
        case Small:case Medium:case Large: {
            RECT r{};GetWindowRect(window,&r);int oldW=width,oldH=height;
            scale=id==Small?.85:id==Medium?1.2:1.6;surface();
            SetWindowPos(window,HWND_TOPMOST,r.left+(oldW-width)/2,r.top+oldH-height,width,height,SWP_NOACTIVATE);
            clamp();render(std::max(lastRow,0),std::max(lastCol,0));save();break;
        }
        case Reset:reset();break;
        case Startup: {
            LSTATUS error=startup::set(!startup::registered());
            if(error!=ERROR_SUCCESS) {
                wchar_t* detail=nullptr;
                FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER|FORMAT_MESSAGE_FROM_SYSTEM|FORMAT_MESSAGE_IGNORE_INSERTS,
                    nullptr,DWORD(error),0,reinterpret_cast<wchar_t*>(&detail),0,nullptr);
                std::wstring message=L"Couldn’t change Run at startup.\n\n";
                message+=detail?detail:L"Please try again from an installed copy of Huhu.";
                if(detail) LocalFree(detail);
                MessageBoxW(window,message.c_str(),L"Huhu",MB_OK|MB_ICONERROR);
            }
            break;
        }
        case Help:MessageBoxW(window,L"Drag to move. Click to wave. Double-click to jump.\n\nHuhu looks toward nearby pointers. Right-click or use the tray icon for size, pause, hide, and quit.\n\nNo ChatGPT, login, internet, or API key needed.",L"Huhu · 呼呼",MB_OK|MB_ICONINFORMATION);break;
        case Quit:DestroyWindow(window);break;
        }
    }
    void menu() {
        HMENU m=CreatePopupMenu(),sizes=CreatePopupMenu(),more=CreatePopupMenu();
        AppendMenuW(m,MF_STRING|MF_DISABLED,0,L"Huhu · 呼呼");
        AppendMenuW(m,MF_STRING,ShowHide,visible?L"Hide Huhu":L"Show Huhu");
        AppendMenuW(m,MF_SEPARATOR,0,nullptr);
        AppendMenuW(m,MF_STRING,Wave,L"Wave");AppendMenuW(m,MF_STRING,Jump,L"Jump");
        for(auto p:{std::pair<int,const wchar_t*>{Think,L"Think"},{Review,L"Check something"},{Ask,L"Ask nicely"},
                    {Shy,L"Feeling shy"},{RunRight,L"Run right"},{RunLeft,L"Run left"}}) AppendMenuW(more,MF_STRING,p.first,p.second);
        AppendMenuW(m,MF_POPUP,reinterpret_cast<UINT_PTR>(more),L"More animations");
        AppendMenuW(m,MF_SEPARATOR,0,nullptr);
        AppendMenuW(m,MF_STRING|(follow?MF_CHECKED:0),Follow,L"Follow pointer");
        AppendMenuW(m,MF_STRING,Pause,paused?L"Resume animation":L"Pause animation");
        AppendMenuW(sizes,MF_STRING|(scale==.85?MF_CHECKED:0),Small,L"Small");
        AppendMenuW(sizes,MF_STRING|(scale==1.2?MF_CHECKED:0),Medium,L"Medium");
        AppendMenuW(sizes,MF_STRING|(scale==1.6?MF_CHECKED:0),Large,L"Large");
        AppendMenuW(m,MF_POPUP,reinterpret_cast<UINT_PTR>(sizes),L"Size");
        AppendMenuW(m,MF_STRING,Reset,L"Reset position");AppendMenuW(m,MF_SEPARATOR,0,nullptr);
        AppendMenuW(m,MF_STRING|(startup::registered()?MF_CHECKED:0),Startup,L"Run at startup");
        AppendMenuW(m,MF_SEPARATOR,0,nullptr);
        AppendMenuW(m,MF_STRING,Help,L"How to play");AppendMenuW(m,MF_STRING,Quit,L"Quit Huhu");
        POINT point{};GetCursorPos(&point);SetForegroundWindow(window);
        int chosen=TrackPopupMenu(m,TPM_RETURNCMD|TPM_RIGHTBUTTON,point.x,point.y,0,window,nullptr);
        PostMessageW(window,WM_NULL,0,0);DestroyMenu(m);if(chosen) command(chosen);
    }
};

App* current=nullptr;
LRESULT CALLBACK procedure(HWND window,UINT message,WPARAM wp,LPARAM lp) {
    if(!current) return DefWindowProcW(window,message,wp,lp);
    auto& a=*current;
    static UINT taskbarCreated=RegisterWindowMessageW(L"TaskbarCreated");
    if(message==taskbarCreated) {a.addTray();return 0;}
    switch(message) {
    case WM_APP+2:a.visible=true;ShowWindow(window,SW_SHOWNOACTIVATE);return 0;
    case WM_MOUSEACTIVATE:return MA_NOACTIVATE;
    case WM_TIMER:a.tick();return 0;
    case WM_LBUTTONDOWN: {
        a.pressed=true;a.dragging=false;GetCursorPos(&a.press);RECT r{};GetWindowRect(window,&r);a.original={r.left,r.top};SetCapture(window);return 0;
    }
    case WM_MOUSEMOVE:if(a.pressed) {
        POINT p{};GetCursorPos(&p);int dx=p.x-a.press.x,dy=p.y-a.press.y;
        if(a.dragging || std::hypot(dx,dy)>3) {a.dragging=true;a.dragRow=dx<0?2:1;
            SetWindowPos(window,HWND_TOPMOST,a.original.x+dx,a.original.y+dy,0,0,SWP_NOSIZE|SWP_NOACTIVATE);}
    }return 0;
    case WM_LBUTTONUP:if(a.pressed) {
        bool dragged=a.dragging;a.pressed=false;a.dragging=false;ReleaseCapture();
        if(dragged) {a.clamp();a.save();} else a.play(3);
    }return 0;
    case WM_CAPTURECHANGED:a.pressed=false;a.dragging=false;return 0;
    case WM_LBUTTONDBLCLK:a.play(4);return 0;
    case WM_RBUTTONUP:a.menu();return 0;
    case trayMessage:if(lp==WM_RBUTTONUP || lp==WM_LBUTTONUP) a.menu();return 0;
    case WM_SETTINGCHANGE:a.readMotionPreference();return 0;
    case WM_DISPLAYCHANGE:a.clamp();return 0;
    case WM_DPICHANGED: {
        a.dpi=HIWORD(wp);a.surface();auto r=reinterpret_cast<RECT*>(lp);
        SetWindowPos(window,HWND_TOPMOST,r->left,r->top,a.width,a.height,SWP_NOACTIVATE);
        a.clamp();a.render(0,0);return 0;
    }
    case WM_CLOSE:DestroyWindow(window);return 0;
    case WM_DESTROY:a.save();KillTimer(window,1);PostQuitMessage(0);return 0;
    }
    return DefWindowProcW(window,message,wp,lp);
}

bool selfTest(App& a,const wchar_t* output) {
    int errors=0,frames=0;BitmapData data{};Rect full(0,0,1536,2288);
    if(a.art->LockBits(&full,ImageLockModeRead,PixelFormat32bppARGB,&data)!=Ok) return false;
    for(int row=0;row<11;++row) for(int col=0;col<8;++col) {
        int used=0;
        for(int y=row*208;y<(row+1)*208;++y) {
            auto line=static_cast<BYTE*>(data.Scan0)+y*data.Stride;
            for(int x=col*192;x<(col+1)*192;++x) if(line[x*4+3]>16) ++used;
        }
        if(col<huhu::counts[row]) {++frames;if(used<400) ++errors;} else if(used!=0) ++errors;
    }
    a.art->UnlockBits(&data);
    constexpr double pi=3.14159265358979323846;
    for(int d=0;d<16;++d) if(huhu::direction(std::sin(d*pi/8)*100,-std::cos(d*pi/8)*100)!=d) ++errors;
    std::string result="{\"ok\":"+std::string(errors==0?"true":"false")+",\"frames\":"+std::to_string(frames)+
        ",\"gazeDirectionsChecked\":16,\"errorCount\":"+std::to_string(errors)+"}\n";
    HANDLE file=CreateFileW(output,GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
    if(file==INVALID_HANDLE_VALUE) return false;
    DWORD written=0;bool saved=WriteFile(file,result.data(),DWORD(result.size()),&written,nullptr)!=FALSE;CloseHandle(file);
    return errors==0 && saved && written==result.size();
}

int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,LPWSTR,int) {
    ULONG_PTR token{};GdiplusStartupInput input;
    if(GdiplusStartup(&token,&input,nullptr)!=Ok) return 1;
    int result=0;
    {
        App a;a.instance=instance;
        if(!a.loadArtwork()) {MessageBoxW(nullptr,L"Huhu’s embedded artwork could not be loaded.",L"Huhu",MB_OK|MB_ICONERROR);return 1;}
        int argc=0;LPWSTR* args=CommandLineToArgvW(GetCommandLineW(),&argc);
        if(argc>=2 && (std::wstring(args[1])==L"--startup-enable" || std::wstring(args[1])==L"--startup-disable")) {
            result=startup::set(std::wstring(args[1])==L"--startup-enable")==ERROR_SUCCESS?0:1;
        } else if(argc>=2 && std::wstring(args[1])==L"--self-test") {
            result=selfTest(a,argc>=3?args[2]:L"validation.json")?0:1;
        } else {
            HANDLE mutex=CreateMutexW(nullptr,TRUE,L"Local\\HuhuDesktopCompanion");
            if(mutex && GetLastError()==ERROR_ALREADY_EXISTS) {
                HWND existing=FindWindowW(windowClass,nullptr);if(existing) PostMessageW(existing,WM_APP+2,0,0);
                CloseHandle(mutex);LocalFree(args);return 0;
            }
            a.readSettings();a.readMotionPreference();current=&a;
            WNDCLASSEXW wc{};wc.cbSize=sizeof(wc);wc.style=CS_DBLCLKS;wc.lpfnWndProc=procedure;
            wc.hInstance=instance;wc.hCursor=LoadCursorW(nullptr,IDC_HAND);wc.hIcon=LoadIconW(instance,MAKEINTRESOURCEW(1));wc.lpszClassName=windowClass;
            if(!RegisterClassExW(&wc)) return 1;
            a.window=CreateWindowExW(WS_EX_LAYERED|WS_EX_TOOLWINDOW|WS_EX_TOPMOST|WS_EX_NOACTIVATE,
                windowClass,L"Huhu · 呼呼",WS_POPUP,0,0,230,250,nullptr,nullptr,instance,nullptr);
            if(!a.window) return 1;
            a.dpi=int(GetDpiForWindow(a.window));
            if(!a.surface()) return 1;
            int x=GetPrivateProfileIntW(L"Huhu",L"X",INT_MIN,a.ini.c_str());
            int y=GetPrivateProfileIntW(L"Huhu",L"Y",INT_MIN,a.ini.c_str());
            if(x==INT_MIN || y==INT_MIN) a.reset();
            else {SetWindowPos(a.window,HWND_TOPMOST,x,y,a.width,a.height,SWP_NOACTIVATE);a.clamp();}
            if(!a.render(0,0)) return 1;
            a.addTray();ShowWindow(a.window,SW_SHOWNOACTIVATE);SetTimer(a.window,1,33,nullptr);
            MSG msg{};while(GetMessageW(&msg,nullptr,0,0)>0) {TranslateMessage(&msg);DispatchMessageW(&msg);}
            if(mutex) CloseHandle(mutex);
            current=nullptr;
        }
        LocalFree(args);
    }
    GdiplusShutdown(token);return result;
}
