defmodule WebrtcPhoenix.Repo do
  use Ecto.Repo,
    otp_app: :webrtc_phoenix,
    adapter: Ecto.Adapters.Postgres
end
