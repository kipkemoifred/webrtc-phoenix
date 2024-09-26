defmodule WebrtcPhoenixWeb.WebRTCChannel do
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
