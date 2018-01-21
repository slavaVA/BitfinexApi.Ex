defmodule BitfinexApi.Public.Ws.Test do
  use ExUnit.Case,  async: false

  alias BitfinexApi.Public.Ws.Protocol
  alias BitfinexApi.Public.Ws.Endpoint
  alias BitfinexApi.Public.Ws.Client, as: WsClient

  import Mock

  test "Connect sequnce" do
    this=self()

    with_mock WsClient, [
      start_link: fn(_up_level, _opts)->{:ok, this} end,
      send_frame: fn(pid, frame)->Kernel.send(pid, frame) end
      ] do
        key="trade:1m:tBTCUSD"

        msg_info_version="{\"event\":\"info\",\"version\":2}"

        {:ok, pid}=Endpoint.start_link
        
        Endpoint.connect(pid)

        Endpoint.client_connected(pid)

        assert Endpoint.get_version(pid)==nil

        Endpoint.receive_message(pid, msg_info_version)

        assert Endpoint.get_version(pid)==2

        assert Endpoint.is_subscribed(pid, self(), :candles, key)==false

        Endpoint.subscribe_candles(pid, self(), key)
        assert Endpoint.is_subscribed(pid, self(), :candles, key)==true

        assert_receive ~s({"event":"subscribe","channel":"candles","key":"trade:1m:tBTCUSD"}), 500

        msg_subscribed="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"
        :ok=Endpoint.receive_message(pid, msg_subscribed)

        assert Endpoint.get_channel_id(pid, :candles, key)==118949

        assert Endpoint.get_channel_id(pid, :candles1, key)==nil
              
        Endpoint.unsubscribe_candles(pid, self(), key)
        assert Endpoint.is_subscribed(pid, self(), :candles, key)==false

        assert_receive ~s({"event":"unsubscribe","chanId":"118949"}), 500
    end
  end

  test "Handle connect event after subscription" do
    this=self()
    
    with_mock WsClient, [
      start_link: fn(_up_level, _opts)->{:ok, this} end,
      send_frame: fn(pid, frame)->Kernel.send(pid, frame) end
      ] do
        key="trade:1m:tBTCUSD"

        {:ok, pid}=Endpoint.start_link
        
        Endpoint.connect(pid)

        assert Endpoint.is_subscribed(pid, self(), :candles, key)==false
        
        Endpoint.subscribe_candles(pid, self(), key)
        assert Endpoint.is_subscribed(pid, self(), :candles, key)==true
        
        Endpoint.client_connected(pid)

        assert_receive ~s({"event":"subscribe","channel":"candles","key":"trade:1m:tBTCUSD"}), 500

        msg_subscribed="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"
        :ok=Endpoint.receive_message(pid, msg_subscribed)
          
        Endpoint.unsubscribe_candles(pid, self(), key)
        assert Endpoint.is_subscribed(pid, self(), :candles, key)==false

        assert_receive ~s({"event":"unsubscribe","chanId":"118949"}), 500
    end        
  end

  test "Handle channel snapshot" do
    this=self()
    with_mock WsClient, [
      start_link: fn(_up_level,_opts)->{:ok, this} end,
      send_frame: fn(pid, frame)->Kernel.send(pid, frame) end
      ] do
    
        key="trade:1m:tBTCUSD"

        snapshot_data="""
        [118949,[[1506845100000,4335.1,4335.1,4335.1,4335.1,0.513457],[1506845040000,4337.5,4335,4337.5,4335,1.07204968]]]
        """
        subscribed_event="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"

        {:ok, pid}=Endpoint.start_link
        
        {:ok, {ch, data}}=Protocol.decode_message(snapshot_data)
        assert ch==118949
        assert length(data)==2

        Endpoint.subscribe_candles(pid, self(), key)

        symbol="tBTCUSD"
        Endpoint.subscribe_ticker(pid, self(), symbol)

        Endpoint.receive_message(pid, subscribed_event)

        Endpoint.receive_message(pid, snapshot_data)

        assert_receive {:cahnnel_data, :candles, {"trade:1m:tBTCUSD", %BitfinexApi.Candle{close: 4335.1, high: 4335.1, low: 4335.1, open: 4335.1, time: 1506845100000, volume: 0.513457}}}
        assert_receive {:cahnnel_data, :candles, {"trade:1m:tBTCUSD", %BitfinexApi.Candle{close: 4335, high: 4337.5, low: 4335, open: 4337.5, time: 1506845040000, volume: 1.07204968}}}

        subscribed_event="{\"event\":\"subscribed\",\"channel\":\"ticker\",\"chanId\":2,\"symbol\":\"tBTCUSD\",\"pair\":\"BTCUSD\"}"
        Endpoint.receive_message(pid, subscribed_event)

        snapshot_data="""
        [2,[11780,66.13829346,11781,66.38159777,-701,-0.0562,11780,45859.26458538,13017,11621]]
        """        
        Endpoint.receive_message(pid, snapshot_data)

        assert_receive {:cahnnel_data, :ticker, {"tBTCUSD", %BitfinexApi.TradeTicker{ask: 11781, ask_size: 66.38159777, bid: 11780,
        bid_size: 66.13829346, daily_change: -701, daily_change_perc: -0.0562,
        high: 13017, last_price: 11780, low: 11621, volume: 45859.26458538}}}        

      end
  end

  defp wait_end do
    IO.puts "Start receive"
    receive do
      :end->
        IO.puts "End"
        :ok
      other->
        IO.inspect(other)
        wait_end()
    end  
  end
  
  test "Test subscriber termination" do
    this=self()
    with_mock WsClient, [
      start_link: fn(_up_level, _opts)->{:ok, this} end,
      send_frame: fn(pid, frame)->Kernel.send(pid, frame) end
      ] do
    
        key="trade:1m:tBTCUSD"
        
        {:ok, pid}=Endpoint.start_link

        {:ok, s_pid}=Task.start(fn->wait_end() end)
        ref=Process.monitor(s_pid)

        Endpoint.subscribe_candles(pid, s_pid, key)

        assert Endpoint.is_subscribed(pid, s_pid, :candles, key)==true

        send(s_pid, :end)
        assert_receive {:DOWN, _, :process, _, _}, 1000

        assert Endpoint.is_subscribed(pid, s_pid, :candles, key)==false
      end
  end
end
