defmodule BitfinexApi.Public.Ws.Protocol do
    require Logger

    defmodule Event do
        @enforce_keys [:event]
        @derive [Poison.Encoder]
        defstruct [:event, :version, :code, :msg, :flags, :channel, :chanId, :key]
    end

    def decode_message(str) do
        case Poison.decode(str, keys: :atoms!) do
            {:ok, v} ->
                decode_json(v)
            err ->
                err
        end
    end
   
    def decode_json(json) when is_map(json) do
        event = struct(Event, json)
        # event=%Event{}|>Map.merge(json)
        {:ok, event}
    end

    def decode_json(json) when is_list(json) do
        # IO.puts inspect json
        {:ok, {Enum.at(json, 0), Enum.at(json, 1)}}
    end

    def decode_json(json)  do
        Logger.warn("Unknown JSON message:#{inspect json}")
        {:error}
    end    
   
    def decode_channel_data(ch, data) do
        case ch do
            :candles ->
                candle = %BitfinexApi.Candle{time: Enum.at(data, 0),
                        open: Enum.at(data, 1),
                        high: Enum.at(data, 3),
                        low: Enum.at(data, 4),
                        close: Enum.at(data, 2),
                        volume: Enum.at(data, 5)
                }
                {:ok, candle}
            _ ->
                :error
        end
    end

    def encode_subscribe_request(channel_name, key) do
        ~s({"event":"subscribe","channel":"#{channel_name}","key":"#{key}"})
    end

    def encode_unsubscribe_request(channel_id) do
      ~s({"event":"unsubscribe","chanId":"#{channel_id}"})
    end

end