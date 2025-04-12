defmodule ProvChain.Utils.Serialization do
  @moduledoc """
  Utilities for serializing and deserializing data structures.
  Provides consistent encoding/decoding across the system.
  """

  @doc """
  Encodes data into a binary.
  For transactions or lists of transactions, uses term_to_binary to preserve binary hashes.
  For other data, uses JSON encoding.
  """
  @spec encode(term()) :: binary()
  def encode(data) when is_map(data) and is_map_key(data, "hash") do
    sanitized_data = sanitize_for_json(data)
    :erlang.term_to_binary(sanitized_data)
  end
  def encode(data) when is_list(data) do
    # ตรวจสอบว่า list มี map ที่มี key "hash" หรือไม่
    if Enum.any?(data, &is_map(&1) and is_map_key(&1, "hash")) do
      sanitized_data = sanitize_for_json(data)
      :erlang.term_to_binary(sanitized_data)
    else
      serializable_data = sanitize_for_json(data)
      Jason.encode!(serializable_data)
    end
  end
  def encode(data) do
    serializable_data = sanitize_for_json(data)
    Jason.encode!(serializable_data)
  end

  # คงส่วนที่เหลือไว้เหมือนเดิม
  @doc """
  Decodes a binary into an Elixir term.
  For transactions, uses binary_to_term to preserve binary hashes.
  For other data, uses JSON decoding.
  """
  @spec decode(binary()) :: {:ok, term()} | {:error, any()}
  def decode(binary) when is_binary(binary) do
    try do
      term = :erlang.binary_to_term(binary, [:safe])
      {:ok, term}
    rescue
      _ -> Jason.decode(binary)
    end
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
    |> Enum.map(fn {k, v} -> {to_string(k), sanitize_for_json(v)} end)
    |> Map.new()
  end
  def struct_to_map(value), do: sanitize_for_json(value)

  # Sanitizes data for JSON encoding
  defp sanitize_for_json(data) when is_map(data) do
    Enum.map(data, fn
      {"hash", v} -> {"hash", v} # คง binary สำหรับ hash
      {k, v} -> {to_string(k), sanitize_for_json(v)}
    end)
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
