defmodule BitfinexApi.Public.Ws.Client do 
    use WebSockex
    require Logger
    alias BitfinexApi.Public.Ws.Endpoint

    @moduledoc false
    
    @url "wss://api.bitfinex.com/ws/2"

    def start_link(up_level, opts \\ []) do
        full_opt = opts
        |> Keyword.delete(:name)
        |> Keyword.put(:name, __MODULE__)
        WebSockex.start_link(@url, __MODULE__, %{up_level: up_level}, full_opt)
    end

    def send_frame(pid, frame) do
        Logger.debug(fn -> "Send frame: #{frame}" end)
        WebSockex.send_frame(pid, {:text, frame})
    end
    
    def handle_connect(_conn, state) do
        Logger.info(fn -> "Connect to: #{@url}" end)
        Endpoint.client_connected(state.up_level)
        {:ok, state}
    end
    
    def handle_frame({:text, msg}, state) do
        Logger.debug(fn -> "Receive frame #{inspect msg}" end)
        Endpoint.receive_message(state.up_level, msg)
        {:ok, state}
    end

    def handle_info({:ssl_closed, add_info}, state) do
        Logger.warn("Receive SSL disconnect #{inspect add_info}")
        {:close, state}
    end
    
    # def handle_ping(ping_frame, state) do
    #     Logger.info("Ping: #{inspect ping_frame}")                
    # end
    
    # def handle_pong(pong_frame, state) do
    #     Logger.info("Ping: #{inspect pong_frame}")                
    # end
    
    def handle_disconnect(connection_status_map, state) do
        Logger.info("Disconnect with reason: #{inspect connection_status_map}")     
        Endpoint.client_disconnected(state.up_level)
        {:reconnect, state}
        # super(disconnect_map, state)
    end
end
