#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // If Orvia is already running, forward any deep link argument and bring the window to focus
  HWND existing_window = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Orvia");
  if (existing_window != nullptr) {
    std::string target_url = "";
    for (const auto& arg : command_line_arguments) {
      if (arg.rfind("orvia://", 0) == 0 ||
          arg.rfind("https://", 0) == 0 ||
          arg.rfind("http://", 0) == 0) {
        target_url = arg;
        break;
      }
    }
    if (!target_url.empty()) {
      COPYDATASTRUCT cds;
      cds.dwData = 0x4F525649;
      cds.cbData = static_cast<DWORD>(target_url.size() + 1);
      cds.lpData = const_cast<char*>(target_url.c_str());
      ::SendMessage(existing_window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds));
    }
    if (::IsIconic(existing_window)) {
      ::ShowWindow(existing_window, SW_RESTORE);
    } else {
      ::ShowWindow(existing_window, SW_SHOW);
    }
    ::SetForegroundWindow(existing_window);
    return EXIT_SUCCESS;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Orvia", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
