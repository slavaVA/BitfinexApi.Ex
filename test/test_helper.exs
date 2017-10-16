# for app <- Application.spec(:my_app,:applications) do
#     Application.ensure_all_started(app)
# end
Application.ensure_all_started(:logger)
ExUnit.start()
