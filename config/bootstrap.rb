require "rubygems"
require "pathname"

require "sinatra/base"
require "sinatra/namespace"
require "sinatra/reloader"
require "sinatra/json"
require "tilt/erb"
require "singleton"
require "i2c/i2c"

require File.join(File.dirname(__FILE__), "database")

APP_ROOT = File.join(Pathname.new(__FILE__).dirname, "..")
$: << File.join(APP_ROOT, "models")
