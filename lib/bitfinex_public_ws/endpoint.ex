defmodule BitfinexApi.Public.Ws.Endpoint do
  use ExActor.GenServer
  require Logger
  require OK

  alias BitfinexApi.Public.Ws.Protocol
  alias BitfinexApi.Public.Ws.Client, as: WsClient
  alias BitfinexApi.Public.Ws.SubscriberApi

  defmodule State do
    @moduledoc false
    defstruct [:ws_client, :channels, :version, :id_map, :ref_map, :listeners]
  end

  @spec start_link(list(pid)) :: {:ok, pid} | {:error, term}
  defstart start_link(listeners \\ []), do: initial_state(%State{ws_client: nil,
                    channels: %{},
                    id_map: %{},
                    ref_map: %{},
                    listeners: listeners})

  defcast connect, state: state do
    if state.ws_client == nil do
      {:ok, pid} = WsClient.start_link(self(), [async: true,
                                            handle_initial_conn_failure: true,
                                            debug: [:trace]])
      new_state(%State{state | ws_client: pid})
    end
  end

  defcall get_version, state: state, do: reply(state.version)

  @spec subscribe_candles(pid, pid, String.t) :: :ok
  defcast subscribe_candles(pid, key), state: state do
    new_state(subscribe(pid, key, :candles, state))
  end

  @spec unsubscribe_candles(pid, pid, String.t) :: :ok
  defcast unsubscribe_candles(pid, key), state: state do
    new_state(unsubscribe(pid, key, :candles, state))
  end

  defcall is_subscribed(pid, channel, key), state: state do
    rc = state.channels |> Map.get({channel, key}, []) |> Enum.member?(pid)
    reply(rc)
  end

  defcall get_channel_id(channel, key), state: state do
    reply state.id_map |> Enum.find_value(
            fn ({id, v}) ->
              {ch, k} = v
              if ch == channel && k == key do
                id
              else
                nil
              end
            end
          )
  end

  defp subscribe(pid, key, ch_name, state) do
    ref = Process.monitor(pid)
    new_ref_map = Map.put(state.ref_map, pid, ref)
    new_pid_list = [pid | Map.get(state.channels, {ch_name, key}, [])]
    new_ch_map = Map.put(state.channels, {ch_name, key}, new_pid_list)

    if state.ws_client != nil and length(new_pid_list) == 1 do
      subscribe_to_channel(state.ws_client, ch_name, key)
    end

    %State{state | channels: new_ch_map, ref_map: new_ref_map}
  end

  defp unsubscribe(pid, key, ch_name, state) do
    new_ref_map = case Map.pop(state.ref_map, pid) do
      {nil, map} ->
        map
      {ref, map} ->
        Process.demonitor(ref)
        map
    end

    pid_list = Map.get(state.channels, {ch_name, key}, [])
    new_pid_list = List.delete(pid_list, pid)
    new_ch_map = Map.put(state.channels, {ch_name, key}, new_pid_list)

    if length(pid_list) > 0 and length(new_pid_list) == 0 and state.ws_client != nil do
      ch_id = state.id_map
              |> Map.to_list
              |> Enum.find_value(fn {ch_id, {ch, ch_key}} -> if ch == ch_name and ch_key == key, do: ch_id end)
      if ch_id != nil do
        Logger.debug (fn -> "Last pid unsubscribed: #{inspect ch_id}" end)
        unsubscribe_to_channel(ch_id, state.ws_client)
      else
        Logger.debug (fn -> "Last pid unsubscribed: ch_id is nill" end)
      end
    end
    %State{state | channels: new_ch_map, ref_map: new_ref_map}
  end

  defcast client_connected, state: state do
    Logger.debug(fn -> "Client connected: #{inspect state}" end)
    state.channels
      |> Map.keys
      |> Enum.each(
          fn {ch, key} ->
            subscribe_to_channel(state.ws_client, ch, key)
          end
        )
    # new_state(%State{state | ws_client: pid})
    state.listeners |> Enum.each(fn pid ->
      Kernel.send(pid, {:endpoin_connect})
    end)
    new_state(state)
  end

  defcast client_disconnected, state: state do
    # new_state(%State{state | ws_client: nil})
    state.listeners |> Enum.each(fn pid ->
      Kernel.send(pid, {:endpoin_disconnect})
    end)    
    new_state(state)
  end

  defcast receive_message(str), state: state do
    {:ok, v} = Protocol.decode_message(str)
    nstate = handle_event(v, state)
    Logger.debug(fn -> "Set new state:#{inspect nstate}" end)
    new_state(nstate)
  end

  defhandleinfo {:DOWN, _ref, :process, pid, _reason},state: state do
    nstate = state.channels
      |> Map.to_list()
      |> Enum.filter(fn {_k, v} -> Enum.member?(v, pid) end)
      |> Enum.reduce(state, fn ({{ch_name, key}, _v}, st) ->
        unsubscribe(pid, key, ch_name, st)
      end)
    new_state(nstate)
  end

  defp subscribe_to_channel(pid, channel_name, key) do
    Logger.info("Sending subscribe request: channel=#{channel_name} key=#{key}")
    WsClient.send_frame(pid, Protocol.encode_subscribe_request(channel_name, key))
  end

  defp unsubscribe_to_channel(channel_id, pid) do
    Logger.info("Sending unsubscribe request: channelId=#{channel_id}")
    WsClient.send_frame(pid, Protocol.encode_unsubscribe_request(channel_id))
  end

  defp handle_event(%Protocol.Event{event: "info", version: ver}, state) when is_nil(ver) == false do
    Logger.debug(fn -> "Handle event Version Info: Version=#{ver}" end)
    %State{state | version: ver}
  end

  defp handle_event(%Protocol.Event{event: "info", code: code, msg: msg}, state) when code > 0 do
    Logger.debug(fn -> "Handle relevant event: code=#{code} Msg=#{msg}" end)
    state
  end

  defp handle_event(%Protocol.Event{event: "subscribed", chanId: id, channel: ch, key: key}, state) do
    Logger.debug(fn -> "Handle event Subscribed: id=#{id} channel=#{ch} key=#{key}" end)
    ch_atom = String.to_existing_atom(ch)
    new_id_map = Map.put(state.id_map, id, {ch_atom, key})
    %State{state | id_map: new_id_map}
  end

  defp handle_event({ch, "hb"}, state) do
    Logger.debug(fn -> "Handle hb event: channel=#{ch}" end)
    state
  end

  defp handle_event({ch_id, data}, state) do
    Logger.debug(fn -> "Handle data event: channel=#{ch_id} data=#{inspect data}" end)

    {:ok, _} = OK.for do
      ch <- get_channel_by_id(ch_id, state)
      pids <- get_pids_by_ch(ch, state)
    after
      send_to_subscribers(pids, data)
      # case pids do
      #   {{ch, key}, []} ->
      #     state = unsubscribe_empty_pids(ch, key, state)
      #   result ->
      #     send_to_subscribers(result, data)
      # end
    end
    state
  end

  defp handle_event(protocl_event, state) do
    Logger.warn("Unknown event :#{inspect protocl_event}")
    state
  end

  defp get_channel_by_id(ch_id, state), do: Map.fetch(state.id_map, ch_id)

  defp get_pids_by_ch(ch, state) do
    case Map.fetch(state.channels, ch) do
      {:ok, v} ->
        {:ok, {ch, v}}
      err ->
         err
    end
  end

  # defp unsubscribe_empty_pids(ch, key, state) do
  #   Logger.warn("Pid list is empty for :#{ch} #{key}")
  #   state = %State{state | channels: Map.delete(state.channels, {ch, key})}
  #   ch_id = state.id_map
  #     |> Map.to_list
  #     |> Enum.find_value(fn {ch_id, {ch, ch_key}} -> if ch == ch_name and ch_key == key, do: ch_id end)
  #   if ch_id != nil do
  #     Logger.debug (fn -> "Unsubscribe from #{ch} #{key} ch_id=#{ch_id}" end)
  #     state = %State{state | id_map: Map.delete(state.id_map, ch_id)}
  #     unsubscribe_to_channel(ch_id, state.ws_client)
  #   end
  #   state
  # end

  defp send_to_subscribers({{ch, key}, pid_list}, data) when is_list(hd(data)) do
    data
    |> Enum.each(
         fn x ->
           send_to_subscribers({{ch, key}, pid_list}, x)
         end
       )
  end

  defp send_to_subscribers({{ch, key}, pid_list}, data) do
    case Protocol.decode_channel_data(ch, data) do
      {:ok, decoded_data} ->
        pid_list
        |> Enum.each(fn pid ->
          SubscriberApi.send_to_subscriber(pid, {key, decoded_data})
        end)
      err ->
        err
    end
  end

end
