defmodule BitfinexApi.Public.Ws.ProtocolTest do
    use ExUnit.Case,  async: false
    alias BitfinexApi.Public.Ws.Protocol

    test "Decode version info" do
        msg_info_version="{\"event\":\"info\",\"version\":2}"
    
        {:ok,event}=Protocol.decode_message(msg_info_version)
        assert event.version == 2
    end
        
    test "Handle subscribed event" do        
        msg="{\"event\":\"subscribed\",\"channel\":\"candles\",\"chanId\":118949,\"key\":\"trade:1m:tBTCUSD\"}"
        {:ok,_event}=Protocol.decode_message(msg)
    end
            
    test "Decode channel snapshot" do
        snapshot_data="""
        [118949,[[1506845100000,4335.1,4335.1,4335.1,4335.1,0.513457],[1506845040000,4337.5,4335,4337.5,4335,1.07204968]]]
        """
        {:ok,{ch,data}}=Protocol.decode_message(snapshot_data)
        assert ch==118949
        assert length(data)==2
    end        

    test "Encode requests" do
        req=Protocol.encode_subscribe_request("candles","trade:1m:tBTCUSD")
        {:ok,_}=Poison.decode(req)
    end        
end  