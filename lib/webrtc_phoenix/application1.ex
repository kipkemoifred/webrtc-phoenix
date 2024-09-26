defmodule WebRTCPhoenixAppWeb.Router do
  use WebrtcPhoenixWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WebRTCPhoenixAppWeb do
    pipe_through :api

    get "/", WebrtcPhoenix, :index
    # websocket "/rtc", WebRTCPhoenixAppWeb.WebRTCChannel
  end
end


defmodule WebRTCPhoenixAppWeb.Controller do
  use WebrtcPhoenixWeb, :controller

  def index(conn, _params) do
    text(conn, "Hello from WebRTC signaling server")
  end
end

defmodule WebRTCPhoenixAppWeb.WebRTCChannel do
  use Phoenix.Channel

  alias WebRTCPhoenixApp.SessionManager

  def join("rtc", _message, socket) do
    session_id = UUID.uuid4()
    SessionManager.on_session_started(session_id, self())
    {:ok, %{session_id: session_id}, assign(socket, :session_id, session_id)}
  end

  def handle_in("message", %{"content" => content}, socket) do
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, content)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    session_id = socket.assigns[:session_id]
    SessionManager.on_session_close(session_id)
    :ok
  end
end

defmodule WebRTCPhoenixAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :webrtc_phoenix_app

  socket "/rtc", WebRTCPhoenixAppWeb.WebRTCChannel,
    websocket: true

  plug Plug.Static,
    at: "/",
    from: :webrtc_phoenix_app,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_webrtc_phoenix_app_key", signing_salt: "secret"

  plug WebRTCPhoenixAppWeb.Router
end
