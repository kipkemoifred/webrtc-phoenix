# defmodule SessionManager do
#   use GenServer
#   require Logger

#   @topic "webrtc_session"

#   @enforce_keys [:state]
#   defstruct clients: %{}, state: :impossible

#   # Starting the GenServer
#   def start_link(_opts) do
#     GenServer.start_link(__MODULE__, %SessionManager{state: :impossible}, name: __MODULE__)
#   end

#   def add_client(user_id, socket) do
#     Logger.info("add_client called")
#     GenServer.call(__MODULE__, {:add_client, user_id, socket})
#   end

#   def remove_client(user_id) do
#     GenServer.cast(__MODULE__, {:remove_client, user_id})
#   end

#   def get_clients do
#     GenServer.call(__MODULE__, :get_clients)
#   end

#   # Server Callbacks

#   def init(state) do
#     {:ok, state}
#   end

#   def handle_call({:add_client, user_id, socket}, _from, state) do
#     new_state = Map.put(state, user_id, socket)
#     {:reply, :ok, new_state}
#   end

#   def handle_call(:get_clients, _from, state) do
#     {:reply, state, state}
#   end

#   def handle_cast({:remove_client, user_id}, state) do
#     new_state = Map.delete(state, user_id)
#     {:noreply, new_state}
#   end

#   def reset_clients do
#     GenServer.cast(__MODULE__, :reset_clients)
#   end

#   def handle_cast(:reset_clients, _state) do
#     {:noreply, %{}}
#   end



#   def init(state) do
#     {:ok, state}
#   end



#   # Public API
#   @spec on_session_started(any(), any()) :: any()
#   def on_session_started(session_id, pid) do
#     Logger.info("on_session_started called for #{inspect(session_id)}")
#     GenServer.call(__MODULE__, {:start_session, session_id, pid})
#   end

#   def on_message(session_id, message) do
#     GenServer.cast(__MODULE__, {:message, session_id, message})
#   end

#   def on_session_close(session_id) do
#     GenServer.call(__MODULE__, {:close_session, session_id})
#   end

#   def handle_call({:start_session, session_id, pid}, _from, %SessionManager{clients: clients} = state) do
#     Logger.info("handle_call for session: #{inspect(session_id)}")
#     Logger.info("handle_call for pid: #{inspect(pid)}")

#     if map_size(clients) >= 2 do
#         send(pid, :close)
#         {:reply, :too_many_clients, state}
#     else
#         Logger.info("Adding client #{inspect(session_id)}")
#         new_clients = Map.put(clients, session_id, pid)

#         new_state = if map_size(new_clients) >= 2, do: :ready, else: :impossible

#         # Notify about state update
#         notify_about_state_update(%{state | clients: new_clients, state: new_state})

#         {:reply, {:ok, session_id}, %{state | clients: new_clients}}
#     end
# end


#   def handle_call({:close_session, session_id}, _from, %SessionManager{clients: clients} = state) do
#     Logger.info("Closing session: #{inspect(session_id)}")
#     new_clients = Map.delete(clients, session_id)
#     new_state = if map_size(new_clients) < 2, do: :impossible, else: state.state
#     notify_about_state_update(%{state | clients: new_clients, state: new_state})
#     {:reply, :ok, %{state | clients: new_clients}}
#   end

#   def handle_cast({:message, session_id, message}, %SessionManager{clients: clients, state: state} = current_state) do
#     Logger.info("Received message from #{inspect(session_id)}: #{inspect(message)}")

#     cond do
#       String.starts_with?(message, "STATE") -> handle_state(session_id, clients[session_id], state)
#       String.starts_with?(message, "OFFER") -> handle_offer(session_id, message, current_state)
#       String.starts_with?(message, "ANSWER") -> handle_answer(session_id, message, current_state)
#       String.starts_with?(message, "ICE") -> handle_ice(session_id, message, current_state)
#     end

#     {:noreply, current_state}
#   end

#   # Internal Logic
#   defp handle_state(session_id, client_pid, state) do
#     Logger.info("Handling state request for #{inspect(session_id)}")
#     if Process.alive?(client_pid) do
#       send(client_pid, {:state, state})
#     else
#       Logger.error("Client #{inspect(session_id)} is not alive.")
#     end
#   end

#   defp handle_offer(session_id, message, %SessionManager{clients: clients, state: :ready} = state) do
#     Logger.info("Handling offer from #{inspect(session_id)}")
#     target_client = find_target_client(session_id, clients)
#     if target_client do
#       send(target_client, {:offer, message})
#     else
#       Logger.warn("No target client available to send the offer.")
#     end
#   end

#   defp handle_answer(session_id, message, %SessionManager{clients: clients, state: :creating} = state) do
#     Logger.info("Handling answer from #{inspect(session_id)}")
#     target_client = find_target_client(session_id, clients)
#     if target_client do
#       send(target_client, {:answer, message})
#     else
#       Logger.warn("No target client available to send the answer.")
#     end
#   end

#   defp handle_ice(session_id, message, %SessionManager{clients: clients} = state) do
#     Logger.info("Handling ICE candidate from #{inspect(session_id)}")
#     target_client = find_target_client(session_id, clients)
#     if target_client do
#       send(target_client, {:ice, message})
#     else
#       Logger.warn("No target client available to send the ICE candidate.")
#     end
#   end

#   # Assuming this is part of the client process
# def handle_info({:state, state}, state_data) do
#   Logger.info("Client received state: #{inspect(state)}")
#   # Handle the state as needed
#   {:noreply, state_data}
# end

#   defp find_target_client(session_id, clients) do
#     clients
#     |> Enum.filter(fn {id, _} -> id != session_id end)
#     |> Enum.map(&elem(&1, 1))
#     |> List.first()
#   end

