defmodule ProvChain.Crypto.Hash do
  @moduledoc """
  Cryptographic hashing utilities for ProvChain.

  Provides secure hashing functions and Merkle tree operations.
  """

  @doc """
  Computes the hash of the given data.

  Uses SHA-256 for secure hashing.

  ## Parameters
    - data: Data to be hashed

  ## Returns
    The hash value as a binary
  """
  @spec hash(binary()) :: binary()
  def hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data)
  end

  @spec hash(term()) :: binary()
  def hash(data) do
    data
    |> :erlang.term_to_binary()
    |> hash()
  end

  @doc """
  Computes the Merkle root of a list of hashes.

  ## Parameters
    - hashes: List of hash values

  ## Returns
    The Merkle root hash or a zero hash if the list is empty
  """
  @spec merkle_root(list(binary())) :: binary()
  def merkle_root([]), do: <<0::256>>  # Return zero hash (32 bytes) for empty list
  def merkle_root([single_hash]), do: single_hash
  def merkle_root(hashes) when is_list(hashes) do
    # Ensure even number of hashes by duplicating the last one if needed
    hashes = if rem(length(hashes), 2) == 1 do
      hashes ++ [List.last(hashes)]
    else
      hashes
    end

    # Combine adjacent pairs of hashes
    combined = Enum.chunk_every(hashes, 2)
               |> Enum.map(fn [h1, h2] -> hash(h1 <> h2) end)

    # Recursively compute the Merkle root of the combined hashes
    merkle_root(combined)
  end

  @doc """
  Computes the double hash of the given data (SHA-256(SHA-256(data))).

  ## Parameters
    - data: Data to be double-hashed

  ## Returns
    The double hash value as a binary
  """
  @spec double_hash(binary()) :: binary()
  def double_hash(data) when is_binary(data) do
    data
    |> hash()
    |> hash()
  end

  @doc """
  Converts a hash binary to a hexadecimal string representation.

  ## Parameters
    - hash: Hash binary

  ## Returns
    The hash in hexadecimal string format
  """
  @spec to_hex(binary()) :: String.t()
  def to_hex(hash) when is_binary(hash) do
    Base.encode16(hash, case: :lower)
  end

  @doc """
  Converts a hexadecimal string to a hash binary.

  ## Parameters
    - hex_string: Hash in hexadecimal string format

  ## Returns
    The hash as a binary
  """
  @spec from_hex(String.t()) :: binary()
  def from_hex(hex_string) when is_binary(hex_string) do
    Base.decode16!(hex_string, case: :mixed)
  end
end
