defmodule BitfinexApi do
  @moduledoc """
  Documentation for BitfinexApi.
  """
  defmodule Candle do
    @moduledoc false
    @type t :: %BitfinexApi.Candle{
      time: non_neg_integer,
      open: non_neg_integer,
      high: non_neg_integer,
      low: non_neg_integer,
      close: non_neg_integer,
      volume: non_neg_integer
    }
    @enforce_keys [:time, :open, :high, :low, :close, :volume]
    defstruct [:time, :open, :high, :low, :close, :volume]
  end
  
end
