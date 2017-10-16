defmodule BitfinexApi.Public.Ws.SubscriberApi do

    def send_to_subscriber(pid, ch_data) do
        send(pid, {:cahnnel_data_receive, ch_data})
    end

end
