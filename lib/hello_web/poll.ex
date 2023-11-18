defmodule HelloWeb.Poll do
  use GenServer, restart: :temporary

  @inactive_timeout 2 * 60 * 60 * 1000

  def start_link(poll_id) do
    GenServer.start_link(__MODULE__, poll_id, name: {:global, poll_id})
  end

  def init(poll_id) do
    poll =
      Hello.Repo.get_by(Hello.Poll, name: poll_id) ||
        Hello.Repo.insert!(%Hello.Poll{name: poll_id, vote_count: 0})

    state = %{
      poll: poll,
      timer_ref: schedule_timer(),
    }

    {:ok, state}
  end

  def get_vote_count(poll_id) do
    GenServer.call({:global, poll_id}, :get_vote_count)
  end

  def increment_vote(poll_id) do
    ensure_poll_process(poll_id)
    GenServer.cast({:global, poll_id}, :increment_vote)
  end

  def terminate(_reason, _state) do
    # Perform any necessary cleanup
    :ok
  end

  def handle_info(:timeout, state) do
    # Terminate if timeout message is received
    IO.puts("Stopping")
    {:stop, :normal, state}
  end

  def handle_call(:get_vote_count, _from, state) do
    Process.cancel_timer(state.timer_ref)
    new_timer_ref = schedule_timer()

    {:reply, state.poll.vote_count,
     %{state | timer_ref: new_timer_ref}}
  end

  def handle_cast(:increment_vote, state) do
    updated_poll =
      state.poll
      |> Ecto.Changeset.change(%{vote_count: state.poll.vote_count + 1})
      |> Hello.Repo.update!()

    Process.cancel_timer(state.timer_ref)
    new_timer_ref = schedule_timer()

    # Broadcast vote update
    Phoenix.PubSub.broadcast(
      Hello.PubSub,
      "poll:#{state.poll.name}",
      {:vote_updated, state.poll.vote_count + 1}
    )

    {:noreply,
     %{
       state
       | poll: updated_poll,
         timer_ref: new_timer_ref
     }}
  end

  defp schedule_timer do
    Process.send_after(self(), :timeout, @inactive_timeout)
  end

  defp ensure_poll_process(poll_id) do
    if :global.whereis_name(poll_id) == :undefined do
      case HelloWeb.PollSupervisor.start_poll(poll_id) do
        {:ok, _pid} ->
          :ok

        {:error, reason} ->
          IO.puts(reason)
      end
    else
      :ok
    end
  end
end
