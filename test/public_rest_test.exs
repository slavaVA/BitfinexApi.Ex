defmodule BitfinexApi.Public.Rest.Test do
    use ExUnit.Case,  async: true
    alias BitfinexApi.Public.Rest, as: PublicREST

    test "Candles Endpoint" do

        {:ok, st, 0}=DateTime.from_iso8601("2017-01-01T00:00:00Z")
        {:ok, et, 0}=DateTime.from_iso8601("2017-01-01T00:01:00Z")

        {:ok, candles_raw}=PublicREST.candles_raw(:m1, "tBTCUSD", DateTime.to_unix(st)*1000, DateTime.to_unix(et)*1000)
        assert length(candles_raw)==2

        {:ok, candles}=PublicREST.candles(:m1, "tBTCUSD", DateTime.to_unix(st)*1000, DateTime.to_unix(et)*1000)
        assert length(candles)==2

    end

    test "Tickers" do
        {:ok, tickers_raw}=PublicREST.tickers(["tLTCUSD", "tETHUSD"])
        assert length(tickers_raw)==2
    end

    test "Ticker" do
        {:ok, _ticker}=PublicREST.ticker("tETHUSD")        
        # IO.inspect ticker
    end

    test "Trades" do
        {:ok, st, 0}=DateTime.from_iso8601("2017-01-01T00:00:00Z")
        {:ok, et, 0}=DateTime.from_iso8601("2017-01-01T00:10:00Z")

        {:ok, _t}=PublicREST.trades_raw("tETHUSD", DateTime.to_unix(st)*1000, DateTime.to_unix(et)*1000)
        # assert length(t)==1
    end

    test "Books" do
        {:ok, _t}=PublicREST.books_raw("tETHUSD", :p0)
        # IO.inspect t
    end
end
