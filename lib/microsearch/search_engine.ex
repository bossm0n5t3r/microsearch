defmodule Microsearch.SearchEngine do
  use Supervisor

  alias Microsearch.FileUtil

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    bulk_index()
    Supervisor.init([], strategy: :one_for_one)
  end

  def bulk_index() do
    # Read parquet file
    dataframe = FileUtil.read_parquet_to_dataframe("./output.parquet")

    # Create documents (zip with url and content)
    urls = dataframe[:url] |> Explorer.Series.to_list()
    contents = dataframe[:content] |> Explorer.Series.to_list()
    documents = Enum.zip(urls, contents)

    for {url, content} <- documents do
      index(url, content)
    end
  end

  defp index(url, content) do
    Cachex.put(:documents, url, content)

    words =
      normalize_string(content)
      |> String.split(" ", trim: true)

    for word <- words do
      Cachex.get_and_update(:index, word, fn
        nil ->
          %{url => 1}

        url_to_count ->
          Map.get_and_update(url_to_count, url, fn
            nil -> 1
            count -> count + 1
          end)
      end)
    end

    has_avdl = Cachex.exists?(:avdl, "avdl") |> elem(1)

    if has_avdl do
      Cachex.del(:avdl, "avdl")
    end
  end

  defp normalize_string(input_string) do
    String.replace(input_string, ~r/[[:punct:]]/, " ")
    |> String.downcase()
  end

  def search(query) do
    normalize_string(query)
    |> String.split(" ", trim: true)
    |> Enum.reduce(%{}, fn keyword, acc ->
      kw_urls_score = bm25(keyword)
      update_url_scores(acc, kw_urls_score)
    end)
  end

  defp bm25(keyword) do
    idf_score = idf(keyword)
    avdl_value = avdl()

    get_urls(keyword)
    |> Enum.reduce(%{}, fn {url, freq}, acc ->
      numerator = freq * (1.5 + 1)
      denominator = freq + 1.5 * (1 - 0.75 + 0.75 * get_document_length(url) / avdl_value)
      Map.put(acc, url, idf_score * numerator / denominator)
    end)
  end

  defp idf(keyword) do
    n = number_of_documents()
    n_kw = get_urls(keyword) |> Enum.count()
    Math.log((n - n_kw + 0.5) / (n_kw + 0.5) + 1)
  end

  defp get_urls(keyword) do
    normalized_keyword = normalize_string(keyword)

    Cachex.get(:index, normalized_keyword)
    |> elem(1)
  end

  def posts() do
    Cachex.keys(:documents)
    |> elem(1)
  end

  defp number_of_documents() do
    posts() |> Enum.count()
  end

  defp avdl() do
    Cachex.get(:avdl, "avdl")
    |> case do
      {:ok, nil} ->
        advl_value =
          Enum.map(posts(), fn url -> get_document_length(url) end)
          |> Enum.sum()
          |> Kernel.div(number_of_documents())

        Cachex.put(:avdl, "avdl", advl_value)
        advl_value

      {:ok, avdl} ->
        avdl
    end
  end

  defp get_document_length(url) do
    Cachex.get(:documents, url)
    |> elem(1)
    |> String.length()
  end

  defp update_url_scores(old, new) do
    for {url, score} <- new do
      if Map.has_key?(old, url) do
        {url, old[url] + score}
      else
        {url, score}
      end
    end
    |> Map.new()
  end
end
