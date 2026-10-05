# Fires every 10 seconds from config/recurring.yml so the scan interval can change at runtime.
class ScanTickJob < ApplicationJob
  def perform
    ScanJob.perform_later if Setting.current.scan_due?
  end
end
