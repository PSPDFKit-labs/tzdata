defmodule Tzdata.DataLoader do
  require Logger
  # Can poll for newest version of tz data and can download
  # and extract it.
  @download_url "https://www.iana.org/time-zones/repository/tzdata-latest.tar.gz"
  #@download_url "https://www.iana.org/time-zones/repository/releases/tzdata2015a.tar.gz"
  def download_new(url\\@download_url) do
    ensure_httpc_ready
    Logger.debug "Tzdata downloading new data from #{url}"
    set_latest_remote_poll_date
    {:ok, {{_, 200, _}, headers, body}} = :httpc.request(:get, {String.to_char_list(url), []}, [], [body_format: :binary])
    content_length = content_length_from_headers(headers)
    new_dir_name ="priv/tmp_downloads/#{content_length}/"
    File.mkdir_p(new_dir_name)
    target_filename = "#{new_dir_name}latest.tar.gz"
    File.write!(target_filename, body)
    extract(target_filename, new_dir_name)
    release_version = release_version_for_dir(new_dir_name)
    Logger.debug "Tzdata data downloaded. Release version #{release_version}."
    {:ok, content_length, release_version, new_dir_name}
  end
  defp extract(filename, target_dir) do
    :erl_tar.extract(filename, [:compressed, {:cwd, target_dir}])
    File.rm(filename) # remove tar.gz file after extraction
  end
  defp content_length_from_headers(headers) do
    headers
    |> Enum.filter(fn {k, _v} -> k == 'content-length' end)
    |> hd |> elem(1)
    |> List.to_integer
  end

  def release_version_for_dir(dir_name) do
    release_string = "#{dir_name}NEWS"
    |> File.stream!
    |> Stream.filter(fn(string) -> Regex.match?(~r/Release/, string) end)
    |> Enum.take(100) # 100 lines should be more than enough to get the first Release line
    |> hd
    |> String.rstrip
    captured = Regex.named_captures( ~r/Release[\s]+(?<version>[^\s]+)[\s]+-[\s]+(?<timestamp>.+)/m, release_string)
    captured["version"]
  end

  def latest_file_size(url\\@download_url) do
    ensure_httpc_ready
    set_latest_remote_poll_date
    :httpc.request(:head, {String.to_char_list(url), []}, [], [])
    |> do_latest_file_size
  end
  defp do_latest_file_size({:ok, {{_, 200, _}, headers, []}}) do
    size = headers |> content_length_from_headers
    {:ok, size}
  end
  defp do_latest_file_size(other), do: {:error, other}

  def set_latest_remote_poll_date do
    {y, m, d} = current_date_utc
    File.write(remote_poll_file_name, "#{y}-#{m}-#{d}")
  end
  def latest_remote_poll_date do
    latest_remote_poll_file_exists? |> do_latest_remote_poll_date
  end
  defp do_latest_remote_poll_date(_file_exists = true) do
    date = File.stream!(remote_poll_file_name) |> Enum.to_list |> hd
    |> String.split("-")
    |> Enum.map(&(Integer.parse(&1)|>elem(0)))
    |> List.to_tuple
    {:ok, date}
  end
  defp do_latest_remote_poll_date(_file_exists = false), do: {:unknown, nil}
  defp latest_remote_poll_file_exists?, do: File.exists? remote_poll_file_name

  defp current_date_utc, do: :calendar.universal_time |> elem(0)

  def days_since_last_remote_poll do
    {tag, date} = latest_remote_poll_date
    case tag do
      :ok ->
        days_today = :calendar.date_to_gregorian_days(current_date_utc)
        days_latest = :calendar.date_to_gregorian_days(date)
        {:ok, days_today - days_latest}
      _ -> {tag, date}
    end
  end

  def remote_poll_file_name do
    Application.app_dir(:tzdata, "priv/latest_remote_poll.txt")
  end

  defp ensure_httpc_ready do
    {:ok, _} = Application.ensure_all_started(:inets, :permanent)
    {:ok, _} = Application.ensure_all_started(:ssl, :permanent)
  end
end
