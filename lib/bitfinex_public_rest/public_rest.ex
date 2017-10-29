defmodule BitfinexApi.Public.Rest do
    use Tesla

    plug Tesla.Middleware.BaseUrl, "https://api.bitfinex.com/v2/"
    plug Tesla.Middleware.JSON
    plug Tesla.Middleware.Logger

    @time_frame_map %{
        m1: "1m", m5: "5m", m15: "15m", m30: "30m",
        h1: "1h", h3: "3h", h6: "6h", h12: "12h",
        D1: "1D", D7: "7D", D14: "14D",
        M1: "1M"
    }

    @section_map %{hist: "hist", last: "last"}

    @precision_map %{p0: "P0", p1: "P1", p2: "P2", p3: "P3", r0: "R0"}    

    @type time_frame_type :: :m1 | :m5 | :m15 | :m30 |
                        :h1 | :h3 | :h6 | :h12 |
                        :D1 | :D7 | :D14 | :M1
    
    @type section_type :: :hist | :last


    @spec candles_raw(time_frame_type, String.t, non_neg_integer, 
                      non_neg_integer, section_type,
                      non_neg_integer, integer) :: {:ok, [[integer]]}
    def candles_raw(time_frame, symbol, start_time, end_time, section \\ :hist, limit \\ 100, sort \\ -1) do
        resp = get("/candles/trade:" <> @time_frame_map[time_frame] <> ":" <> symbol <> "/" <> @section_map[section],
        query: [start: start_time, end: end_time, limit: limit, sort: sort])
        if resp.status == 200 do
            {:ok, resp.body}
        else
            {:error, resp.body}
        end
    end

    @spec candles(time_frame_type, String.t, non_neg_integer,
                        non_neg_integer, section_type,
                        non_neg_integer, integer) :: {:ok, [BitfinexApi.Candle.t]}
    def candles(time_frame, symbol, start_time, end_time, section \\ :hist, limit \\ 100, sort \\ -1) do

        {:ok, raw_candles} = candles_raw(time_frame, symbol, start_time, end_time, section, limit, sort)

        candles = raw_candles |> Enum.map(fn data ->
            %BitfinexApi.Candle{time: Enum.at(data, 0),
            open: Enum.at(data, 1),
            high: Enum.at(data, 3),
            low: Enum.at(data, 4),
            close: Enum.at(data, 2),
            volume: Enum.at(data, 5)}
        end)
        {:ok, candles}
    end

    def status do
        resp = get("/platform/status")
        if resp.status == 200 do
            case resp.body.head do
                0 -> :maintenance
                1 -> :operative
            end
        else
            {:error, resp.body}
        end
    end

    def tickers(symbols) do
        resp = get("/tickers",query: [symbols: Enum.join(symbols, ",")])
        if resp.status == 200 do
            {:ok, resp.body}
        else
            {:error, resp.body}
        end
    end

    def ticker(symbol) do
        resp = get("/ticker/" <> symbol)
        if resp.status == 200 do
            {:ok, resp.body}
        else
            {:error, resp.body}
        end
    end

    def trades_raw(symbol, start_time, end_time,  limit \\ 100, sort \\ -1) do
        resp = get("/trades/" <> symbol <> "/hist",
                    query: [start: start_time, end: end_time, limit: limit, sort: sort])
        if resp.status == 200 do
            {:ok, resp.body}
        else
            {:error, resp.body}
        end
    end

    def books_raw(symbol, precision) do
        resp = get("/book/" <> symbol <> "/" <> @precision_map[precision])
        if resp.status == 200 do
            {:ok, resp.body}
        else
            {:error, resp.body}
        end
    end
    
end
