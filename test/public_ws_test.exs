defmodule BitfinexApi.Public.Ws.Test do
  use ExUnit.Case,  async: false

  alias BitfinexApi.Public.Ws.Protocol
  alias BitfinexApi.Public.Ws.ProtocolHandler

  import Mock

  setup do
    {:ok, pid}=ProtocolHandler.start_link
    on_exit fn->
      ref=Process.monitor(pid)  
      Process.exit(pid, :normal)
      receive do
        {:DOWN, ^ref, :process, _, _}->
          :ok
        other->
          IO.inspect other
      end
    end
  end

  # def socket_receive([h|t],result) do
  #   receive do
  #     {:"$websockex_send", from, {:text,^h}}->
  #       :gen.reply(from, :ok)
  #       socket_receive(t,[true|result])
  #     other->
  #       IO.inspect other  
  #       [false|result]
  #     after
  #       5000->
  #         [false|result]
  #   end
  # end

  # def socket_receive([],result) do
  #   result
  # end

  # def is_all_socket_message_send?(task), do: assert Task.await(task,2000)|>Enum.all?(fn x->x end) == true

  # defp stop_and_wait_termiantion(pid) do
  #     ref  = Process.monitor(pid)    
  #     Process.exit(pid, :normal)
  #     #assert_receive {:DOWN, ^ref, :process, _, :normal}, 1000
  #     assert_receive {:DOWN, ^ref, :process, _, _}, 1000
  # end

  test "Handle version info" do
    msg_info_version="{\"event\":\"info\",\"version\":2}"

    assert ProtocolHandler.get_version == nil

    ProtocolHandler.receive_message(msg_info_version)

    assert ProtocolHandler.get_version == 2

  end

  test "Subscribe/Unsubsribe" do
    key="trade:1m:tBTCUSD"

    assert ProtocolHandler.is_subscribed(self(),:candles,key)==false

    ProtocolHandler.subscribe_candles(self(),key)
    assert ProtocolHandler.is_subscribed(self(),:candles,key)==true

    ProtocolHandler.unsubscribe_candles(self(),key)
    assert ProtocolHandler.is_subscribed(self(),:candles,key)==false
  end

  test "Handle connect event after subscription" do
    with_mock WebSockex, [send_frame: fn(pid,params) -> 
      send(pid, params)
      :ok 
    end] do
      key="trade:1m:tBTCUSD"

      ProtocolHandler.subscribe_candles(self(),key)
      
      ProtocolHandler.client_connected(self())
      
      assert_receive {:text, "{\"event\":\"subscribe\",\"channel\":\"candles\",\"key\":\"trade:1m:tBTCUSD\"}"},1000

      assert ProtocolHandler.is_subscribed(self(),:candles,key)==true

    end
  end

  test "Handle connect event before subscription" do
    with_mock WebSockex, [send_frame: fn(pid,params) -> 
      send(pid, params)
      :ok 
    end] do
      key="trade:1m:tBTCUSD"
      ProtocolHandler.client_connected(self())
      
      ProtocolHandler.subscribe_candles(self(),key)

      assert_receive {:text, "{\"event\":\"subscribe\",\"channel\":\"candles\",\"key\":\"trade:1m:tBTCUSD\"}"},1000

      assert ProtocolHandler.is_subscribed(self(),:candles,key)==true      
    end
  end

  test "Handle subscribed event" do
    key="trade:1m:tBTCUSD"
    msg="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"

    :ok=ProtocolHandler.receive_message(msg)
    assert ProtocolHandler.get_channel_id(:candles,key)==118949
    assert ProtocolHandler.get_channel_id(:candles1,key)==nil

  end

  test "Handle last unsubscription" do
    with_mock WebSockex, [send_frame: fn(pid,params) -> 
      send(pid, params)
      :ok 
    end] do
      key="trade:1m:tBTCUSD"
      ProtocolHandler.client_connected(self())
      
      ProtocolHandler.subscribe_candles(self(),key)
      
      assert_receive {:text, "{\"event\":\"subscribe\",\"channel\":\"candles\",\"key\":\"trade:1m:tBTCUSD\"}"},1000            

      assert ProtocolHandler.is_subscribed(self(),:candles,key)==true

      msg="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"
      :ok=ProtocolHandler.receive_message(msg)

      ProtocolHandler.unsubscribe_candles(self(),key)  
      assert_receive {:text, "{\"event\":\"unsubscribe\",\"chanId\":\"118949\"}"},1000            

      assert ProtocolHandler.is_subscribed(self(),:candles,key)==false
    end    
  end

  test "Handle channel snapshot" do
      key="trade:1m:tBTCUSD"

      snapshot_data="""
      [118949,[[1506845100000,4335.1,4335.1,4335.1,4335.1,0.513457],[1506845040000,4337.5,4335,4337.5,4335,1.07204968]]]
      """
      subscribed_event="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"

      {:ok,{ch,data}}=Protocol.decode_message(snapshot_data)
      assert ch==118949
      assert length(data)==2

      ProtocolHandler.subscribe_candles(self(),key)

      ProtocolHandler.receive_message(subscribed_event)

      ProtocolHandler.receive_message(snapshot_data)

      assert_receive {:cahnnel_data_receive, {"trade:1m:tBTCUSD", %BitfinexApi.Candle{close: 4335.1, high: 4335.1, low: 4335.1, open: 4335.1, time: 1506845100000, volume: 0.513457}}}
      assert_receive {:cahnnel_data_receive, {"trade:1m:tBTCUSD", %BitfinexApi.Candle{close: 4335, high: 4337.5, low: 4335, open: 4337.5, time: 1506845040000, volume: 1.07204968}}}
  end

  defp wait_end() do
    IO.puts "Start receive"
    receive do
      :end  ->
        IO.puts "End"
        :ok
      other ->
        IO.inspect(other)
        wait_end()
    end  
  end

  test "Test subscriber termination" do
    key="trade:1m:tBTCUSD"

    {:ok, s_pid}=Task.start(fn -> wait_end() end)
    ref = Process.monitor(s_pid)

    ProtocolHandler.subscribe_candles(s_pid, key)

    assert ProtocolHandler.is_subscribed(s_pid, :candles, key)==true

    send(s_pid, :end)
    assert_receive {:DOWN, _, :process, _, _}, 1000

    assert ProtocolHandler.is_subscribed(s_pid, :candles, key)==false
  end
end

