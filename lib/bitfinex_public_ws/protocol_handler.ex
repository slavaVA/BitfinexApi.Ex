defmodule BitfinexApi.Public.Ws.ProtocolHandler do
  use Rop
  use ExActor.GenServer, export: :ws_public_protocol_handler
  require Logger

  alias BitfinexApi.Public.Ws.Protocol
  alias BitfinexApi.Public.Ws.Client, as: WsClient
  alias BitfinexApi.Public.Ws.SubscriberApi

  defmodule State do
    defstruct [:ws_client, :channels, :version, :id_map, :ref_map]
  end

  defstart start_link, do: initial_state(%State{channels: %{}, id_map: %{}, ref_map: %{}})

  defcall get_version, state: state, do: reply(state.version)

  #BitfinexApi.Public.Ws.ProtocolHandler.subscribe_candles(self(),"trade:1m:tBTCUSD")

  defcast subscribe_candles(pid, key), state: state do
    new_state(subscribe_channel(pid, key, :candles, state))
  end

  defp subscribe_channel(pid, key, ch_name, state) do
    ref = Process.monitor(pid)
    new_ref_map = Map.put(state.ref_map, pid, ref)
    new_pid_list = [pid | Map.get(state.channels, {ch_name, key}, [])]
    new_ch_map = Map.put(state.channels, {ch_name, key}, new_pid_list)

    if state.ws_client != nil and length(new_pid_list) == 1 do
      :ok = WsClient.subscribe_to_channel(state.ws_client, ch_name, key)
    end

    %State{state | channels: new_ch_map, ref_map: new_ref_map}
  end

  defcast unsubscribe_candles(pid, key), state: state do
    new_state(unsubscribe_from_channel(pid, key, :candles, state))
  end

  defp unsubscribe_from_channel(pid, key, ch_name, state) do
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
      ch_id = Map.to_list(state.id_map)
              |> Enum.find_value(fn {ch_id, {ch, ch_key}} -> if ch == ch_name and ch_key == key, do: ch_id end)

      Logger.debug ("Last pid unsubscribed: #{inspect ch_id}")
      :ok = WsClient.unsubscribe_to_channel(state.ws_client, ch_id)
    end
    %State{state | channels: new_ch_map, ref_map: new_ref_map}
  end

  defcall is_subscribed(pid, channel, key), state: state do
    rc = Map.get(state.channels, {channel, key}, [])
         |> Enum.member?(pid)
    reply(rc)
  end

  defcall get_channel_id(channel, key), state: state do
    reply Enum.find_value(
            state.id_map,
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

  defcast client_connected(pid), state: state do
    Logger.debug("Client connected:#{inspect state}")
    # chList=state.channels
    state.channels
    |> Enum.map(fn ({k, _v}) -> k end)
    |> Enum.each(
         fn x ->
           {ch, key} = x
           :ok = WsClient.subscribe_to_channel(pid, ch, key)
         end
       )

    new_state(%State{state | ws_client: pid})
  end

  defcast client_disconnected(), state: state do
    new_state(%State{state | ws_client: nil})
  end

  defcast receive_message(str), state: state do
    {:ok, v} = Protocol.decode_message(str)
    nstate = handle_event(v, state)
    Logger.debug("Set new state:#{inspect nstate}")
    new_state(nstate)
  end

  defhandleinfo {:DOWN, _ref, :process, pid, _reason},state: state do
    nstate=Map.to_list(state.channels)
    |>Enum.filter(fn {_k, v} -> 
      Enum.member?(v,pid)
    end)
    |>Enum.reduce(state, fn ({{ch_name, key}, _v}, st) ->
      unsubscribe_from_channel(pid, key, ch_name, st)
    end)
    new_state(nstate)
  end

  defp handle_event(%Protocol.Event{event: "info", version: ver}, state) when is_nil(ver) == false do
    Logger.debug("Handle event Version Info: Version=#{ver}")
    %State{state | version: ver}
  end

  defp handle_event(%Protocol.Event{event: "info", code: code, msg: msg}, state) when code > 0 do
    Logger.debug("Handle relevant event: code=#{code} Msg=#{msg}")
    state
  end

  defp handle_event(%Protocol.Event{event: "subscribed", chanId: id, channel: ch, key: key}, state) do
    Logger.debug("Handle event Subscribed: id=#{id} channel=#{ch} key=#{key}")
    ch_atom = String.to_existing_atom(ch)
    new_id_map = Map.put(state.id_map, id, {ch_atom, key})
    %State{state | id_map: new_id_map}
  end

  defp handle_event({ch, "hb"}, state) do
    Logger.debug("Handle hb event: channel=#{ch}")
    state
  end

  defp handle_event({ch_id, data}, state) do
    Logger.debug("Handle data event: channel=#{ch_id} data=#{inspect data}")

    get_channel_by_id(ch_id, state)
        >>> get_pids_by_ch(state)
        >>> send_to_subscribers(data)

    state
  end

  defp handle_event(protocl_event, _state) do
    Logger.warn("Unknown event :#{inspect protocl_event}")
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
        |> Enum.each(fn pid -> SubscriberApi.send_to_subscriber(pid, {key, decoded_data}) end)
      err ->
        err
    end
  end

end
