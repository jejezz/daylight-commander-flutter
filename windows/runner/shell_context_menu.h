#ifndef RUNNER_SHELL_CONTEXT_MENU_H_
#define RUNNER_SHELL_CONTEXT_MENU_H_

#include <windows.h>

#include <string>
#include <vector>

// Windows 탐색기와 같은 셸 컨텍스트 메뉴를 현재 마우스 커서 위치에 띄운다.
// [paths]는 같은 폴더에 있는 파일/폴더들이어야 하며(다른 폴더의 항목은
// 무시한다), 메뉴를 닫을 때까지 블록된다. 메뉴를 띄웠으면 true.
bool ShowShellContextMenu(HWND owner, const std::vector<std::wstring>& paths);

// 셸 메뉴가 열려 있는 동안 "보내기"/"연결 프로그램" 같은 하위 메뉴가 제대로
// 그려지도록 소유 창의 메뉴 메시지를 IContextMenu2/3 에 전달한다. 처리했으면
// true 와 함께 [result] 를 채운다.
bool HandleShellMenuMessage(HWND hwnd, UINT message, WPARAM wparam,
                            LPARAM lparam, LRESULT* result);

#endif  // RUNNER_SHELL_CONTEXT_MENU_H_
