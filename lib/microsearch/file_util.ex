defmodule Microsearch.FileUtil do
  @spec read_lines(String.t()) :: list(String.t())
  def read_lines(filename) do
    path = Path.expand(filename, __DIR__)

    case File.read(path) do
      {:ok, lines} ->
        lines |> String.split("\n", trim: true)

      {:error, _} ->
        IO.puts("Error: #{filename} file not found")
        System.halt(1)
    end
  end

  def read_parquet_to_dataframe(filename) do
    Explorer.DataFrame.from_parquet(filename)
    |> case do
      {:ok, df} ->
        df

      _ ->
        IO.puts("Error: #{filename} file not found")
        System.halt(1)
    end
  end
end
