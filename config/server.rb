require 'uri'

@log = Log4r::Logger.new('github')
@log.add(Log4r::StdoutOutputter.new('console', {
  :formatter => Log4r::PatternFormatter.new(:pattern => "[#{Process.pid}:%l] %d :: %m")
}))

@latest = []

if Goliath.env == :production
  uri  = URI.parse(ENV['MONGOLAB_URI'])
  db_name = uri.path.gsub(/^\//, '')
  db = EM::Mongo::Connection.new(uri.host, uri.port).db(db_name)
  db.authenticate(uri.user, uri.password)
else
  db = EM::Mongo::Connection.new('localhost').db('heathub_development')
end

collection = db.collection('push_events')
cities_collection = db.collection('cities')
$channel = EM::Channel.new

process = Proc.new do
  req = EventMachine::HttpRequest.new("https://github.com/timeline.json").get({
    :head => {
      'user-agent' => 'abuiles.com'
    }
  })

  req.callback do
    begin
      latest = Yajl::Parser.parse(req.response)
      urls = latest.collect {|e| e['url']}
      new_events = latest.reject {|e| @latest.include? e['url']}

      @latest = urls
      new_events.each do |event|
        location = event["actor_attributes"] && event["actor_attributes"]["location"]
        next unless location && event["type"] == "PushEvent"

        @log.info "Event in city #{location}"

        cursor = cities_collection.find(_id: location)
        resp = cursor.defer_as_a

        resp.callback do |cities|
          if city = cities.first
            @log.info "using pre-store city #{location}"
            event["location"] = city["location"]
            event["city"] = location

            @log.info "Pushing event"
            $channel.push event

            collection.insert(event)
          else
            query = {:q => location, :flags => 'J'}
            http = EventMachine::HttpRequest.new('http://where.yahooapis.com/geocode').get :query => query

            http.errback { @log.error "Request to placefinder failed for #{location} " }
            http.callback {
              result = Yajl::Parser.parse(http.response)
              if result["ResultSet"]["Found"] > 0

                result = result["ResultSet"]["Results"].first
                event["location"] = {
                  "longitude" => result["longitude"],
                  "latitude"  => result["latitude"]
                }

                event["city"] = location

                city_info = { location: event["location"] }.merge(_id: location)

                cities_collection.insert( city_info)
                $channel.push event
                collection.insert(event)
              end
            }
          end

        end

        resp.errback do |err|
          raise *err
        end
      end

      @log.info "Found #{new_events.size} new events"

      if new_events.size >= 25
        EM.add_timer(1.5, &process)
      end

    rescue Exception => e
      @log.error "Processing exception: #{e}, #{e.backtrace.first(5)}"
      # @log.error "Response: #{req.response_header}, #{req.response}"
    end
  end

  req.errback do
    @log.error "Error: #{req.response_header.status}, header: #{req.response_header}, response: #{req.response}"
  end
end

EM.add_periodic_timer(6, &process)
