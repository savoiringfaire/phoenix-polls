defmodule Hello.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  schema "polls" do
    field :name, :string
    field :vote_count, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:name, :vote_count])
    |> validate_required([:name])
  end
end
