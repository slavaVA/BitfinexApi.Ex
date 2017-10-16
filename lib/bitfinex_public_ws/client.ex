defmodule BitfinexApi.Public.Ws.Client do
    use WebSockex
    require Logger
    alias BitfinexApi.Public.Ws.ProtocolHandler
    alias BitfinexApi.Public.Ws.Protocol
    
    @url "wss://api.bitfinex.com/ws/2"

    def start_link(_opts \\ []) do
        WebSockex.start_link(@url, __MODULE__, {},[name: __MODULE__, debug: [:trace]])
    end

    def subscribe_to_channel(pid, channel_name, key) do
        Logger.info("Sending subscribe request: channel=#{channel_name} key=#{key}")
        WebSockex.send_frame(pid, {:text, Protocol.encode_subscribe_request(channel_name,key)})
    end

    def unsubscribe_to_channel(pid, channel_id) do
      Logger.info("Sending unsubscribe request: channelId=#{channel_id}")
      WebSockex.send_frame(pid, {:text, Protocol.encode_unsubscribe_request(channel_id)})
    end

    def handle_connect(_conn, state) do
        Logger.info("Connect")
        ProtocolHandler.client_connected(self())
        {:ok, state}
    end
    
    def handle_frame({:text,msg}, state) do
        Logger.debug("Receive frame #{inspect msg}")
        ProtocolHandler.receive_message(msg)
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
        Logger.info("Dissconnect with reason: #{inspect connection_status_map}")     
        ProtocolHandler.client_disconnected()   
        {:reconnect, state}
        # super(disconnect_map, state)
    end
    
end