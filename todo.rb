# Note that this app relies on session data to be stored in the cookie - 
# that's what we manipulate here
# If we go into browser tools and delete the cookie, we lose the lists

require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
	enable :sessions
	set :session_secret, 'secret' #if we don't specify a value, Sinatra will specify
																# everytime it starts. That means if we ever stop
																# and start app, it will have a diff secret. If value
																# changes, any session previous will become invalid
end

#accessible in any view template, or routes in this file
#if there are methods you want to share that aren't needed in views,
#don't need to go in helpers (and shouldn't, to better delineate the code)
helpers do
	def list_complete?(list)
		todos_count(list) > 0 && todos_remaining_count(list) == 0
	end

#we don't need to worry about returning nil
	def list_class(list)
		"complete" if list_complete?(list)
	end

	def todos_count(list)
		list[:todos].size
	end

	def todos_remaining_count(list)
		list[:todos].select { |todo| !todo[:completed] }.size
	end

		#we can use hashes because they are now ordered in Ruby
	def sort_lists(lists, &block)
		complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

		incomplete_lists.each { |list| yield list, lists.index(list) }
		complete_lists.each { |list| yield list, lists.index(list) }
	end

	#You can compare this with sort_lists method to see different approaches. Ultimately,
	# unless what you are doing is very performant sensitive, choose the one that reads easier -
	# in this case, sort_lists
	def sort_todos(todos, &block)
		complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

		incomplete_todos.each { |todo| yield todo, todos.index(todo) }
		complete_todos.each { |todo| yield todo, todos.index(todo) }
	end
end

before do
	session[:lists] ||= []
end

get "/" do
	redirect "/lists"
end

#URL design: Note that the URLS have names that are resource based - i.e. 
#they all refer to what they are affecting/viewing
#GET /lists
#GET /lists/new
#POST /lists
#GET /lists/1 -> view a single list
#GET /users
#GET /users/1	-> if this app had user info, we would build out URLs like this


# View list of lists
get "/lists" do
	@lists = session[:lists]
  erb :lists
end

# Render the new list form
get "/lists/new" do
	erb :new_list, layout: :layout
end

#Return an error message if the name is invalid. Otherwise will return nil
def error_for_list_name(name)
	if !(1..100).cover? name.size #.include? would check every single value in range
		"List name must be between 1 and 100 characters."
	elsif session[:lists].any? { |list| list[:name] == name }
		"List name must be unique."
	end
end

def error_for_todo(name)
	if !(1..100).cover? name.size #.include? would check every single value in range
		"List name must be between 1 and 100 characters."
	end
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

	error = error_for_list_name(list_name) #removed this from if statement
	if error #more explicit and easier to read
		session[:error] = error
		erb :new_list, layout: :layout
	else
		session[:lists] << { name: list_name, todos: [] }
		session[:success] = "The list has been created."
		## i.e. if I redirected here, I would lose access to list_name var, or 
		## params[:list_name]		
		redirect "/lists"
	end
end

get "/lists/:id" do
	@list_id = params[:id].to_i
	@list = session[:lists][@list_id]
	erb :list
end

get "/lists/:id/edit" do
	id = params[:id].to_i
	@list = session[:lists][id]
	erb :edit_list, layout: :layout
end

#Update an existing todo list
post "/lists/:id" do
	list_name = params[:list_name].strip
	@list_id = params[:id].to_i
	@list = session[:lists][@list_id]

	error = error_for_list_name(list_name) #removed this from if statement
	if error #more explicit and easier to read

		session[:error] = error
		erb :edit_list, layout: :layout
	else
		@list[:name] = list_name
		session[:success] = "The list has been updated."
		## i.e. if I redirected here, I would lose access to list_name var, or 
		## params[:list_name]		
		redirect "/lists/#{id}"
	end
end

post "/lists/:id/delete" do
	id = params[:id].to_i
	session[:lists].delete_at(id)
	session[:success] = "The list has been deleted."
	redirect "/lists"
end

post "/lists/:list_id/todos" do
	@list_id = params[:list_id].to_i
	@list = session[:lists][@list_id]
	text = params[:todo].strip

	error = error_for_todo(text)
	if error
		session[:error] = error
		erb :list, layout: :layout
	else
		@list[:todos] << { name: text, completed: false }
		session[:success] = "The todo was added."
		redirect "/lists/#{@list_id}"
	end
end

#Delete a todo from a list
post "/lists/:list_id/todos/:id/delete" do
	@list_id = params[:list_id].to_i
	@list = session[:lists][@list_id]

	todo_id = params[:id].to_i
	@list[:todos].delete_at todo_id
	session[:success] = "The todo has been deleted."
	redirect "/lists/#{@list_id}"
end

#update status of a todo
post "/lists/:list_id/todos/:id" do
	@list_id = params[:list_id].to_i
	@list = session[:lists][@list_id]

	todo_id = params[:id].to_i
	is_completed = params[:completed] == "true"
	@list[:todos][todo_id][:completed] = is_completed

	session[:success] = "The todo has been updated."
	redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do
	@list_id = params[:id].to_i
	@list = session[:lists][@list_id]

	@list[:todos].each do |todo|
		todo[:completed] = true
	end

	session[:success] = "All todos have been completed."
	redirect "/lists/#{@list_id}"
end