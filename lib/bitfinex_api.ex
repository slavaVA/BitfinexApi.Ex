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
  
  defmodule TradeTicker do
    @moduledoc false
    @type t :: %BitfinexApi.TradeTicker{
      bid: non_neg_integer,
      bid_size: non_neg_integer,
      ask: non_neg_integer,
      ask_size: non_neg_integer,
      daily_change: non_neg_integer,
      daily_change_perc: non_neg_integer,
      last_price: non_neg_integer,
      volume: non_neg_integer,
      high: non_neg_integer,
      low: non_neg_integer
    }
    @enforce_keys [
      :bid,
      :bid_size,
      :ask,
      :ask_size,
      :daily_change,
      :daily_change_perc,
      :last_price,
      :volume,
      :high,
      :low
    ]
    defstruct [
      :bid,
      :bid_size,
      :ask,
      :ask_size,
      :daily_change,
      :daily_change_perc,
      :last_price,
      :volume,
      :high,
      :low
    ]
  end
end
