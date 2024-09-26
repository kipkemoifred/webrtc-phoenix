defmodule WebrtcPhoenixWeb.RoomChannel do
  use Phoenix.Channel

  @spec join(<<_::72>>, any(), Phoenix.Socket.t()) ::
          {:ok, %{session_id: any()}, Phoenix.Socket.t()}
  def join("room:lobby", _payload, socket) do
    # {:ok, socket}
    session_id = UUID.uuid4()  # Generate a unique session ID
    SessionManager.on_session_started(session_id, self())  # Notify SessionManager

    send(self(), :after_join)  # Send message to self to handle incoming messages

    {:ok, assign(socket, :session_id, session_id)}  # Assign session ID to the socket

  end

  @spec handle_in(<<_::56>>, map(), Phoenix.Socket.t()) :: {:noreply, Phoenix.Socket.t()}
  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast! socket, "new_msg", %{body: body}
    {:noreply, socket}
  end


  def handle_info(:after_join, socket) do
    # Loop to handle incoming messages
    receive do
      {:socket_frame, frame} ->
        # Handle incoming frame (e.g., a message)
        SessionManager.on_message(socket.assigns.session_id, frame)
        # Continue to listen for more messages
        handle_info(:after_join, socket)

      {:exit, reason} ->
        # Handle closure or exit reason
        IO.puts("Exiting incoming loop, closing session: #{socket.assigns.session_id}")
        SessionManager.on_session_close(socket.assigns.session_id)
        {:stop, reason, socket}

      # Catch-all for unhandled messages
      _ ->
        handle_info(:after_join, socket)
    after
      # Handle timeout or other cleanup logic if needed
      15000 ->  # Adjust timeout as necessary
        IO.puts("No messages received, closing session: #{socket.assigns.session_id}")
        SessionManager.on_session_close(socket.assigns.session_id)
        {:stop, :timeout, socket}
    end
  end

    # This is where we handle info messages
    def handle_info({:state, :impossible}, socket) do
      # Here you can decide what to do when the state is :impossible
      # For instance, you might want to push a message to the client:
      push(socket, "state_update", %{status: "impossible", message: "The session cannot be started."})

      # Return the unchanged socket
      {:noreply, socket}
    end

    # You may want to handle other states as well
    def handle_info({:state, state}, socket) do
      # Handle other states as needed
      push(socket, "state_update", %{status: state})
      {:noreply, socket}
    end

  def terminate(_reason, socket) do
    # Clean up when the channel is terminated
    SessionManager.on_session_close(socket.assigns.session_id)
    :ok
  end
end
