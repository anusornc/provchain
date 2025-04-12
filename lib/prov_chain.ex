defmodule ProvChain do
  @moduledoc """
  Documentation for `ProvChain`.

  ProvChain is a permissioned blockchain system that combines Block-DAG structure
  with PROV-O ontology and Knowledge Graph technology to create a high-throughput
  supply chain traceability solution.

  This module provides the primary interface for interacting with the ProvChain system.
  """

  @doc """
  Returns the current version of the ProvChain system.

  ## Examples

      iex> ProvChain.version()
      "0.1.0"

  """
  def version do
    "0.1.0"
  end

  @doc """
  Generates a new keypair for use in the ProvChain system.

  ## Examples

      iex> {:ok, {private, public}} = ProvChain.generate_keypair()
      iex> byte_size(private) == 32
      true
      iex> byte_size(public) == 32
      true

  """
  def generate_keypair do
    ProvChain.Crypto.Signature.generate_key_pair()
  end

  @doc """
  Returns information about the current blockchain state.

  ## Examples

      iex> ProvChain.chain_info()
      %{version: "0.1.0", status: :initializing}

  """
  def chain_info do
    %{
      version: version(),
      status: :initializing,
      # These will be implemented in later phases
      # height: ProvChain.BlockDag.Dag.height(),
      # tx_count: ProvChain.BlockDag.Dag.tx_count(),
    }
  end
end
