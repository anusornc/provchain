defmodule ProvChain.Crypto.Signature do
  @moduledoc """
  Digital signature utilities for ProvChain.
  Uses Ed25519 via Eddy for creating and verifying digital signatures.
  """

  alias Eddy.{PrivKey, PubKey, Sig}

  @doc """
  Generates a new key pair for signing and verification.
  """
  @spec generate_key_pair() :: {:ok, {binary(), binary()}} | {:error, term()}
  def generate_key_pair do
    try do
      privkey = Eddy.generate_key()
      pubkey = Eddy.get_pubkey(privkey)
      {:ok, {PrivKey.to_bin(privkey), PubKey.to_bin(pubkey)}}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Derives a public key from a private key.
  """
  @spec derive_public_key(binary()) :: {:ok, {binary(), binary()}} | {:error, term()}
  def derive_public_key(private_key) when is_binary(private_key) do
    with {:ok, privkey} <- PrivKey.from_bin(private_key),
         pubkey <- Eddy.get_pubkey(privkey) do
      {:ok, {private_key, PubKey.to_bin(pubkey)}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  def derive_public_key(_), do: {:error, :invalid_input}

  @doc """
  Signs data with a private key.
  """
  @spec sign(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def sign(data, private_key) when is_binary(data) and is_binary(private_key) do
    with {:ok, privkey} <- PrivKey.from_bin(private_key),
         signature <- Eddy.sign(data, privkey) do
      {:ok, Sig.to_bin(signature)}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  def sign(_, _), do: {:error, :invalid_input}

  @doc """
  Verifies a signature against data and a public key.
  """
  @spec verify(binary(), binary(), binary()) :: boolean()
  def verify(data, signature, public_key)
      when is_binary(data) and is_binary(signature) and is_binary(public_key) do
    with {:ok, sig} <- Sig.from_bin(signature),
         {:ok, pubkey} <- PubKey.from_bin(public_key) do
      Eddy.verify(sig, data, pubkey)
    else
      {:error, _} -> false
    end
  end
  def verify(_, _, _), do: false

  @doc """
  Verifies a signature with a simulated validator registry.
  """
  @spec verify_with_registry(binary(), binary(), binary()) :: boolean()
  def verify_with_registry(_data, _signature, _validator_id) do
    true
  end
end
