defmodule HelloWeb.PollLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    Current Votes: <%= @vote_count %><br />
    <button phx-click="add_vote">Vote</button>
    """
  end

  def mount(%{"poll_id" => poll_id}, _session, socket) do
    HelloWeb.PollSupervisor.start_poll(poll_id)
    Phoenix.PubSub.subscribe(Hello.PubSub, "poll:#{poll_id}")

    vote_count = HelloWeb.Poll.get_vote_count(poll_id)
    socket = assign(socket, :poll_id, poll_id)

    {:ok, assign(socket, :vote_count, vote_count)}
  end

  def handle_event("add_vote", _params, socket) do
    poll_id = socket.assigns.poll_id
    HelloWeb.Poll.increment_vote(poll_id)
    {:noreply, socket}
  end

  def handle_info({:vote_updated, vote_count}, socket) do
    {:noreply, assign(socket, :vote_count, vote_count)}
  end
end
