require "remote_device"

class Knob < RemoteDevice
  before_create { self.device_type = "input" }
end
