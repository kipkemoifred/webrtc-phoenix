defmodule WebrtcPhoenixWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "room:*", WebrtcPhoenixWeb.RoomChannel

  # When a user connects, you can assign them an ID
  def connect(%{"token" => token}, socket, _connect_info) do
    {:ok, assign(socket, :user_id, verify_user_token(token))}
  end

  # Optional function to identify a socket connection
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

    # Define the token verification function
    defp verify_user_token(token) do
      # Example verification logic:
      if token == "valid_token" do
        {:ok, 123}  # Example user ID
      else
        :error
      end
    end
end
