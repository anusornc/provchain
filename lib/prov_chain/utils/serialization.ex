defmodule ProvChain.Utils.Serialization do
  @moduledoc """
  Utilities for serializing and deserializing data structures.
  Provides consistent encoding/decoding across the system.
  """

  @doc """
  Encodes data into a JSON binary string.
  """
  @spec encode(term()) :: binary()
  def encode(data) do
    serializable_data = sanitize_for_json(data)
    Jason.encode!(serializable_data)
  end

  @doc """
  Decodes a JSON binary string into an Elixir term.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, any()}
  def decode(binary) when is_binary(binary) do
    Jason.decode(binary)
  end

  @doc """
  Decodes a JSON binary string into an Elixir term with atom keys.
  """
  @spec decode_with_atoms(binary()) :: {:ok, map()} | {:error, any()}
  def decode_with_atoms(binary) when is_binary(binary) do
    Jason.decode(binary, keys: :atoms)
  end

  @doc """
  Converts a struct to a serializable map by removing __struct__ and handling nested structs.
  """
  @spec struct_to_map(term()) :: term()
  def struct_to_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> {k, sanitize_for_json(v)} end)
    |> Map.new()
  end
  def struct_to_map(value), do: sanitize_for_json(value)

  # Sanitizes data for JSON encoding
  defp sanitize_for_json(data) when is_map(data) do
    Enum.map(data, fn {k, v} -> {k, sanitize_for_json(v)} end)
    |> Enum.into(%{})
  end

  defp sanitize_for_json(data) when is_list(data) do
    Enum.map(data, &sanitize_for_json/1)
  end

  defp sanitize_for_json(%_{} = struct) do
    struct_to_map(struct)
  end

  defp sanitize_for_json(data) when is_binary(data) do
    if String.valid?(data), do: data, else: Base.encode16(data, case: :upper)
  end

  defp sanitize_for_json(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp sanitize_for_json(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp sanitize_for_json(%Date{} = d), do: Date.to_iso8601(d)
  defp sanitize_for_json(%Time{} = t), do: Time.to_iso8601(t)
  defp sanitize_for_json(data) when is_function(data), do: nil
  defp sanitize_for_json(data), do: data
end
