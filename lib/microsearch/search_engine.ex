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
      Cachex.get_and_update(:index, "#{word}_#{url}", fn
        nil -> 1
        val -> val + 1
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
end
