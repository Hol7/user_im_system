defmodule MyAuthSystem.Utils.UserAgentParser do
  @moduledoc """
  Parse User-Agent strings to extract device and browser information.
  """

  @doc """
  Parse user agent string and return device info map.
  """
  def parse(nil), do: %{device: "Unknown", browser: "Unknown", os: "Unknown"}
  
  def parse(user_agent) when is_binary(user_agent) do
    %{
      device: detect_device(user_agent),
      browser: detect_browser(user_agent),
      os: detect_os(user_agent)
    }
  end

  defp detect_device(ua) do
    cond do
      String.contains?(ua, ["iPhone", "iPad", "iPod"]) -> "iOS Device"
      String.contains?(ua, "Android") -> "Android Device"
      String.contains?(ua, ["Windows Phone", "Windows Mobile"]) -> "Windows Phone"
      String.contains?(ua, "Mobile") -> "Mobile Device"
      String.contains?(ua, "Tablet") -> "Tablet"
      true -> "Desktop"
    end
  end

  defp detect_browser(ua) do
    cond do
      String.contains?(ua, "Edg/") -> "Edge"
      String.contains?(ua, "Chrome/") -> "Chrome"
      String.contains?(ua, "Safari/") and not String.contains?(ua, "Chrome") -> "Safari"
      String.contains?(ua, "Firefox/") -> "Firefox"
      String.contains?(ua, "MSIE") or String.contains?(ua, "Trident/") -> "Internet Explorer"
      String.contains?(ua, "Opera") or String.contains?(ua, "OPR/") -> "Opera"
      true -> "Unknown Browser"
    end
  end

  defp detect_os(ua) do
    cond do
      String.contains?(ua, "Windows NT 10.0") -> "Windows 10"
      String.contains?(ua, "Windows NT 6.3") -> "Windows 8.1"
      String.contains?(ua, "Windows NT 6.2") -> "Windows 8"
      String.contains?(ua, "Windows NT 6.1") -> "Windows 7"
      String.contains?(ua, "Windows") -> "Windows"
      String.contains?(ua, "Mac OS X") -> "macOS"
      String.contains?(ua, "Linux") -> "Linux"
      String.contains?(ua, "Android") -> "Android"
      String.contains?(ua, ["iPhone", "iPad", "iPod"]) -> "iOS"
      true -> "Unknown OS"
    end
  end
end
