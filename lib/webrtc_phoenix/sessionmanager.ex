defmodule SessionManager do
  use GenServer
  require Logger

  @topic "webrtc_session"

  @enforce_keys [:state]
  defstruct clients: %{}, state: :impossible

  # Starting the GenServer
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %SessionManager{state: :impossible}, name: __MODULE__)
  end


  def init(state) do
    {:ok, state}
  end



  # Public API
  @spec on_session_started(any(), any()) :: any()
  def on_session_started(session_id, pid) do
    Logger.info("on_session_started called for #{inspect(session_id)}")
    GenServer.call(__MODULE__, {:start_session, session_id, pid})
  end

  def on_message(session_id, message) do
    GenServer.cast(__MODULE__, {:message, session_id, message})
  end

  def on_session_close(session_id) do
    GenServer.call(__MODULE__, {:close_session, session_id})
  end

  def handle_call({:start_session, session_id, pid}, _from, %SessionManager{clients: clients} = state) do
    Logger.info("handle_call for session: #{inspect(session_id)}")
    Logger.info("handle_call for pid: #{inspect(pid)}")

    if map_size(clients) >= 2 do
        send(pid, :close)
        {:reply, :too_many_clients, state}
    else
        Logger.info("Adding client #{inspect(session_id)}")
        new_clients = Map.put(clients, session_id, pid)

        new_state = if map_size(new_clients) >= 2, do: :ready, else: :impossible

        # Notify about state update
        notify_about_state_update(%{state | clients: new_clients, state: new_state})

        {:reply, {:ok, session_id}, %{state | clients: new_clients}}
    end
end


  def handle_call({:close_session, session_id}, _from, %SessionManager{clients: clients} = state) do
    Logger.info("Closing session: #{inspect(session_id)}")
    new_clients = Map.delete(clients, session_id)
    new_state = if map_size(new_clients) < 2, do: :impossible, else: state.state
    notify_about_state_update(%{state | clients: new_clients, state: new_state})
    {:reply, :ok, %{state | clients: new_clients}}
  end

  def handle_cast({:message, session_id, message}, %SessionManager{clients: clients, state: state} = current_state) do
    Logger.info("Received message from #{inspect(session_id)}: #{inspect(message)}")

    cond do
      String.starts_with?(message, "STATE") -> handle_state(session_id, clients[session_id], state)
      String.starts_with?(message, "OFFER") -> handle_offer(session_id, message, current_state)
      String.starts_with?(message, "ANSWER") -> handle_answer(session_id, message, current_state)
      String.starts_with?(message, "ICE") -> handle_ice(session_id, message, current_state)
    end

    {:noreply, current_state}
  end

  # Internal Logic
  defp handle_state(session_id, client_pid, state) do
    Logger.info("Handling state request for #{inspect(session_id)}")
    if Process.alive?(client_pid) do
      send(client_pid, {:state, state})
    else
      Logger.error("Client #{inspect(session_id)} is not alive.")
    end
  end

  defp handle_offer(session_id, message, %SessionManager{clients: clients, state: :ready} = state) do
    Logger.info("Handling offer from #{inspect(session_id)}")
    target_client = find_target_client(session_id, clients)
    if target_client do
      send(target_client, {:offer, message})
    else
      Logger.warn("No target client available to send the offer.")
    end
  end

  defp handle_answer(session_id, message, %SessionManager{clients: clients, state: :creating} = state) do
    Logger.info("Handling answer from #{inspect(session_id)}")
    target_client = find_target_client(session_id, clients)
    if target_client do
      send(target_client, {:answer, message})
    else
      Logger.warn("No target client available to send the answer.")
    end
  end

  defp handle_ice(session_id, message, %SessionManager{clients: clients} = state) do
    Logger.info("Handling ICE candidate from #{inspect(session_id)}")
    target_client = find_target_client(session_id, clients)
    if target_client do
      send(target_client, {:ice, message})
    else
      Logger.warn("No target client available to send the ICE candidate.")
    end
  end

  defp find_target_client(session_id, clients) do
    clients
    |> Enum.filter(fn {id, _} -> id != session_id end)
    |> Enum.map(&elem(&1, 1))
    |> List.first()
  end

  defp notify_about_state_update(%SessionManager{clients: clients, state: state}) do
    Logger.info("Clients: #{inspect(clients)}")
    Logger.info("State: #{inspect(state)}")

    Enum.each(clients, fn {key, pid} ->
        if Process.alive?(pid) do
            Logger.info("Before Sent state #{inspect(state)} to client #{inspect(key)}")
          send(pid, {:state, state})
          
            Logger.info("AfterSent state #{inspect(state)} to client #{inspect(key)}")
        else
            Logger.error("Client #{inspect(key)} has a dead process with PID: #{inspect(pid)}")
        end
    end)
end


end