#   defp notify_about_state_update(%SessionManager{clients: clients, state: state}) do
#     Logger.info("Clients: #{inspect(clients)}")
#     Logger.info("State: #{inspect(state)}")

#     Enum.each(clients, fn {key, pid} ->
#         if Process.alive?(pid) do
#             Logger.info("Before Sent state #{inspect(state)} to client #{inspect(key)} pid #{inspect(pid)}")
#           send(pid, {:state, state})

#             Logger.info("AfterSent state #{inspect(state)} to client #{inspect(key)} pid #{inspect(pid)}")
#         else
#             Logger.error("Client #{inspect(key)} has a dead process with PID: #{inspect(pid)}")
#         end
#     end)
# end


# end


defmodule SessionManager do
  use GenServer
  require Logger

  @session_states [:impossible, :ready, :creating, :active]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{clients: %{}, session_state: :impossible}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def on_session_started(session_id, pid) do
    GenServer.cast(__MODULE__, {:session_started, session_id, pid})
  end

  def on_message(session_id, message) do
    GenServer.cast(__MODULE__, {:handle_message, session_id, message})
  end

  def on_session_close(session_id) do
    GenServer.cast(__MODULE__, {:session_close, session_id})
  end

  # GenServer Callbacks
  def handle_cast({:session_started, session_id, pid}, state) do
    clients = Map.put(state.clients, session_id, pid)
    session_state =
      if map_size(clients) > 2 do
        send(pid, {:close, :too_many_clients})
        state.session_state
      else
        # new_state = if map_size(new_clients) >= 2, do: :ready, else: :impossible
        if map_size(clients) == 2 do :ready else :impossible end
        # :ready
      end

    notify_state_update(session_state, clients)
    {:noreply, %{state | clients: clients, session_state: session_state}}
  end

  def handle_cast({:handle_message, session_id, message}, state) do
    case parse_message_type(message) do
      :offer -> handle_offer(session_id, message, state)
      :answer -> handle_answer(session_id, message, state)
      :ice -> handle_ice(session_id, message, state)
      _ -> {:noreply, state}
    end
  end

  def handle_cast({:session_close, session_id}, state) do
    clients = Map.delete(state.clients, session_id)
    session_state = if map_size(clients) == 0, do: :impossible, else: state.session_state
    notify_state_update(session_state, clients)
    {:noreply, %{state | clients: clients, session_state: session_state}}
  end

  defp notify_state_update(session_state, clients) do
    Enum.each(clients, fn {_id, client_pid} ->
      Logger.info("before send #{inspect(session_state)}  #{inspect(clients)}")
      send(client_pid, {:state_update, session_state})
      Logger.info("after send")
    end)
  end

  # def handle_offer(session_id, message, %{clients: clients,session_state: :ready} = state) do
  #   IO.puts "session_id "<>session_id<>" message "<>message
  #   clients = Map.delete(state.clients, session_id)
  #   IO.puts "clients #{inspect(clients)}"

  #   [client_pid] = Map.values(clients)
  #   IO.puts "client_pid ===== #{inspect(client_pid)}"
  #   send(client_pid, {:offer, message})
  #   {:noreply, %{state | session_state: :creating}}
  # end

  def handle_offer(session_id, message, %{clients: clients, session_state: :ready} = state) do
    IO.puts "session_id "<>session_id<>" message "<>message
    clients = Map.delete(state.clients, session_id)
    IO.puts "clients #{inspect(clients)}"

    [client_pid] = Map.values(clients)
    IO.puts "client_pid ===== #{inspect(client_pid)}"
    send(client_pid, {:offer, message})
    {:noreply, %{state | session_state: :creating}}
  end

  # New clause to handle the :creating state
  def handle_offer(session_id, message, %{clients: clients, session_state: :creating} = state) do
    IO.puts "Session is still being created. Ignoring offer for session: #{session_id}"

    IO.puts "session_id "<>session_id<>" message "<>message
    clients = Map.delete(state.clients, session_id)
    IO.puts "clients #{inspect(clients)}"

    [client_pid] = Map.values(clients)
    IO.puts "client_pid ===== #{inspect(client_pid)}"
    send(client_pid, {:creating, message})
    {:noreply, state}  # You can choose to log or take a different action
  end


  # defp handle_offer(session_id, message, %{session_state: :ready, clients: clients} = state) do
  #   IO.puts "in handle offer===="
  #   case Map.get(clients, session_id) do
  #     nil ->
  #       IO.puts "in handle offer nil "
  #       # Handle the case where the session_id does not exist
  #       {:stop, :session_not_found, state}

  #     client_pid ->
  #       IO.puts "in handle offer==== client_pid "<>client_pid
  #       # Send the offer to the client process
  #       send(client_pid, {:offer, message})
  #       # Update the state to creating and remove the client
  #       updated_clients = Map.delete(clients, session_id)
  #       {:noreply, %{state | clients: updated_clients, session_state: :creating}}
  #   end
  # end

  defp handle_answer(session_id, message, %{session_state: :creating} = state) do
    clients = Map.delete(state.clients, session_id)
    [client_pid] = Map.values(clients)
    send(client_pid, {:answer, message})
    {:noreply, %{state | session_state: :active}}
  end

  defp handle_ice(session_id, message, state) do
    clients = Map.delete(state.clients, session_id)
    [client_pid] = Map.values(clients)
    send(client_pid, {:ice, message})
    {:noreply, state}
  end

  defp parse_message_type(message) do
    cond do
      String.starts_with?(message, "OFFER") -> :offer
      String.starts_with?(message, "ANSWER") -> :answer
      String.starts_with?(message, "ICE") -> :ice
      true -> :unknown
    end
  end
end
