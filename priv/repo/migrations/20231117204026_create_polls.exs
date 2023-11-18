defmodule Hello.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    create table(:polls) do
      add :name, :string
      add :vote_count, :integer, default: 0

      timestamps()
    end
  end
end
