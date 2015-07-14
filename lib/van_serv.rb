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
  def exportable
    {id: id, name: name, address: read_address, device: read_device}
  end
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
    [rand(2), 0, rand(4), rand(255)].pack("CCCC")
  end
end

class DataSource
  include Singleton
  include PackingHelpers

  PACKET_SIZE = 4

  def initialize
#@arduino = I2C.create("/dev/i2c-1")
    @arduino = DummyI2C.new
  end

  def fetch(devices)
    ret = []
    more_data = false
    devices.each do |device_address; address, value, more_data|
      loop do
        address, value, more_data = parse(@arduino.read(device_address, PACKET_SIZE))
        ret << {device: device_address, address: address, value: value} if address != 0
        break unless more_data
      end
    end
    puts ret.inspect
    ret
  end

  def start_thread
    fetch_thread.run
  end

  private
  def parse(response)
    address = response[0].unpack("C")[0]
    more_data = (response[1].unpack("C")[0] == 1)
    value = high_low_unpack(response[2..3])

    [address, value, more_data]
  end

  def fetch_thread
    @thread ||= Thread.new(self) do |data_source|
      begin
        while true do
          ActiveRecord::Base.connection_pool.with_connection do
            device_addresses = RemoteDevice.uniq(:read_device).pluck(:read_device)
            new_values = data_source.fetch(device_addresses)
            new_values.each do |update_vals|
              RemoteDevice.where(read_device: update_vals[:device], read_address: update_vals[:address]).
                update_all(value: update_vals[:value])
            end
          end
          sleep 0.5
        end
      rescue
        puts $!
        puts $!.backtrace
      end
    end
  end
end

class VanServ < Sinatra::Base
  configure do
    DataSource.instance.start_thread
    set :server, :thin
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
    remote_devices = RemoteDevice.all.collect {|i| i.exportable }
    remote_devices.to_json
  end

  get "/api/remote_data/:id" do
    remote_device = RemoteDevice.find(params[:id].to_i)
    remote_device.exportable.to_json
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
