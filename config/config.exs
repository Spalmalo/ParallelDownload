import Config
# Path to directory for temporary files. /tmp is the best place to use.
config :parallel_download, tmp_dir_path: "/tmp/paralleldownload"

# Timeout for Task.async jobs.
config :parallel_download, task_await_timeout: 20 * 60_000

# Connection time-out time, used during the initial request, when the client is connecting to the server.
config :parallel_download, connect_timeout: 20 * 60_000

# Time-out time for the request. The clock starts ticking when the request is sent. Time is in milliseconds.
config :parallel_download, request_timeout: 20 * 60_000

# Download results store directory. Used only in tests
config :parallel_download, results_dir_path_for_tests: "downloads"

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
