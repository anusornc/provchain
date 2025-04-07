defmodule ProvChain.Utils.Serialization do
  @moduledoc """
  Utilities for serializing and deserializing data structures.

  Provides consistent encoding/decoding across the system.
  """

  @doc """
  Encodes a data structure to binary format.

  Uses JSON encoding with deterministic key ordering to ensure
  consistent hashing results.

  ## Parameters
    - data: The data structure to encode

  ## Returns
    Binary representation of the data
  """
  @spec encode(term()) :: binary()
  def encode(data) do
    # Pre-sanitize data to ensure it's encodable
    serializable_data = sanitize_for_json(data)

    # Handle map ordering manually for atom key maps
    serializable_data = sort_map_keys(serializable_data)

    # Try to encode with Jason without catching exceptions
    encoded_json =
      try do
        # Here we're using Jason.encode! with manually sorted maps
        # so the sort_maps option isn't needed
        Jason.encode!(serializable_data)
      catch
        # Only catch specific known pattern matches
        :error, _ ->
          # Fallback for data that can't be encoded
          inspect(data, limit: :infinity)
      end

    # Return the encoded JSON
    encoded_json
  end

  # Manually sort map keys to ensure deterministic ordering
  defp sort_map_keys(data) when is_map(data) do
    data
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {k, sort_map_keys(v)} end)
    |> Enum.into(%{})
  end

  defp sort_map_keys(data) when is_list(data) do
    Enum.map(data, &sort_map_keys/1)
  end

  defp sort_map_keys(data), do: data

  @doc """
  Decodes binary data into an Elixir data structure.

  ## Parameters
    - binary: The binary data to decode

  ## Returns
    {:ok, decoded_data} or {:error, reason}
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, any()}
  def decode(binary) when is_binary(binary) do
    Jason.decode(binary)
  end

  @doc """
  Decodes binary data into an Elixir data structure with atom keys.

  ## Parameters
    - binary: The binary data to decode

  ## Returns
    {:ok, decoded_data} or {:error, reason}
  """
  @spec decode_with_atoms(binary()) :: {:ok, map()} | {:error, any()}
  def decode_with_atoms(binary) when is_binary(binary) do
    Jason.decode(binary, keys: :atoms)
  end

  @doc """
  Encodes a struct to a map that can be serialized.

  Handles special Elixir types like DateTime.

  ## Parameters
    - struct: The struct to encode

  ## Returns
    A map representation of the struct
  """
  @spec struct_to_map(struct()) :: map()
  def struct_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {k, prepare_value(v)} end)
    |> Enum.into(%{})
  end

  @spec struct_to_map(struct()) :: map()
  def struct_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {k, prepare_value(v)} end)
    |> Enum.into(%{})
  end

  # Sanitizes data for JSON encoding, removing any problematic elements
  @spec sanitize_for_json(term()) :: term()
  defp sanitize_for_json(data) when is_map(data) do
    data
    |> Enum.filter(fn {_k, v} -> is_json_encodable(v) end)
    |> Enum.map(fn {k, v} -> {k, sanitize_for_json(v)} end)
    |> Enum.into(%{})
  end

  defp sanitize_for_json(data) when is_list(data) do
    data
    |> Enum.filter(&is_json_encodable/1)
    |> Enum.map(&sanitize_for_json/1)
  end

  defp sanitize_for_json(%_{} = struct) do
    # Convert structs to maps
    struct
    |> Map.from_struct()
    |> sanitize_for_json()
  end

  defp sanitize_for_json(data), do: data

  # Checks if a value is JSON encodable
  defp is_json_encodable(nil), do: true
  defp is_json_encodable(data) when is_binary(data), do: true
  defp is_json_encodable(data) when is_number(data), do: true
  defp is_json_encodable(data) when is_boolean(data), do: true
  defp is_json_encodable(data) when is_list(data), do: true
  defp is_json_encodable(data) when is_map(data), do: true
  defp is_json_encodable(_), do: false

  # Helper functions for handling special types
@spec prepare_value(term()) :: term()
defp prepare_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
defp prepare_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
defp prepare_value(%Date{} = d), do: Date.to_iso8601(d)
defp prepare_value(%Time{} = t), do: Time.to_iso8601(t)
defp prepare_value(struct) when is_struct(struct), do: struct_to_map(struct)
defp prepare_value(map) when is_map(map) and not is_struct(map) do
  map |> Enum.map(fn {k, v} -> {k, prepare_value(v)} end) |> Enum.into(%{})
end
defp prepare_value(list) when is_list(list), do: Enum.map(list, &prepare_value/1)
defp prepare_value(binary) when is_binary(binary), do: binary
defp prepare_value(other), do: other
  
end
