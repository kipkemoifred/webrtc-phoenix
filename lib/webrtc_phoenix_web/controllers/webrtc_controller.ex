defmodule WebrtcPhoenixWeb.WebRtcGetController do
  use WebrtcPhoenixWeb, :controller

  def index(conn, _params) do
    text(conn, "Hello from WebRTC signaling server")
  end
end
