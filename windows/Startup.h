#pragma once
#include <windows.h>
#include <string>
#include <vector>

namespace startup {
inline constexpr wchar_t key[]=L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
inline constexpr wchar_t value[]=L"Huhu";
inline std::wstring command() {
    std::vector<wchar_t> path(32768);
    DWORD length=GetModuleFileNameW(nullptr,path.data(),DWORD(path.size()));
    if(length==0 || length>=path.size()) return {};
    return L"\""+std::wstring(path.data(),length)+L"\"";
}
inline bool registered() {
    HKEY handle{};
    if(RegOpenKeyExW(HKEY_CURRENT_USER,key,0,KEY_QUERY_VALUE|KEY_WOW64_64KEY,&handle)!=ERROR_SUCCESS) return false;
    wchar_t data[32768]{};DWORD bytes=sizeof(data),type=0;
    LSTATUS result=RegQueryValueExW(handle,value,nullptr,&type,reinterpret_cast<BYTE*>(data),&bytes);
    RegCloseKey(handle);
    if(result!=ERROR_SUCCESS || type!=REG_SZ || bytes<sizeof(wchar_t) || bytes>sizeof(data)) return false;
    data[32767]=0;
    auto expected=command();
    return !expected.empty() && _wcsicmp(data,expected.c_str())==0;
}
inline LSTATUS set(bool enable) {
    HKEY handle{};
    if(!enable) {
        auto result=RegOpenKeyExW(HKEY_CURRENT_USER,key,0,KEY_SET_VALUE|KEY_WOW64_64KEY,&handle);
        if(result==ERROR_FILE_NOT_FOUND) return ERROR_SUCCESS;
        if(result!=ERROR_SUCCESS) return result;
        result=RegDeleteValueW(handle,value);RegCloseKey(handle);
        return result==ERROR_FILE_NOT_FOUND?ERROR_SUCCESS:result;
    }
    auto cmd=command();
    // Windows Run entries support a command line of at most 260 characters.
    if(cmd.empty() || cmd.size()>260) return ERROR_FILENAME_EXCED_RANGE;
    auto result=RegCreateKeyExW(HKEY_CURRENT_USER,key,0,nullptr,0,KEY_SET_VALUE|KEY_WOW64_64KEY,nullptr,&handle,nullptr);
    if(result!=ERROR_SUCCESS) return result;
    result=RegSetValueExW(handle,value,0,REG_SZ,reinterpret_cast<const BYTE*>(cmd.c_str()),DWORD((cmd.size()+1)*sizeof(wchar_t)));
    RegCloseKey(handle);return result;
}
}
