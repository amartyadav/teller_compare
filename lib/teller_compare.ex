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

    changes = compare_data_deep(parsed_file1, parsed_file2)

    # Use Logger to format the output
    # CustomLogger.format_log(changes, "Changes")


    # creating file output
    changes_content = "Changes:\n" <> (Enum.map(changes, &CustomLogger.format_entry_for_file(&1)) |> Enum.join("\n"))


    output_content = changes_content <> "\n\n"

    # writing to file
    output_path = "output_diff.txt"
    case File.write(output_path, output_content) do
      :ok -> IO.puts("Successfully wrote to #{output_path}")
      {:error, reason} -> IO.puts("Failed to write to #{output_path}: #{reason}")
    end
  end

  def compare_data_deep(data1, data2) do
    data1_map = Map.new(data1, & {identifier(&1), &1})
    data2_map = Map.new(data2, & {identifier(&1), &1})

    IO.puts("data1_map: #{inspect(data1_map)}")
    IO.puts("data2_map: #{inspect(data2_map)}")

    key = {"https://status.thebank.teller.engineering/status.json?downtimeTimestamp=1691577508.930853", "GET"}
    IO.puts("Key in data1_map: #{Map.has_key?(data1_map, key)}")
    IO.puts("Key in data2_map: #{Map.has_key?(data2_map, key)}")

    common_keys = for {k, _v} <- data1_map, Map.has_key?(data2_map, k), do: k
    IO.puts("common_keys: #{inspect(common_keys)}")

    common_keys_set = MapSet.new(common_keys)

    changes = Enum.flat_map(common_keys_set, fn key ->
      obj1 = Map.get(data1_map, key)
      obj2 = Map.get(data2_map, key)

      request_changes = DeepComparator.compare_requests(obj1.request, obj2.request)
      response_changes = DeepComparator.compare_response(obj1.response, obj2.response)

      request_changes ++ response_changes
    end)

    # changes = []
    # Enum.each(common_keys, fn key ->
    #   obj1 = Map.get(data1_map, key)
    #   obj2 = Map.get(data2_map, key)

    #   IO.puts("obj1: #{inspect(obj1)}")

    #   request_changes = DeepComparator.compare_requests(obj1.request, obj2.request)
    #   response_changes = DeepComparator.compare_response(obj1.response, obj2.response)

    #   ^changes = changes ++ request_changes ++ response_changes
    # end)

    additions = data2_map |> Map.drop(MapSet.to_list(common_keys_set))
    |> Map.values()
    |> Enum.map(fn obj -> "Addition: #{inspect(obj)}" end)

    removals = data1_map |> Map.drop(MapSet.to_list(common_keys_set))
    |> Map.values()
    |> Enum.map(fn obj -> "Removal: #{inspect(obj)}" end)

    changes ++ additions ++ removals
  end

  defp identifier(%MainObject{request: %Request{url: url, method: method}}), do: {url, method}

  def read_parse_json(path) do
    {:ok, content} = File.read(path)
    parsed_content = Poison.decode!(content, as: [%MainObject{
    request: %Request{headers: [%Header{}]},
    response: %Response{headers: [%Header{}]}
    }])
    # IO.puts("Parsed Content----")
    # IO.puts(inspect(parsed_content))
    # IO.puts("\n")
    parsed_content
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

  def format_entry(message) when is_binary(message), do: IO.puts(message)


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

   # Handle plain strings
   def format_entry_for_file(message) when is_binary(message), do: message


end

defmodule DeepComparator do
  def compare_requests(req1, req2) do
    # compare url
    # compare method
    # compare headers
    # compare body

    changes = []

     # Check for URL differences
     changes =
     cond do
       req1.url != req2.url -> changes ++ ["URL: #{req1.url} -> #{req2.url}"]
       true -> changes
     end

   # Check for method differences
   changes =
     cond do
       req1.method != req2.method -> changes ++ ["Method: #{req1.method} -> #{req2.method}"]
       true -> changes
     end

   # Check for body differences
   changes =
     cond do
       req1.body != req2.body -> changes ++ ["Body: #{req1.body} -> #{req2.body}"]
       true -> changes
     end

    # compare headers
    header_changes = compare_headers(req1.headers, req2.headers)
    changes = changes ++ header_changes

    changes
  end

  def compare_response(resp1, resp2) do
    # compare status code
    # compare status text
    # compare body
    # compare headers

    changes = []

    changes =
    cond do
      resp1.status_code != resp2.status_code -> changes ++ ["Status Code: #{resp1.status_code} -> #{resp2.status_code}"]
      true -> changes
    end

    changes =
    cond do
      resp1.status_text != resp2.status_text -> changes ++ ["Status Text: #{resp1.status_text} -> #{resp2.status_text}"]
      true -> changes
    end

    changes =
    cond do
      resp1.body != resp2.body -> changes ++ ["Body: #{resp1.body} -> #{resp2.body}"]
      true -> changes
    end

    # compare headers
    header_changes = compare_headers(resp1.headers, resp2.headers)
    changes = changes ++ header_changes

    changes
  end

  def compare_headers(headers1, headers2) do
    changes = []
    # comparing headers' order and content
    Enum.zip(headers1, headers2)
    |> Enum.each(fn {h1, h2} when h1 != h2 ->
      changes = [changes | "Header: #{h1.name}: #{h1.value} -> #{h2.name}: #{h2.value}"]
      _ -> nil
    end)

    # finding header additions and removals
    additions = headers2 -- headers1
    removals = headers1 -- headers2

    Enum.each(additions, fn header ->
      changes = [changes | "Header Addition: #{header.name}: #{header.value}"]
    end)

    Enum.each(removals, fn header ->
      changes = [changes | "Header Removal: #{header.name}: #{header.value}"]
    end)
    changes
  end
end
