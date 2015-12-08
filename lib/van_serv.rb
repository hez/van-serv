require "./config/bootstrap"

require "sinatra/base"
require "sinatra/namespace"
require "sinatra/reloader"
require "sinatra/json"
require "tilt/erb"
require "singleton"
require "i2c/i2c"

# Models
require "knob"
require "sensor"

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database =>  'sinatra_application.sqlite3.db'
)

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
    ret
  end

  def start_thread
    puts 'starting thread'
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
            device_addresses = RemoteDevice.uniq(:device).pluck(:device)
            new_values = data_source.fetch(device_addresses)
            new_values.each do |update_vals|
              RemoteDevice.where(device: update_vals[:device], address: update_vals[:address]).each do |remote_device|
                remote_device.value = update_vals[:value]
                remote_device.save
              end
            end
          end
          sleep 0.5
        end
      rescue
        puts $!
        puts $!.backtrace
      end
      puts 'thread done'
    end
  end
end

class VanServ < Sinatra::Base
  register Sinatra::Namespace

  configure :development do
    register Sinatra::Reloader
  end

  configure do
    DataSource.instance.start_thread
    enable :method_override
    set :server, :thin
    set :views, [ "./views" ]
    set :public_folder, "public"
  end

  get "/" do
    @remote_devices = RemoteDevice.all
    puts @remote_devices.inspect
    erb :index
  end

  get "/devices" do
    @devices = `sudo i2cdetect -y 1`
    erb :devices
  end

  namespace "/remote_device" do
    # Show
    get "/:id" do
      @remote_device = RemoteDevice.find(params[:id])
      erb :"remote_devices/show"
    end

    # New
    get "/new" do
      @remote_device = RemoteDevice.new
      erb :"remote_devices/new"
    end

    # Create
    post "/" do
      device_klass = Kernel.const_get(params[:device_type].capitalize)
      @remote_device = device_klass.new(params[:remote_device])
      if @remote_device.save
        redirect "/remote_device/#{@remote_device.id}"
      else
        erb :"remote_devices/new"
      end
    end

    # Edit
    get "/:id/edit" do
      @remote_device = RemoteDevice.find(params[:id])
      erb :"remote_devices/edit"
    end

    # Update
    put "/:id" do
      @remote_device = RemoteDevice.find(params[:id])
      @remote_device.update_attributes(params[:remote_device])
      if @remote_device.save
        redirect "/remote_device/#{@remote_device.id}"
      else
        erb :"remote_devices/new"
      end
    end

    delete "/:id" do
      @remote_device = RemoteDevice.find(params[:id])
      @remote_device.delete
      redirect "/"
    end
  end

  namespace "/api" do
    get "/remote_data" do
      remote_devices = RemoteDevice.all.collect {|i| i.exportable }
      json remote_devices
    end

    get "/remote_data/:id" do
      remote_device = RemoteDevice.find(params[:id].to_i)
      puts remote_device.exportable.inspect
      json remote_device.exportable
    end
  end
end
