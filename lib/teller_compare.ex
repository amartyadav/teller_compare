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

    parsed_file1 = read_parse_json(file1_path) # reading and parsing file1
    parsed_file2 = read_parse_json(file2_path) # reading and parsing file2

    changes = compare_data_deep(parsed_file1, parsed_file2)

    # creating file output
    changes_content =
      "Changes:\n" <>
        (Enum.map(changes, &CustomLogger.format_entry_for_file(&1)) |> Enum.join("\n"))

    output_content = changes_content <> "\n\n"

    # writing to file
    output_path = "output_diff.txt"

    case File.write(output_path, output_content) do
      :ok -> IO.puts("Successfully wrote to #{output_path}")
      {:error, reason} -> IO.puts("Failed to write to #{output_path}: #{reason}")
    end
  end

  def compare_data_deep(data1, data2) do
    # creating a map for data1 with the identifier() function's return value as the key and the object as the value
    data1_map = Map.new(data1, &{identifier(&1), &1})

    # creating a map for data2 with the identifier() function's return value as the key and the object as the value
    data2_map = Map.new(data2, &{identifier(&1), &1})

    # finding the common keys between the two maps using list comprehension
    common_keys = for {k, _v} <- data1_map, Map.has_key?(data2_map, k), do: k

    # creating a set of the common keys
    common_keys_set = MapSet.new(common_keys)

    # extracting the values of the common keys from the maps to pass them to the deep comparator as arguments
    # changes will contain the changes in the requests and responses
    changes =
      Enum.flat_map(common_keys_set, fn key ->
        obj1 = Map.get(data1_map, key)
        obj2 = Map.get(data2_map, key)

        request_changes = DeepComparator.compare_requests(obj1.request, obj2.request) # comparing request
        response_changes = DeepComparator.compare_response(key, obj1.response, obj2.response) # comparing response

        request_changes ++ response_changes # combining the changes
      end)

    # finding the additions. dropping the common keys from data2_map (second file) to get the additions
    additions =
      data2_map
      |> Map.drop(MapSet.to_list(common_keys_set))
      |> Map.values()
      |> Enum.map(fn obj ->
        request = Map.get(obj, :request)
        response = Map.get(obj, :response)
        http_version = Map.get(obj, :http_version)
        url_method = identifier(obj)
        url_method = "#{elem(url_method, 0)},#{elem(url_method, 1)}"
        request_str = inspect(Map.from_struct(request))
        request_str = String.replace(request_str, "%", "")
        response_str = inspect(Map.from_struct(response))
        response_str = String.replace(response_str, "%", "")
        http_version_str = inspect(http_version)
        "URL+Method (identifier): #{url_method}\n Addition: {\n  http_version: #{http_version_str}\n  request: #{request_str}\n  response: #{response_str}}\n"
      end)

    # finding the removals. dropping the common keys from data1_map(first file) to get the removals
    removals =
      data1_map
      |> Map.drop(MapSet.to_list(common_keys_set))
      |> Map.values()
      |> Enum.map(fn obj ->
        request = Map.get(obj, :request)
        response = Map.get(obj, :response)
        http_version = Map.get(obj, :http_version)
        url_method = identifier(obj)
        url_method = "#{elem(url_method, 0)},#{elem(url_method, 1)}"
        request_str = inspect(Map.from_struct(request))
        request_str = String.replace(request_str, "%", "")
        response_str = inspect(Map.from_struct(response))
        response_str = String.replace(response_str, "%", "")
        http_version_str = inspect(http_version)
        "URL+Method (identifier): #{url_method}\n Removal: {\n  http_version: #{http_version_str}\n  request: #{request_str}\n  response: #{response_str}}\n"
      end)

    # combining the changes, additions and removals
    changes ++ additions ++ removals
  end

  defp identifier(%MainObject{request: %Request{url: url, method: method}}), do: {url, method}

  def read_parse_json(path) do
    {:ok, content} = File.read(path)

    # decoding/parsing the json content as per the structs defined above
    parsed_content =
      Poison.decode!(content,
        as: [
          %MainObject{
            request: %Request{headers: [%Header{}]},
            response: %Response{headers: [%Header{}]}
          }
        ]
      )
    parsed_content
  end
