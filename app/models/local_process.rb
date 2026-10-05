module LocalProcess
  def self.alive?(pid)
    Process.kill(0, pid.to_i)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end
end
