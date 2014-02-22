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
        news_sources: NewsSource.all(company_id: company.id)
      }
    end
    response
  end

  def create_news_stories name, id
    news_items = fetch_news_stories name 
    news_items.each do |news_item|
      NewsSource.create!({
        :company_id => id,
        :name => news_item["source"],
        :headline => news_item["title"],
        :url => news_item["url"],
        :polarity => news_item["score"]
      })
    end
  end

  def fetch_news_stories name
    uri = URI.parse("http://79df7f35.ngrok.com/news/#{name}")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body)
  end
end

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_WHITE_URL'] || ENV['LOCAL_URL'])

class Company
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :mission_statement, Text, lazy: false
  property :mission_statement_proof, Text, lazy: false
  property :mission_statement_investigator, String
end

class NewsSource
  include DataMapper::Resource
  property :id, Serial
  property :company_id, Integer
  property :name, Text, lazy: false
  property :headline, Text, lazy: false
  property :polarity, Float 
  property :url, Text, lazy: false
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
  erb :companies, :locals => { :companies => Company.all }
end

get '/companies' do
  erb :companies, :locals => { :companies => Company.all }
end

get '/companies' do
  company_id = Sanitize.clean(params[:company_id])
  company = Company.first(id: company_id)
  erb :company, :locals => { company => company }
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
  name = Sanitize.clean(params[:name])
  company = Company.create({
    name: name,
    mission_statement: Sanitize.clean(params[:mission_statement])
  })
  create_news_stories name, company.id
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