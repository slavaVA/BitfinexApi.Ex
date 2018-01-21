defmodule BitfinexApi.Public.Ws.SubscriberApi do

    def send_to_subscriber(pid,ch, ch_data) do
        send(pid, {:cahnnel_data, ch, ch_data})
    end

end
