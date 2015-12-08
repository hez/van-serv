require "active_record"

class RemoteDevice < ActiveRecord::Base
  TYPES = [:knob, :sensor]

  enum device_type: [:input, :output]

  def exportable
    {id: id, name: name, device: device, address: address, value: value}
  end

  def read_only?; false; end
end
