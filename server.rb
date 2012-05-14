require 'em-http'
require 'em-mongo'
require 'yajl'
require 'log4r'
require 'goliath'

class EventGenerator < Goliath::API
  def on_close(env)
    return unless env['subscription']

    $channel.unsubscribe(env['subscription'])
    env.logger.info "Stream connection closed."
  end

  def response(env)
    env['subscription'] = $channel.subscribe do |event|
      location = {lat: event["location"]["latitude"].to_f, lng: event["location"]["longitude"].to_f }
      env.stream_send(["event:push_event", "data:#{Yajl::Encoder.encode(location)}\n\n"].join("\n"))
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end
end

class Server < Goliath::API
  use Goliath::Rack::Params

  use Goliath::Rack::Heartbeat
  use Goliath::Rack::Validation::RequestMethod, %w(GET)

  use Rack::Static, :urls => ["/index.html"], :root => Goliath::Application.app_path("public")

  get "/events" do
    run EventGenerator.new
  end

  get "/" do
    run lambda{ |env| [301, {"Location" => "/index.html"}, self] }
  end
end
