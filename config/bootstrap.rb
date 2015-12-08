require "rubygems"
require "pathname"

APP_ROOT = File.join(Pathname.new(__FILE__).dirname, "..")
$: << File.join(APP_ROOT, "models")
