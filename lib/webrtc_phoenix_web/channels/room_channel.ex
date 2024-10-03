defmodule WebrtcPhoenixWeb.RoomChannel do
  use Phoenix.Channel
  require Logger

  @spec join(<<_::72>>, any(), Phoenix.Socket.t()) ::
          {:ok, %{session_id: any()}, Phoenix.Socket.t()}
  @spec join(<<_::80>>, any(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()}
  def join("room:lobby", _payload, socket) do
    Logger.info("Client joined RTC channel")



    session_id = UUID.uuid4()  # Generate a unique session ID

    # Task.start(fn -> SessionManager.on_session_started(session_id, self()) end)
    SessionManager.on_session_started(session_id, self())  # Notify SessionManager

    # send(self(), :after_join)  # Send message to self to handle incoming messages
    {:ok, %{session_id: session_id}, assign(socket, :session_id, session_id)}

    # {:ok, assign(socket, :session_id, session_id)}  # Assign session ID to the socket

  end

  # @spec handle_in(<<_::56>>, map(), Phoenix.Socket.t()) :: {:noreply, Phoenix.Socket.t()}
  # def handle_in("new_msg", %{"body" => body}, socket) do
  #   broadcast! socket, "new_msg", %{body: body}
  #   {:noreply, socket}
  # end

  # def handle_in("start_session", _params, socket) do
  #   Logger.info("Starting session for client #{socket.assigns.user_id}")
  #   session_id = UUID.uuid4()
  #   SessionManager.on_session_started(session_id, socket)
  #   {:noreply, socket}
  # end


  # @spec handle_info(:after_join | {:state, any()}, atom() | map()) ::
  #         {:noreply, Phoenix.Socket.t()}
  #         | {:stop, any(), atom() | %{:assigns => atom() | map(), optional(any()) => any()}}
  # def handle_info(:after_join, socket) do
  #   # Loop to handle incoming messages
  #   receive do
  #     {:socket_frame, frame} ->
  #       # Handle incoming frame (e.g., a message)
  #       SessionManager.on_message(socket.assigns.session_id, frame)
  #       # Continue to listen for more messages
  #       handle_info(:after_join, socket)

  #     {:exit, reason} ->
  #       # Handle closure or exit reason
  #       IO.puts("Exiting incoming loop, closing session: #{socket.assigns.session_id}")
  #       SessionManager.on_session_close(socket.assigns.session_id)
  #       {:stop, reason, socket}

  #     # Catch-all for unhandled messages
  #     _ ->
  #       handle_info(:after_join, socket)
  #   after
  #     # Handle timeout or other cleanup logic if needed
  #     60000 ->  # Adjust timeout as necessary
  #       IO.puts("No messages received, closing session: #{socket.assigns.session_id}")
  #       SessionManager.on_session_close(socket.assigns.session_id)
  #       {:stop, :timeout, socket}
  #   end
  # end

  #   # This is where we handle info messages
  #   def handle_info({:state, :impossible}, socket) do
  #     # Here you can decide what to do when the state is :impossible
  #     # For instance, you might want to push a message to the client:
  #     push(socket, "state_update", %{status: "impossible", message: "The session cannot be started."})

  #     # Return the unchanged socket
  #     {:noreply, socket}
  #   end

  #   # You may want to handle other states as well
  #   def handle_info({:state, state}, socket) do
  #     # Handle other states as needed
  #     push(socket, "state_update", %{status: state})
  #     {:noreply, socket}
  #   end

  # def terminate(_reason, socket) do
  #   # Clean up when the channel is terminated
  #   SessionManager.on_session_close(socket.assigns.session_id)
  #   :ok
  # end

  @spec handle_in(
          <<_::24, _::_*8>>,
          map(),
          atom() | %{:assigns => nil | maybe_improper_list() | map(), optional(any()) => any()}
        ) ::
          {:noreply,
           atom() | %{:assigns => nil | maybe_improper_list() | map(), optional(any()) => any()}}
  def handle_in("new_message", %{"message" => message}, socket) do
    IO.puts "new message==="
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, "OFFER " <> message)
    {:noreply, socket}
  end

  # def handle_in("offer", message, socket) when is_binary(message) do
  #   session_id = socket.assigns[:session_id]

  #   # Assuming the SDP offer is coming in as plain text
  #   # Prepend "OFFER " to the message and pass it to the SessionManager
  #   SessionManager.on_message(session_id, "OFFER " <> message)

  #   {:noreply, socket}
  # end


  def handle_in("answer", %{"message" => message}, socket) do
    IO.puts "answer"
    session_id = socket.assigns[:session_id]
    SessionManager.on_message(session_id, "ANSWER " <> message)
    {:noreply, socket}
  end

  def handle_in("ice", %{"message" => message}, socket) do
    IO.puts "ice"
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

    push(socket, "state_update", %{state: "ready"})
    {:noreply, socket}
  end



  def handle_info({:state_update, :impossible}, socket) do

    push(socket, "state_update", %{state: "impossible"})
    {:noreply, socket}
  end

  def handle_info({:state_update, :creating}, socket) do

    push(socket, "state_update", %{state: "creating"})
    {:noreply, socket}
  end

  def handle_info({:creating, offer}, socket) do
    IO.inspect(offer, label: "Received WebRTC Offer")

    # You can push the offer to the client or process it further
    push(socket, "state_update", %{state: "creating", offer: offer})

    {:noreply, socket}
  end


    #   # You may want to handle other states as well
    # def handle_info({:state, state}, socket) do
    #   # Handle other states as needed
    #   push(socket, "state_update", %{status: state})
    #   {:noreply, socket}
    # end

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
