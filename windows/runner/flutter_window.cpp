#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "shell_context_menu.h"

namespace {

std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return std::wstring();
  const int n = MultiByteToWideChar(CP_UTF8, 0, s.data(),
                                    static_cast<int>(s.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()),
                      out.data(), n);
  return out;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  shell_menu_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "art.zoomon.daylightcommander/shell_menu",
          &flutter::StandardMethodCodec::GetInstance());
  shell_menu_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "show") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<flutter::EncodableList>(call.arguments());
        if (!args) {
          result->Error("bad_args", "paths list expected");
          return;
        }
        std::vector<std::wstring> paths;
        for (const auto& v : *args) {
          if (const auto* s = std::get_if<std::string>(&v)) {
            paths.push_back(Utf8ToWide(*s));
          }
        }
        result->Success(flutter::EncodableValue(
            ShowShellContextMenu(GetHandle(), paths)));
      });

  // window_manager가 창 표시를 맡는다(main.dart: 배치가 끝나고 첫 프레임이 그려진 뒤에
  // show()를 부른다). 여기서 첫 프레임에 바로 보여버리면, 아직 최종 모니터·배율로 옮기기 전의
  // 창이 먼저 보였다가 자리 잡으며 커졌다 줄었다 하는 게 비친다 (window_manager README
  // "Make sure you don't call Show() in windows/runner/flutter_window.cpp").

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  shell_menu_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  LRESULT menu_result = 0;
  if (HandleShellMenuMessage(hwnd, message, wparam, lparam, &menu_result)) {
    return menu_result;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
