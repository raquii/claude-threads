class ScanJob < ApplicationJob
  limits_concurrency to: 1, key: "scan", duration: 10.minutes, on_conflict: :discard

  def perform
    Scanner.new.run
  end
end
