defmodule Header do
  @derive [Poison.Encoder]
  defstruct [:name, :value]
end

defmodule Request do
  @derive [Poison.Encoder]
  defstruct [:body, :headers, :method, :url]
end

defmodule Response do
  @derive [Poison.Encoder]
  defstruct [:body, :headers, :status_code, :status_text]
end

defmodule MainObject do
  @derive [Poison.Encoder]
  defstruct [:http_version, :request, :response]
end

defmodule TellerCompare do
  def main([file1_path, file2_path]) do
    parsed_file1 = read_parse_json(file1_path)
    parsed_file2 = read_parse_json(file2_path)

    {changes, additions, removals} = compare_data(parsed_file1, parsed_file2)

    # Use Logger to format the output
    CustomLogger.format_log(changes, "Changes")
    CustomLogger.format_log(additions, "Additions")
    CustomLogger.format_log(removals, "Removals")

    # creating file output
    changes_content = "Changes:\n" <> (Enum.map(changes, &CustomLogger.format_entry_for_file(&1)) |> Enum.join("\n"))
    additions_content = "\n\nAdditions:\n" <> (Enum.map(additions, &CustomLogger.format_entry_for_file(&1)) |> Enum.join("\n"))
    removals_content = "\n\nRemovals:\n" <> (Enum.map(removals, &CustomLogger.format_entry_for_file(&1)) |> Enum.join("\n"))


    output_content = changes_content <> additions_content <> removals_content <> "\n\n"


    # writing to file
    output_path = "output_diff.txt"
    case File.write(output_path, output_content) do
      :ok -> IO.puts("Successfully wrote to #{output_path}")
      {:error, reason} -> IO.puts("Failed to write to #{output_path}: #{reason}")
    end
  end

  def read_parse_json(path) do
    {:ok, content} = File.read(path)
    parsed_content = Poison.decode!(content, as: [%MainObject{
    request: %Request{headers: [%Header{}]},
    response: %Response{headers: [%Header{}]}
    }])
    IO.puts("Parsed Content----")
    IO.puts(inspect(parsed_content))
    IO.puts("\n")
    parsed_content
  end

  def compare_lists(list1, list2) when is_list(list1) and is_list(list2) do
    # Additions are items present in list2 but not in list1.
    additions = list2 -- list1
    IO.puts("Additions----")
    IO.puts(inspect(additions))

    # Removals are items present in list1 but not in list2.
    removals = list1 -- list2
    IO.puts("Removals----")
    IO.puts(inspect(removals))

    IO.puts("List 1----")
    IO.puts(inspect(list1))
    IO.puts("List 2----")
    IO.puts(inspect(list2))

    # Changes are items that exist in both lists but are not identical.
    # This approach assumes the data structure has a meaningful equality check.
#    common_list1 = list1 -- removals
#    common_list2 = list2 -- additions
#    IO.puts("Common List 1----")
#    IO.puts(inspect(common_list1))
#    IO.puts("Common List 2----")
#    IO.puts(inspect(common_list2))

#    changes = Enum.zip(common_list1, common_list2)
#              |> Enum.filter(fn {a, b} -> a != b end)
#              |> Enum.map(fn {_, b} -> b end)

    # making an empty list of changes temporarily
    changes = []

    {changes, additions, removals}
  end

  def compare_data(data1, data2) when is_list(data1) and is_list(data2) do
    compare_lists(data1, data2)
  end
end

defmodule CustomLogger do
  def format_log(entries, title) when is_list(entries) do
    IO.puts("#{title}:")
    Enum.each(entries, &format_entry(&1))
    IO.puts("\n")
  end

  def format_entry(%MainObject{request: request, response: response}) do
    IO.puts("URL: #{request.url}")
    IO.puts("Method: #{request.method}")

    IO.puts("Request Headers:")
    Enum.each(request.headers, &IO.puts("  #{&1.name}: #{&1.value}"))

    if request.body do
      IO.puts("Request Body:")
      IO.puts("  #{request.body}")
    end

    IO.puts("Response Status: #{response.status_code} #{response.status_text}")

    IO.puts("Response Headers:")
    Enum.each(response.headers, &IO.puts("  #{&1.name}: #{&1.value}"))

    if response.body do
      IO.puts("Response Body:")
      IO.puts("  #{response.body}")
    end

    IO.puts("---")
  end

  def format_entry_for_file(%MainObject{request: request, response: response}) do
    [
      "URL: #{request.url}",
      "Method: #{request.method}",
      "Request Headers:" <> "\n" <> Enum.map_join(request.headers, "\n", fn header -> "  #{header.name}: #{header.value}" end),
      "Request Body: #{request.body}",
      "Response Status: #{response.status_code} #{response.status_text}",
      "Response Headers:" <> "\n" <> Enum.map_join(response.headers, "\n", fn header -> "  #{header.name}: #{header.value}" end),
      "Response Body: #{response.body}",
      "---"
    ] |> Enum.filter(& &1) |> Enum.join("\n")
  end


end
