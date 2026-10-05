class SettingsController < ApplicationController
  def edit
    @setting = Setting.current
  end

  def update
    @setting = Setting.current
    if @setting.update(params.expect(setting: %i[scan_interval_seconds claude_path projects_root appearance theme font editor]))
      redirect_to root_path, notice: "Settings saved"
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
