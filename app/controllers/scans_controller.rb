class ScansController < ApplicationController
  def create
    ScanJob.perform_later
    redirect_back_or_to root_path, notice: "Scan started"
  end
end
