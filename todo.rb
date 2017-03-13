# Note that this app relies on session data to be stored in the cookie - 
# that's what we manipulate here
# If we go into browser tools and delete the cookie, we lose the lists

require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
	enable :sessions
	set :session_secret, 'secret' #if we don't specify a value, Sinatra will specify
																# everytime it starts. That means if we ever stop
																# and start app, it will have a diff secret. If value
																# changes, any session previous will become invalid
end

before do
	session[:lists] ||= []
end

get "/" do
	redirect "/lists"
end

# URL design: Note that the URLS have names that are resource based - i.e. 
# they all refer to what they are affecting/viewing
# GET /lists
# GET /lists/new
# POST /lists
# GET /lists/1 -> view a single list
# GET /users
# GET /users/1	-> if this app had user info, we would build out URLs like this


# View list of lists
get "/lists" do
	@lists = session[:lists]
  erb :lists
end

# Render the new list form
get "/lists/new" do
	erb :new_list, layout: :layout
end

# Create a new list
## Note how we redirect when a valid action takes place, but instead render
## a page when there is some sort of error. This is due to stateless HTTP -
## if there is an error, we want to be able to go back and fix it... it may 
## be useful to have access to our parameters and any instance vars set in 
## the current route in that case. If we redirected to the new list page, 
## we would lose access to data related to the current request (see below)
post "/lists" do
	list_name = params[:list_name].strip
	if (1..100).cover? list_name.size #.include? would check every single value in range
		session[:lists] << { name: list_name, todos: [] }
		session[:success] = "The list has been created."
		redirect "/lists"
	else
		session[:error] = "List name must be between 1 and 100 characters."
		## i.e. if I redirected here, I would lose access to list_name var, or 
		## params[:list_name]
		erb :new_list, layout: :layout
	end
end
