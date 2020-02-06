defmodule ParallelDownload.Supervisor do
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @doc """
  Starts new ParallelDownload.HTTPClient with given arguments and adds it to supervisor.
  """
  def start_client(args) do
    spec = {ParallelDownload.HTTPClient, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_arg) do
    :inets.start()
    :ssl.start()
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