end

defmodule CustomLogger do
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
        req1.url != req2.url ->
          changes ++
            [
              "URL+Method (identifier): #{req1.url},#{req1.method} \n Request URL Change: \n  #{req1.url} -> #{req2.url}\n"
            ]

        true ->
          changes
      end

    # Check for method differences
    changes =
      cond do
        req1.method != req2.method ->
          changes ++
            [
              "URL+Method (identifier): #{req1.url},#{req1.method} \n Request Method Change: \n  #{req1.method} -> #{req2.method}\n"
            ]

        true ->
          changes
      end

    # Check for body differences
    changes =
      cond do
        req1.body != req2.body ->
          changes ++
            [
              "URL+Method (identifier): #{req1.url},#{req1.method} \n Request Body Change: \n  #{req1.body} -> #{req2.body}\n"
            ]

        true ->
          changes
      end

    # compare headers
    header_changes = compare_headers(req1, req2, req1.headers, req2.headers)
    changes = changes ++ header_changes

    changes
  end

  def compare_response(key, resp1, resp2) do
    # compare status code
    # compare status text
    # compare body
    # compare headers

    changes = []
    # get the values of the key tuple and concatenate to string
    key = "#{elem(key, 0)},#{elem(key, 1)}"

    changes =
      cond do
        resp1.status_code != resp2.status_code ->
          changes ++
            [
              "URL+Method (identifier): #{key} \n Response Status Code Change: \n  #{resp1.status_code} -> #{resp2.status_code}\n"
            ]

        true ->
          changes
      end

    changes =
      cond do
        resp1.status_text != resp2.status_text ->
          changes ++
            [
              "URL+Method (identifier): #{key} \n Response Status Text Change: \n  #{resp1.status_text} -> #{resp2.status_text}\n"
            ]

        true ->
          changes
      end

    changes =
      cond do
        resp1.body != resp2.body ->
          changes ++
            ["URL+Method (identifier): #{key} \n Response Body Change: \n  #{resp1.body} -> #{resp2.body}\n"]

        true ->
          changes
      end

    # compare headers
    header_changes = compare_headers(key, resp1.headers, resp2.headers)
    changes = changes ++ header_changes

    changes
  end

  def compare_headers(req1, _req2, headers1, headers2) do
    # comparing headers' order and content
    zipped_changes = Enum.flat_map(Enum.zip(headers1, headers2), fn
      {h1, h2} when h1 != h2 ->
        ["URL+Method (identifier): #{req1.url},#{req1.method}\n Header Change: \n  #{h1.name}: #{h1.value} ->\n  #{h2.name}: #{h2.value}\n"]
      _ ->
        []
    end)

    # finding header additions and removals
    additions_changes = Enum.flat_map(headers2 -- headers1, fn header ->
      ["URL+Method (identifier): #{req1.url},#{req1.method}\nHeader Addition: \n  #{header.name}: #{header.value}\n"]
    end)

    removals_changes = Enum.flat_map(headers1 -- headers2, fn header ->
      ["URL+Method (identifier): #{req1.url},#{req1.method}\nHeader Removal: \n  #{header.name}: #{header.value}\n"]
    end)

    changes = zipped_changes ++ additions_changes ++ removals_changes
    changes
  end

  def compare_headers(key, headers1, headers2) do
    # comparing headers' order and content
    zipped_changes = Enum.flat_map(Enum.zip(headers1, headers2), fn
      {h1, h2} when h1 != h2 ->
        ["URL+Method (identifier): #{key} \n Header Change: \n  #{h1.name}: #{h1.value} ->\n  #{h2.name}: #{h2.value}\n"]
      _ ->
        []
    end)

    # finding header additions and removals
    additions_changes = Enum.flat_map(headers2 -- headers1, fn header ->
      ["URL+Method (identifier): #{key} \n Header Addition: \n  #{header.name}: #{header.value}\n"]
    end)

    removals_changes = Enum.flat_map(headers1 -- headers2, fn header ->
      ["URL+Method (identifier): #{key} \n Header Removal: \n  #{header.name}: #{header.value}\n"]
    end)

    changes = zipped_changes ++ additions_changes ++ removals_changes
    changes
  end
end
