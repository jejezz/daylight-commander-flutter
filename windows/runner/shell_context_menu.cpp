#include "shell_context_menu.h"

#include <shlobj.h>
#include <shobjidl.h>

#include <algorithm>

namespace {

IContextMenu2* g_menu2 = nullptr;
IContextMenu3* g_menu3 = nullptr;

constexpr UINT kFirstCommand = 1;
constexpr UINT kLastCommand = 0x7FFF;

std::wstring ParentDir(const std::wstring& path) {
  const size_t pos = path.find_last_of(L"\\/");
  return pos == std::wstring::npos ? std::wstring() : path.substr(0, pos);
}

}  // namespace

bool HandleShellMenuMessage(HWND, UINT message, WPARAM wparam, LPARAM lparam,
                            LRESULT* result) {
  if (!g_menu2 && !g_menu3) return false;
  switch (message) {
    case WM_INITMENUPOPUP:
    case WM_DRAWITEM:
    case WM_MEASUREITEM:
      if (g_menu3) {
        LRESULT r = 0;
        if (SUCCEEDED(g_menu3->HandleMenuMsg2(message, wparam, lparam, &r))) {
          *result = r;
          return true;
        }
      } else if (SUCCEEDED(g_menu2->HandleMenuMsg(message, wparam, lparam))) {
        *result = (message == WM_INITMENUPOPUP) ? 0 : TRUE;
        return true;
      }
      return false;
    case WM_MENUCHAR:
      if (g_menu3) {
        LRESULT r = 0;
        if (SUCCEEDED(g_menu3->HandleMenuMsg2(message, wparam, lparam, &r))) {
          *result = r;
          return true;
        }
      }
      return false;
  }
  return false;
}

bool ShowShellContextMenu(HWND owner, const std::vector<std::wstring>& paths) {
  if (paths.empty()) return false;

  const std::wstring dir = ParentDir(paths.front());
  std::vector<PIDLIST_ABSOLUTE> absolute;
  std::vector<PCUITEMID_CHILD> children;
  IShellFolder* parent = nullptr;

  for (const auto& path : paths) {
    if (_wcsicmp(ParentDir(path).c_str(), dir.c_str()) != 0) continue;
    PIDLIST_ABSOLUTE pidl = nullptr;
    if (FAILED(SHParseDisplayName(path.c_str(), nullptr, &pidl, 0, nullptr))) {
      continue;
    }
    IShellFolder* folder = nullptr;
    PCUITEMID_CHILD child = nullptr;
    if (FAILED(SHBindToParent(pidl, IID_PPV_ARGS(&folder), &child))) {
      CoTaskMemFree(pidl);
      continue;
    }
    absolute.push_back(pidl);
    children.push_back(child);
    if (!parent) {
      parent = folder;
    } else {
      folder->Release();
    }
  }

  auto cleanup_pidls = [&]() {
    for (auto pidl : absolute) CoTaskMemFree(pidl);
    if (parent) parent->Release();
  };
  if (!parent || children.empty()) {
    cleanup_pidls();
    return false;
  }

  IContextMenu* menu = nullptr;
  if (FAILED(parent->GetUIObjectOf(owner, static_cast<UINT>(children.size()),
                                   children.data(), IID_IContextMenu, nullptr,
                                   reinterpret_cast<void**>(&menu))) ||
      !menu) {
    cleanup_pidls();
    return false;
  }

  HMENU popup = CreatePopupMenu();
  UINT flags = CMF_NORMAL | CMF_EXPLORE;
  // Shift 를 누른 채 열면 탐색기처럼 확장 메뉴("PowerShell 창 열기" 등)도 보인다.
  if (GetKeyState(VK_SHIFT) & 0x8000) flags |= CMF_EXTENDEDVERBS;
  bool shown = false;
  if (SUCCEEDED(menu->QueryContextMenu(popup, 0, kFirstCommand, kLastCommand,
                                       flags))) {
    menu->QueryInterface(IID_PPV_ARGS(&g_menu2));
    menu->QueryInterface(IID_PPV_ARGS(&g_menu3));

    POINT pt;
    GetCursorPos(&pt);
    SetForegroundWindow(owner);
    const UINT cmd = TrackPopupMenuEx(
        popup, TPM_RETURNCMD | TPM_RIGHTBUTTON, pt.x, pt.y, owner, nullptr);
    PostMessage(owner, WM_NULL, 0, 0);
    shown = true;

    if (cmd >= kFirstCommand) {
      CMINVOKECOMMANDINFOEX info = {};
      info.cbSize = sizeof(info);
      info.fMask = CMIC_MASK_UNICODE | CMIC_MASK_PTINVOKE;
      info.hwnd = owner;
      info.lpVerb = MAKEINTRESOURCEA(cmd - kFirstCommand);
      info.lpVerbW = MAKEINTRESOURCEW(cmd - kFirstCommand);
      info.nShow = SW_SHOWNORMAL;
      info.ptInvoke = pt;
      menu->InvokeCommand(reinterpret_cast<CMINVOKECOMMANDINFO*>(&info));
    }

    if (g_menu3) g_menu3->Release();
    if (g_menu2) g_menu2->Release();
    g_menu2 = nullptr;
    g_menu3 = nullptr;
  }

  DestroyMenu(popup);
  menu->Release();
  cleanup_pidls();
  return shown;
}
