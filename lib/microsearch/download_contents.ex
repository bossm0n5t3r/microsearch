defmodule Microsearch.DownloadContents do
  alias Microsearch.FileUtil

  @spec download_contents() :: :ok
  def download_contents() do
    tasks =
      FileUtil.read_lines("../../feeds.txt")
      |> Enum.map(fn feed_url ->
        Task.async(fn -> process_feed(feed_url) end)
      end)

    url_and_contents = Task.await_many(tasks, :infinity) |> List.flatten()

    post_urls = url_and_contents |> Enum.map(fn {url, _} -> url end)
    contents = url_and_contents |> Enum.map(fn {_, content} -> content end)

    url = Explorer.Series.from_list(post_urls)
    content = Explorer.Series.from_list(contents)

    Explorer.DataFrame.new(url: url, content: content)
    |> Explorer.DataFrame.to_parquet!("./output.parquet")
  end

  defp process_feed(feed_url) do
    post_urls = get_links_from_feed(feed_url)
    contents = post_urls |> Enum.map(fn post_url -> get_clean_content(post_url) end)
    Enum.zip(post_urls, contents)
  end

  defp get_links_from_feed(feed_url) do
    try do
      Req.get(feed_url)
      |> case do
        {:ok, %{status: 200, body: body}} ->
          body
          |> FastRSS.parse_rss()
          |> case do
            {:ok, map_of_rss} ->
              Map.get(map_of_rss, "items") |> Enum.map(fn item -> item["link"] end)

            _ ->
              []
          end

        _ ->
          []
      end
    rescue
      _ -> []
    end
  end

  defp get_clean_content(feed_url) do
    {:ok, document} =
      try do
        Req.get(feed_url)
        |> case do
          {:ok, %{status: 200, body: body}} -> body
          _ -> ""
        end
      rescue
        _ -> ""
      end
      |> Floki.parse_document()

    Floki.text(document)
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      line |> String.split(" ", trim: true)
    end)
    |> Enum.join(" ")
  end
end
