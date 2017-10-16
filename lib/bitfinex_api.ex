defmodule BitfinexApi do
  @moduledoc """
  Documentation for BitfinexApi.
  """
  defmodule Candle do
    @enforce_keys [:time, :open, :high, :low, :close, :volume]
    defstruct [:time, :open, :high, :low, :close, :volume]
  end

  @doc """
  Hello world.

  ## Examples

      iex> BitfinexApi.hello
      :world

  """
  def hello do
    :world
  end
end
