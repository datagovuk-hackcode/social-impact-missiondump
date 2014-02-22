require 'sinatra'
require 'json'
require 'net/http'
require 'uri'
require 'pry'

get '/' do
  send_file 'sample.html'
end

get '/script.js' do
  send_file 'script.js'
end

get '/style.css' do
  send_file 'style.css'
end

# get '/favicon.ico' do
#   send_file 'favicon.ico'
# end

get '/sample.json' do
  # uri = URI.parse("http://pod.opendatasoft.com/api/records/1.0/search")
  # response = Net::HTTP.post_form(uri, {
  #   dataset: "pod_brand",
  #   facet: "brand_nm", 
  #   facet: "owner_nm"
  # })
  # json = JSON.parse(response.body)
   {
    company_name: 'Coca-Cola' || params[:company_name],
    mission_statement: 'Coca-Cola is awesome x approx 150 words',
    mission_statement_proof: 'Coca cola IS awesome for realz',
    mission_statement_investigator: 'John Smith - WHO',
    news_sources: [
      { 
        name: "Al Jazeera",
        headline: 'Coke killed 15 people today',
        polarity: 0.1
      },
      {
        name: 'New York Times',
        headline: 'Coke have found a cure for cancer',
        polarity: 0.9
      },
    ]
  }.to_json
end