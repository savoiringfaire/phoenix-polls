defmodule HelloWeb.PollSupervisor do
  use DynamicSupervisor

  def init(_init_arg) do
    # Define the supervision strategy here. Usually, for a DynamicSupervisor, it's :one_for_one
    # This means if a child process terminates, only that process is restarted.
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__, restart: :temporary)
  end

  def start_poll(poll_id) do
    case DynamicSupervisor.start_child(__MODULE__, {HelloWeb.Poll, poll_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end
end
