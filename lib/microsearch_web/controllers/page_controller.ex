defmodule MicrosearchWeb.PageController do
  use MicrosearchWeb, :controller

  alias Microsearch.SearchEngine

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    posts = SearchEngine.posts()
    render(conn, :home, posts: posts, layout: false)
  end

  def search_results(conn, %{"query" => query} = _params) do
    results =
      SearchEngine.search(query)
      |> get_top_urls(5)

    render(conn, :results, query: query, results: results, layout: false)
  end

  defp get_top_urls(scores_map, n) do
    scores_map
    |> Map.to_list()
    |> Enum.sort(fn {_, score1}, {_, score2} -> score1 > score2 end)
    |> Enum.take(n)
    |> Map.new()
  end
end
