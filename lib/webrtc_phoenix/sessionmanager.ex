
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
    IO.puts " adding clients #{inspect(clients)}"
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
    IO.puts "message; "<>message
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

  def handle_offer(session_id, message, %{clients: clients, session_state: :ready} = state) do
    IO.puts "session_id "<>session_id<>" clients #{inspect(clients)}"
    updated_clients = Map.delete(clients, session_id)
    IO.puts "updated clients #{inspect(updated_clients)} "

    case Map.values(updated_clients) do
      # IO.puts  "pid #{inspect(client_pid)}"
      [client_pid] ->
        IO.puts "client_pid sending create message to ===== #{inspect(client_pid)} =>#{inspect(message)}"
        # send(client_pid, {:offer, message})
        notify_state_update(:creating, updated_clients)
        notify_state_update(message, updated_clients)
        # notify_state_update(:offer, updated_clients)
        {:noreply, %{state | session_state: :creating}}



      [] ->
        IO.puts "No ready clients available for us to send creating"
        {:noreply, state}  # You can decide how to handle this case, like returning an error or keeping the state unchanged.

      _ ->
        IO.puts "Multiple clients found, something is wrong"
        {:noreply, state}  # Handle unexpected scenarios where there are multiple clients
    end

    # notify_state_update(:offer, updated_clients)
  end


  # New clause to handle the :creating state
  def handle_offer(session_id, message, %{clients: clients, session_state: :creating} = state) do
    IO.puts "Session is still being created. Ignoring offer for session: #{session_id}"

    IO.puts "session_id "<>session_id<>" message "<>message
    clients = Map.delete(state.clients, session_id)
    IO.puts "clients #{inspect(clients)}"

    [client_pid] = Map.values(clients)
    IO.puts "client_pid ===== #{inspect(client_pid)}"

    notify_state_update(:active, clients)
    {:noreply, state}
  end


    def handle_offer(session_id, message, %{clients: clients, session_state: :active} = state) do
      IO.puts "Session is still being created. Ignoring offer for session: #{session_id}"

      IO.puts "session_id "<>session_id<>" message "<>message
      clients = Map.delete(state.clients, session_id)
      IO.puts "clients #{inspect(clients)}"

      [client_pid] = Map.values(clients)
      IO.puts "client_pid ===== #{inspect(client_pid)}"
      send(client_pid, {:active, message})
      {:noreply, state}
    end


    def handle_offer(session_id, message, %{clients: clients, session_state: :offer} = state) do
      IO.puts "Session is still being created. Ignoring offer for session: #{session_id}"

      IO.puts "session_id "<>session_id<>" message "<>message
      clients = Map.delete(state.clients, session_id)
      IO.puts "clients #{inspect(clients)}"

      [client_pid] = Map.values(clients)
      IO.puts "client_pid ===== #{inspect(client_pid)}"
      send(client_pid, {:offer, message})
      notify_state_update(:offer, clients)
      {:noreply, state}
    end

  defp handle_answer(session_id, message, %{session_state: :creating} = state) do
    IO.puts "in handle answer"
    clients = Map.delete(state.clients, session_id)
    [client_pid] = Map.values(clients)
    # send(client_pid, {:answer, message})
    notify_state_update(message, clients)
    notify_state_update(:active, state.clients)
    {:noreply, %{state | session_state: :active}}
  end

  defp handle_ice(session_id, message, state) do
    IO.puts "in handle ice "#{session_id} #{state.clients}

    # Delete the session_id from the clients map
    clients = Map.delete(state.clients, session_id)

    # Check if there are any clients left to send the message to
    case Map.values(clients) do
      [client_pid | _rest] ->
        # If there is at least one client, send the message
        send(client_pid, {:ice, message})
        # notify_state_update(:active, clients)
          # notify_state_update(:active, clients)
      [] ->
        # If no clients remain, log an appropriate message
        IO.puts "No clients available to send the ICE candidate"
    end

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
