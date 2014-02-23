require 'sinatra'
require 'json'
require 'net/http'
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

  def slugify string
    string.strip.tr(' ', '_').downcase
  end

  def remove_old_company slug
    old_company = Company.first(slug: slug)
    old_company.destroy if old_company
  end

  def polarity_class news_source
    response = "neutral_polarity"
    response = "positive_polarity" if news_source.polarity > 0.3
    response = "negative_polarity" if news_source.polarity < -0.3
    response
  end

  def search_companies input
    slug = slugify(input)
    if slug == "*"
      companies = Company.all
    else
      companies = Company.all(slug: slug)
    end
    response = []
    companies.each do |company|
      binding.pry
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

  def request_news_stories id, name
    uri = URI.parse("http://s.craigsnowden.com:5000/queue")
    response = Net::HTTP.post_form(uri, { id: id, name: name })
  end

end

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_WHITE_URL'] || ENV['LOCAL_URL'])

class Company
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :slug, String
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

#file routing

get '/style.css' do
  send_file 'style.css'
end

#home
get '/' do
  erb :index
end

#companies

#index
get '/companies' do
  erb :companies, :locals => { :companies => Company.all }
end

#new
get '/companies/new' do
  protected!
  erb :new_company
end

#show
get '/companies/:id' do |id|
  company_id = Sanitize.clean(id)
  company = Company.first(id: company_id)
  news_sources = NewsSource.all(company_id: company_id)
  erb :company, locals: { company: company, news_sources: news_sources }
end


#create
post '/companies' do
  protected!
  name = Sanitize.clean(params[:name])
  slug = slugify(name)
  remove_old_company slug
  company = Company.create({
    name: name,
    slug: slug,
    mission_statement: Sanitize.clean(params[:mission_statement])
  })
  request_news_stories name, company.id
  redirect to("/companies/#{company.id}")
end

#json
get '/companies.json' do
  Company.all.to_json
end

#search
get '/search/:slug.json' do |slug|
  search_companies(Sanitize.clean(slug)).to_json
end

#investigation

#index
get '/investigations' do
  protected!
  erb :investigations, :locals => { :companies => Company.all }
end

#create
get '/investigations/new' do
  protected!
  company_id = Sanitize.clean(params[:company_id])
  company = Company.first(id: company_id)
  erb :new_investigation, locals: { company: company }
end

#update
post '/investigations' do
  protected!
  id = Sanitize.clean(params[:company_id])
  company = Company.first(id: id)
  company.update({
    mission_statement_proof: Sanitize.clean(params[:mission_statement_proof]),
    mission_statement_investigator: Sanitize.clean(params[:mission_statement_investigator])
  })
  redirect to("/investigations")
end

# news sources

#index
get '/news_sources' do
  erb :news_sources, locals: { news_sources: NewsSource.all }
end

#show
get '/news_sources/:id' do |id|
  erb :news_source, locals: { news_source: NewsSource.first(Sanitize.clean(id))}
end

#json
get '/news_sources.json' do
  NewsSource.all.to_json
end

#new
post '/news_sources/:id' do |id|
  protected!
  NewsSource.create!({
    :company_id => Sanitize.clean(id),
    :name => Sanitize.clean(params["source"]),
    :headline => Sanitize.clean(params["title"]),
    :url => Sanitize.clean(params["url"]),
    :polarity => Sanitize.clean(params["score"])
  })
end
