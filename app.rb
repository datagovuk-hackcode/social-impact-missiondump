require 'sinatra'
require 'json'
require 'uri'
require 'pry'
require 'pg'
require 'data_mapper'
require 'dm-serializer'
require 'sanitize'

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['USERNAME'], ENV['PASSWORD']]
  end

  def fetch_companies query
    if query == "*"
      companies = Company.all
    else
      companies = Company.all(name: query)
    end
    response = []
    companies.each do |company|
      response << {
        name: company.name,
        mission_statement: company.mission_statement,
        mission_statement_proof: company.mission_statement_proof,
        mission_statement_investigator: company.mission_statement_proof,
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
          }
        ]
      }
    end
    response
  end
end

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_WHITE_URL'] || ENV['LOCAL_URL'])

class Company
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :mission_statement, Text,   :lazy => false
  property :mission_statement_proof, Text,   :lazy => false
  property :mission_statement_investigator, String
end

class NewsSource
  include DataMapper::Resource
  property :id, Serial
  property :company_id, Integer
  property :name, String
  property :headline, String
  property :polarity, Float  
  belongs_to :company
end  

DataMapper.finalize
DataMapper.auto_upgrade!

get '/script.js' do
  send_file 'script.js'
end

get '/style.css' do
  send_file 'style.css'
end

get '/' do
  erb :index
end

get '/companies' do
  erb :companies, :locals => { :companies => Company.all }
end

get '/companies/new' do
  protected!
  erb :new_company
end

get '/investigations' do
  protected!
  erb :investigations, :locals => { :companies => Company.all }
end

get '/investigations/new' do
  protected!
  company_id = Sanitize.clean(params[:company_id])
  company = Company.first(id: company_id)
  erb :new_investigation, :locals => { :company => company }
end

post '/companies' do
  protected!
  Company.create({
    name: Sanitize.clean(params[:name]),
    mission_statement: Sanitize.clean(params[:mission_statement])
  })
  redirect to('/companies.json')
end

post '/companies/update' do
  protected!
  company = Company.first(id: Sanitize.clean(params[:company_id]))
  company.update({
    mission_statement_proof: Sanitize.clean(params[:mission_statement_proof]),
    mission_statement_investigator: Sanitize.clean(params[:mission_statement_investigator])
  })
  redirect to('/companies.json')
end

get '/companies.json' do
  Company.all.to_json
end

get '/sample.json' do
  fetch_companies(Sanitize.clean(params[:name])).to_json
end