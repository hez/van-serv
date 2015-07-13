require "rubygems"
require "sinatra/base"
require "tilt/erb"
require "active_record"
require "singleton"
require "i2c/i2c"

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database =>  'sinatra_application.sqlite3.db'
)

class RemoteDevice < ActiveRecord::Base
end

class Knob < RemoteDevice
end

module PackingHelpers
  def high_low_unpack(values = [0x00, 0x00])
    values.unpack("H*")[0].hex
  end
end

class DummyI2C
  def read(device_address, size)
    "\x00\x00\x00\x50"
  end
end

class DataSource
  include Singleton
  include PackingHelpers

  def initialize
#@arduino = I2C.create("/dev/i2c-1")
    @arduino = DummyI2C.new
    @packet_size = 0x04
  end

  def fetch(devices)
    ret = []
    more_data = false
    devices.each do |device_address|
      loop do
        puts "fetching #{device_address}"
        val = @arduino.read(device_address, @packet_size)
        address = val[0].unpack("C")[0]
        more_data = (val[1].unpack("C")[0] == 1)
        value = high_low_unpack(val[2..3])
        ret << {device: device_address, address: address, value: value}

        break unless more_data
      end
    end
    puts ret.inspect
    ret
  end
end

class VanServ < Sinatra::Base
  configure do
    set :views, [ "./views" ]
    set :public_folder, "public"
  end

  get "/" do
    @lights = get_updated_ligths
    erb :index
  end

  get "/devices" do
    @devices = `sudo i2cdetect -y 1`
    puts @devices.inspect
    erb :devices
  end

  get "/api/remote_data" do
    remote_devices = RemoteDevice.all.collect {|i| {name: i.name, value: i.value, address: i.read_address} }
    remote_devices.to_json
  end

  def get_updated_ligths
    device_addresses = RemoteDevice.uniq(:read_device).pluck(:read_device)
    new_values = DataSource.instance.fetch(device_addresses)
    new_values.each do |update_vals|
      RemoteDevice.where(read_device: update_vals[:device], read_address: update_vals[:address]).
        update_all(value: update_vals[:value])
    end

    RemoteDevice.all
  end
end
