defmodule SessionManager do
  use GenServer

  alias Phoenix.PubSub

  @topic "webrtc_session"

  @enforce_keys [:state]
  defstruct clients: %{}, state: :impossible

  # Starting the GenServer
  def start_link(_opts) do
    # Initialize with a default state
    GenServer.start_link(__MODULE__, %SessionManager{state: :impossible}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  # Public API
  def on_session_started(session_id, pid) do
    GenServer.call(__MODULE__, {:start_session, session_id, pid})
  end

  def on_message(session_id, message) do
    GenServer.cast(__MODULE__, {:message, session_id, message})
  end

  def on_session_close(session_id) do
    GenServer.call(__MODULE__, {:close_session, session_id})
  end

  # Callbacks
  def handle_call({:start_session, session_id, pid}, _from, %SessionManager{clients: clients} = state) do
    if map_size(clients) > 1 do
      send(pid, :close)
      {:reply, :too_many_clients, state}
    else
      new_clients = Map.put(clients, session_id, pid)
      new_state = if map_size(new_clients) > 1, do: :ready, else: :impossible
      notify_about_state_update(%{state | clients: new_clients, state: new_state})
      {:reply, {:ok, session_id}, %{state | clients: new_clients}}
    end
  end

  def handle_call({:close_session, session_id}, _from, %SessionManager{clients: clients} = state) do
    new_clients = Map.delete(clients, session_id)
    new_state = if map_size(new_clients) < 2, do: :impossible, else: state.state
    notify_about_state_update(%{state | clients: new_clients, state: new_state})
    {:reply, :ok, %{state | clients: new_clients}}
  end

  def handle_cast({:message, session_id, message}, %SessionManager{clients: clients, state: state} = current_state) do
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
    send(client_pid, {:state, state})
  end

  defp handle_offer(session_id, message, %SessionManager{clients: clients, state: :ready} = state) do
    new_state = %{state | state: :creating}
    target_client = Enum.find(clients, fn {id, _} -> id != session_id end) |> elem(1)
    send(target_client, {:offer, message})
    notify_about_state_update(new_state)
  end

  defp handle_answer(session_id, message, %SessionManager{clients: clients, state: :creating} = state) do
    target_client = Enum.find(clients, fn {id, _} -> id != session_id end) |> elem(1)
    send(target_client, {:answer, message})
    new_state = %{state | state: :active}
    notify_about_state_update(new_state)
  end

  defp handle_ice(session_id, message, %SessionManager{clients: clients} = state) do
    target_client = Enum.find(clients, fn {id, _} -> id != session_id end) |> elem(1)
    send(target_client, {:ice, message})
  end

  defp notify_about_state_update(%SessionManager{clients: clients, state: state}) do
    for {_, pid} <- clients do
      send(pid, {:state, state})
    end
  end
end
