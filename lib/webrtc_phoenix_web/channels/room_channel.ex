defmodule WebrtcPhoenixWeb.RoomChannel do
  use Phoenix.Channel
  require Logger

  @spec join(<<_::72>>, any(), Phoenix.Socket.t()) ::
          {:ok, %{session_id: any()}, Phoenix.Socket.t()}
  @spec join(<<_::80>>, any(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()}
  def join("room:lobby", _payload, socket) do
    # Generate a unique session ID
    session_id = UUID.uuid4()
    # Notify SessionManager
    SessionManager.on_session_started(session_id, self())
    {:ok, %{session_id: session_id}, assign(socket, :session_id, session_id)}
  end

  def handle_in("offer", %{"message" => message}, socket) do
    IO.puts("offer")
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, "OFFER " <> message)
    {:noreply, socket}
  end

  def handle_in("answer", %{"message" => message}, socket) do
    IO.puts("answer")
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, "ANSWER " <> message)
    {:noreply, socket}
  end

  def handle_in("ice", %{"message" => message}, socket) do
    IO.puts("ice")
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, "ICE " <> message)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    session_id = socket.assigns[:session_id]
    SessionManager.on_session_close(session_id)
    :ok
  end

  def handle_info({:state_update, :ready}, socket) do
    IO.puts("ready received")
    push(socket, "state_update", %{state: "ready"})
    {:noreply, socket}
  end

  def handle_info({:ice, ice_message}, socket) do
    IO.puts("Received ICE message")
    IO.inspect(ice_message, label: "ICE Candidate")

    push(socket, "state_update", %{state: ice_message})
    {:noreply, socket}
  end

  def handle_info({:offer, message}, socket) do
    IO.puts("Received offer message")
    IO.inspect(message, label: "offer Candidate")

    push(socket, "state_update", %{state: "offer"})
    {:noreply, socket}
  end

  def handle_info({:state_update, :impossible}, socket) do
    push(socket, "state_update", %{state: "impossible"})
    {:noreply, socket}
  end

  def handle_info({:state_update, :offer}, socket) do
    IO.puts("handle info offer =========??====")
    push(socket, "state_update", %{state: "offer"})
    {:noreply, socket}
  end

  def handle_info({:state_update, :active}, socket) do
    IO.puts("handle info offer ==============")
    push(socket, "state_update", %{state: "activee"})
    {:noreply, socket}
  end

  def handle_info({:state_update, :answer}, socket) do
    IO.puts("handle info offer ==============")
    push(socket, "state_update", %{state: "answer"})
    {:noreply, socket}
  end

  def handle_info({:state_update, message}, socket) do
    IO.puts("sending message ===========<><>")
    push(socket, "state_update", %{state: message})
    {:noreply, socket}
  end

  def handle_info({:state_update, :creating}, socket) do
    IO.puts("handle info creating ==============")
    push(socket, "state_update", %{state: "creating"})
    push(socket, "state_update", %{state: "answer"})
    # push(socket, "state_update", %{state: "offer"})
    IO.puts("after pushing creating")
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    IO.inspect(msg, label: "Unexpected message")
    {:noreply, socket}
  end

  # Handle incoming WebSocket messages
  def handle_in(message, socket) do
    case Jason.decode(message) do
      {:ok, json} ->
        # Handle valid JSON messages
        handle_json_message(json, socket)

      {:error, _} ->
        # Handle non-JSON messages (likely plain text like SDP offers)
        handle_plain_text_message(message, socket)
    end
  end

  defp handle_json_message(%{"type" => "offer", "sdp" => sdp}, socket) do
    # Handle SDP offer here
    push(socket, "sdp_offer", %{sdp: sdp})
    {:noreply, socket}
  end

  defp handle_plain_text_message(sdp, socket) do
    # Handle plain SDP offer here
    push(socket, "sdp_offer", %{sdp: sdp})
    {:noreply, socket}
  end
end
