#include "include/pasteboard/pasteboard_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <Windows.h>

#include <fstream>
#include <memory>
#include <string>
#include <vector>

namespace
{

  class ScopedClipboard
  {
  public:
    ~ScopedClipboard()
    {
      if (opened_)
      {
        CloseClipboard();
      }
    }

    bool Open()
    {
      opened_ = ::OpenClipboard(nullptr) != FALSE;
      return opened_;
    }

  private:
    bool opened_ = false;
  };

  std::vector<unsigned char> ReadFile(const std::wstring &path)
  {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file)
    {
      return {};
    }
    const std::streamsize size = file.tellg();
    if (size <= 0)
    {
      return {};
    }
    std::vector<unsigned char> bytes(static_cast<size_t>(size));
    file.seekg(0);
    file.read(reinterpret_cast<char *>(bytes.data()), size);
    return bytes;
  }

  std::string ToUtf8(const std::wstring &value)
  {
    const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (size <= 1)
    {
      return {};
    }
    std::string result(static_cast<size_t>(size - 1), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), size, nullptr, nullptr);
    return result;
  }

  bool SetClipboardPng(const std::vector<unsigned char> &bytes)
  {
    const UINT png_format = RegisterClipboardFormatW(L"PNG");
    HGLOBAL global = GlobalAlloc(GMEM_MOVEABLE, bytes.size());
    if (global == nullptr)
    {
      return false;
    }
    void *destination = GlobalLock(global);
    if (destination == nullptr)
    {
      GlobalFree(global);
      return false;
    }
    memcpy(destination, bytes.data(), bytes.size());
    GlobalUnlock(global);
    if (SetClipboardData(png_format, global) == nullptr)
    {
      GlobalFree(global);
      return false;
    }
    return true;
  }

  std::wstring ClipboardDibFile()
  {
    if (!IsClipboardFormatAvailable(CF_DIB))
    {
      return {};
    }
    void *clipboard_data = GetClipboardData(CF_DIB);
    if (clipboard_data == nullptr)
    {
      return {};
    }
    const auto *header = static_cast<const BITMAPINFOHEADER *>(clipboard_data);
    const size_t color_table_entries = header->biBitCount <= 8
                                           ? (header->biClrUsed != 0 ? header->biClrUsed : (1u << header->biBitCount))
                                           : (header->biCompression == BI_BITFIELDS && header->biBitCount == 32 ? 3u : 0u);
    const size_t pixel_offset = sizeof(BITMAPFILEHEADER) + header->biSize +
                                color_table_entries * sizeof(RGBQUAD);
    const size_t data_size = GlobalSize(clipboard_data);
    if (data_size == 0)
    {
      return {};
    }
    BITMAPFILEHEADER file_header = {};
    file_header.bfType = 0x4D42;
    file_header.bfOffBits = static_cast<DWORD>(pixel_offset);
    file_header.bfSize = static_cast<DWORD>(sizeof(BITMAPFILEHEADER) + data_size);

    wchar_t directory[MAX_PATH] = {};
    wchar_t path[MAX_PATH] = {};
    GetTempPathW(MAX_PATH, directory);
    GetTempFileNameW(directory, L"fpaint", 0, path);
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (!file)
    {
      return {};
    }
    file.write(reinterpret_cast<const char *>(&file_header), sizeof(file_header));
    file.write(static_cast<const char *>(clipboard_data), static_cast<std::streamsize>(data_size));
    return path;
  }

  std::wstring ClipboardPngFile()
  {
    const UINT png_format = RegisterClipboardFormatW(L"PNG");
    if (!IsClipboardFormatAvailable(png_format))
    {
      return {};
    }
    HANDLE clipboard_data = GetClipboardData(png_format);
    if (clipboard_data == nullptr)
    {
      return {};
    }
    const SIZE_T size = GlobalSize(clipboard_data);
    const void *bytes = GlobalLock(clipboard_data);
    if (bytes == nullptr || size == 0)
    {
      return {};
    }
    wchar_t directory[MAX_PATH] = {};
    wchar_t path[MAX_PATH] = {};
    GetTempPathW(MAX_PATH, directory);
    GetTempFileNameW(directory, L"fpaint", 0, path);
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (!file)
    {
      GlobalUnlock(clipboard_data);
      return {};
    }
    file.write(static_cast<const char *>(bytes), static_cast<std::streamsize>(size));
    GlobalUnlock(clipboard_data);
    return path;
  }

  class PasteboardPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  private:
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  void PasteboardPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(), "pasteboard",
        &flutter::StandardMethodCodec::GetInstance());
    auto plugin = std::make_unique<PasteboardPlugin>();
    channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result)
                                  { plugin_pointer->HandleMethodCall(call, std::move(result)); });
    registrar->AddPlugin(std::move(plugin));
  }

  void PasteboardPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (call.method_name() == "image")
    {
      std::wstring path = ClipboardPngFile();
      if (path.empty())
      {
        path = ClipboardDibFile();
      }
      if (path.empty())
      {
        result->Success();
      }
      else
      {
        result->Success(flutter::EncodableValue(ToUtf8(path)));
      }
      return;
    }

    if (call.method_name() == "writeImage")
    {
      const auto *arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      if (arguments == nullptr)
      {
        result->Error("invalid_arguments", "Image file name is missing");
        return;
      }
      const auto iterator = arguments->find(flutter::EncodableValue("fileName"));
      if (iterator == arguments->end() || !std::holds_alternative<std::string>(iterator->second))
      {
        result->Error("invalid_arguments", "Image file name is missing");
        return;
      }
      const std::string file_name = std::get<std::string>(iterator->second);
      const std::wstring wide_file_name(file_name.begin(), file_name.end());
      const std::vector<unsigned char> bytes = ReadFile(wide_file_name);
      ScopedClipboard clipboard;
      if (bytes.empty() || !clipboard.Open())
      {
        result->Error("clipboard_error", "Unable to open image or clipboard");
        return;
      }
      EmptyClipboard();
      if (!SetClipboardPng(bytes))
      {
        result->Error("clipboard_error", "Unable to write PNG to clipboard");
        return;
      }
      result->Success();
      return;
    }

    result->NotImplemented();
  }

} // namespace

void PasteboardPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  PasteboardPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
