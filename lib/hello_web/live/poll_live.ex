defmodule HelloWeb.PollLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current Votes: <%= @vote_count %><br />
    <button phx-click="add_vote">Vote</button><br />
    Expires in: <%= @countdown/1000/60 %>
    """
  end

  def mount(%{"poll_id" => poll_id}, _session, socket) do
    IO.puts("mount")

    HelloWeb.PollSupervisor.start_poll(poll_id)
    Phoenix.PubSub.subscribe(Hello.PubSub, "poll:#{poll_id}")

    vote_count = HelloWeb.Poll.get_vote_count(poll_id)
    socket = assign(socket, :poll_id, poll_id)
    socket = assign(socket, :countdown, 0)

    {:ok, assign(socket, :vote_count, vote_count)}
  end

  def handle_event("add_vote", _params, socket) do
    IO.puts("add_vote")
    poll_id = socket.assigns.poll_id
    HelloWeb.Poll.increment_vote(poll_id)
    {:noreply, socket}
  end

  def handle_info({:vote_updated, vote_count}, socket) do
    IO.puts("vote_updated")
    {:noreply, assign(socket, :vote_count, vote_count)}
  end

  def handle_info({:countdown_update, countdown}, socket) do
    {:noreply, assign(socket, :countdown, countdown)}
  end
end
