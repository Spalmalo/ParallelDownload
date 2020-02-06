import Config
# Path to directory for temporary files. /tmp is the best place to use.
config :parallel_download, tmp_dir_path: "/tmp/paralleldownload"

# Timeout for Task.async jobs. Could be positive integer value in milliseconds or :infinity
config :parallel_download, task_await_timeout: 20 * 60_000

# Download results store directory. Used only in tests
config :parallel_download, results_dir_path_for_tests: "downloads"

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]
