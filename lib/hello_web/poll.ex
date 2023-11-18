defmodule HelloWeb.Poll do
  use GenServer, restart: :temporary

  @inactive_timeout 2 * 60 * 60 * 1000
  @update_interval 100

  def start_link(poll_id) do
    GenServer.start_link(__MODULE__, poll_id, name: {:global, poll_id})
  end

  def init(poll_id) do
    poll = Hello.Repo.get_by(Hello.Poll, name: poll_id) ||
      Hello.Repo.insert!(%Hello.Poll{name: poll_id, vote_count: 0})

    state = %{
      poll: poll,
      timer_ref: schedule_timer(),
      last_reset_time: :erlang.system_time(:millisecond),
      countdown: @inactive_timeout,
      update_ref: schedule_update(@update_interval)
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

  def handle_info(:timeout, state) do
    # Terminate if timeout message is received
    IO.puts("Stopping")
    {:stop, :normal, state}
  end

  def terminate(_reason, _state) do
    # Perform any necessary cleanup
    :ok
  end

  def handle_info(:update, state) do
    current_time = :erlang.system_time(:millisecond)
    time_since_last_reset = current_time - state.last_reset_time
    remaining_time = @inactive_timeout - time_since_last_reset

    schedule_update(@update_interval)

    Phoenix.PubSub.broadcast(Hello.PubSub, "poll:#{state.poll.name}", {:countdown_update, remaining_time})
      {:noreply, state}
  end

  def handle_call(:get_vote_count, _from, state) do
    Process.cancel_timer(state.timer_ref)
    new_timer_ref = schedule_timer()

    {:reply, state.poll.vote_count, %{state | timer_ref: new_timer_ref, last_reset_time: :erlang.system_time(:millisecond)}}
  end

  def handle_cast(:increment_vote, state) do
    updated_poll = 
      state.poll
      |> Ecto.Changeset.change(%{vote_count: state.poll.vote_count + 1})
      |> Hello.Repo.update!()

    Process.cancel_timer(state.timer_ref)
    new_timer_ref = schedule_timer()

    # Broadcast vote update
    Phoenix.PubSub.broadcast(Hello.PubSub, "poll:#{state.poll.name}", {:vote_updated, state.poll.vote_count + 1})

    {:noreply, %{state | poll: updated_poll, timer_ref: new_timer_ref, last_reset_time: :erlang.system_time(:millisecond)}}
  end

  defp schedule_timer do
    Process.send_after(self(), :timeout, @inactive_timeout)
  end

  defp schedule_update(interval) do
    Process.send_after(self(), :update, interval)
  end

  defp ensure_poll_process(poll_id) do
    if :global.whereis_name(poll_id) == :undefined do
      case HelloWeb.PollSupervisor.start_poll(poll_id) do
        {:ok, _pid} -> :ok
        {:error, _reason} -> 
          # Handle error (e.g., log it or raise an exception)
      end
    else
      :ok
    end
  end
end