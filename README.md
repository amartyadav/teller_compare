# TellerCompare

CLI tool that accepts two json files containing the API responses and deep compares them. The output is generated and saved in a file "output_diff.txt", saved in the project path.
## Run

Github Repository: [teller-compare](https://github.com/amartyadav/teller_compare)

The tool can be run by cloning/downloading the project directory locally.
-  Download the code directory or Clone the project locally
- `mix deps.get` in the terminal under the project directory path
- The project direcotry currently contains the example files at the root level. Running `mix run -e "TellerCompare.main([\"13.3.7.json\", \"13.4.0.json\"])"` runs the tool with those two files as the arguments. The output file is generated at the same root level as the input files named 'output_diff.txt'.

## Code Explanation and Decision Justification
#### General Overview
The tool accepts two json files as arguments from the terminal. It proceeds to parse the json files using Poison. 

After the posion decoding, the parsed data is passed to the `compare_data_deep/2` function. 
This function converts it into a map with the `URL+HTTP Method` as the key, and the json object as the value.
The `compare_requests/2` and `compare_response/3` functions are called to compare the requests portion and the response portion of the json objects seperately. These functions are only called for the json objects in the files that have common keys (here, URL+Method) to identify the changes in the existing objects. 
After the changes in the existing json objects are identified, new json objects which are added to the second file are identified, and the json objects that have been removed from the second file are identified.

The final result contains the changes + additions + removals between the two files. 
This output is then returned and written to the output file.

#### Specific Function Explanation
##### `compare_headers/4`

This function compares the headers of the requests part of the json object. It performs a deep comparision based on the order of the headers, and the content of the headers. It also formats the output for the difference in headers.
```
zipped_changes =
      Enum.flat_map(Enum.zip(headers1, headers2), fn
        {h1, h2} when h1 != h2 ->
          [
            "URL+Method (identifier): #{req1.url},#{req1.method}\n Header Change: \n  #{h1.name}: #{h1.value} ->\n  #{h2.name}: #{h2.value}\n"
          ]

        _ ->
          []
      end)
```

##### `compare_headers/3`

This function compares the headers of the response part of the json object. It performs a deep comparision based on the order of the headers, and the content of the headers just like the `compare_headers/4` function. It is a seperate function as it accepts the `key` as an argument to generate the identifier in the output since the response part does not contain the url+method. It also formats the output for the difference in headers.
```
zipped_changes =
      Enum.flat_map(Enum.zip(headers1, headers2), fn
        {h1, h2} when h1 != h2 ->
          [
            "URL+Method (identifier): #{key} \n Header Change: \n  #{h1.name}: #{h1.value} ->\n  #{h2.name}: #{h2.value}\n"
          ]

        _ ->
          []
      end)
```

Both these functions check for header additions/removals using the list operators `--`.
```
additions_changes =
      Enum.flat_map(headers2 -- headers1, fn header ->
        [
          "URL+Method (identifier): #{req1.url},#{req1.method}\nHeader Addition: \n  #{header.name}: #{header.value}\n"
        ]
      end)

    removals_changes =
      Enum.flat_map(headers1 -- headers2, fn header ->
        [
          "URL+Method (identifier): #{req1.url},#{req1.method}\nHeader Removal: \n  #{header.name}: #{header.value}\n"
        ]
      end)
```
<br>

##### `compare_requests/2`
This function checks for changes in the URL, Method, and body of the Requests part of the JSON object. It then calls the `compare_header/4` function to compare the headers, and appends all the output to the `changes` list. 
```
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
```
<br>

##### `compare_response/3`
This method performs the same steps in the same way, but accepts the key of the data map as an additional argument to generate the identifier (URL+Method) since response does not contain those fields. It calls the `compare_headers/3` function. All the output gets appended to the `changes` list.
<br>

##### `compare_data_deep/2`
The purpose of this function has been discussed in the 'General Overview' section above.

##### Structs for Poison Decode
```
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
```

These structs were defined to aid in the decoding/parsing of the json objects, since they were nested (in case of headers, for example). 

#### Summary and Final Notes
The tool performs what was expected in the challenge requirement document to some extent. This can be further improved/extended to provide additional details in the formatting to enhance the developer experience. The current output file is a txt file. This could be changed to a html file with proper formatting based on colour to differentiate the changes, additions, removals. Further, a frontend web app/GUI could be made to which this tool gives the data for being more user friendly (showing specific changes based on filters, auto highlight the changes in the original files etc.)

Given the limitations of time, only the basic functionality was developed, as described in the requirements document.




