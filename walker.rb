require 'mongo'
require 'yajl'
require "net/http"
require "uri"

@conn = Mongo::Connection.new
@db   = @conn['heathub_development']

cities = @db['cities']
coll = @db['push_events']
places = Hash.new do |hsh, key|
  hsh[key] = []
end

coll.find.each do |row|
  next if row["location"] && row["location"]["longitude"]
  puts row["location"]

  # coll.update({"_id" => row["_id"]}, row)
end.nil?

# coll.find.each do |row|
#   next if row["location"]
#   uri = URI.parse("http://where.yahooapis.com/geocode")
#   uri.query = URI.encode_www_form({q: row["city"], flags: 'J' })
#   response = Net::HTTP.get_response(uri)
#   result = Yajl::Parser.parse response.body
#   if result["ResultSet"]["Found"] > 0
#     result = result["ResultSet"]["Results"].first
#     row["location"] = {
#       "longitude" => result["longitude"],
#       "latitude"  => result["latitude"]
#     }

#     coll.update({"_id" => row["_id"]}, row)
#   end
# end

  # row["city"] = row["actor_attributes"]["location"]
  # coll.update({"_id" => row["_id"]}, row)
  # unless row["location"]
  #   city = row["city"]
  #   coll.update({"_id" => row["_id"]}, row)
  # end
  # places[row["actor_attributes"]["location"]] << row["actor_attributes"]


hsh = Hash.new do |hsh, key|
  hsh[key] = 0
end

from = "2012/05/12 00:00:00 -0700"
to   = "2012/05/12 23:59:00 -0700"

coll.find("created_at" => {"$gte" => from, "$lte" => to }).each do |row|
  hsh[row["location"]] += 1
end.nil?

js = "data = ["
hsh = hsh.sort_by{|key, value| -value }
hsh = Hash[hsh.first(10)]
last = hsh.to_a.last.first
hsh.map {|key, value|
  if key == last
    js << "{lat: #{key["latitude"].to_f}, lng: #{key["longitude"].to_f}, count: #{value} }];"
  else
    js << "{lat: #{key["latitude"].to_f}, lng: #{key["longitude"].to_f}, count: #{value} },"
  end
}



js << "maxValue = #{hsh.values.max };"

File.open('./heatmap.js/demo/maps_heatmap_layer/data.js', 'w') { |f| f.write(js)}


places.each do |city, count|
  puts "#{city}     :#{count}"
end

puts "places count #{places.count}"



uri = URI.parse("http://where.yahooapis.com/geocode")
uri.query = URI.encode_www_form({q: row["city"], flags: 'J' })
response = Net::HTTP.get_response(uri)
result = Yajl::Parser.parse response.body
if result["ResultSet"]["Found"] > 0
  result = result["ResultSet"]["Results"].first
  row["location"] = {
    "longitude" => result["longitude"],
    "latitude"  => result["latitude"]
  }

  coll.update({"_id" => row["_id"]}, row)
end


cities = @db['cities']
cities.find.each do |city|
  puts city
end

# location = event["actor_attributes"]["location"]

# cities.insert({ location: event["location"] }.merge(_id: location))
# cities.find(_id: location).to_a
