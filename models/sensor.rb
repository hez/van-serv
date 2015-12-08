require "remote_device"

class Sensor < RemoteDevice
  before_create { self.device_type = "input" }

  def read_only?; true; end
end
