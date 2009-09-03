class ItemsController < ApplicationController
  unloadable
  before_filter :authorize
  before_filter :find_project, :only => [:index, :create]
  before_filter :find_item, :only => [:edit, :update, :show, :delete]
  
  def index
    render :text => "We don't do no indexin' round this part of town."
  end
  
  def create
    item = Item.create(params, @project)
    render :partial => "item", :locals => { :item => item }
  end

  def update
    item = Item.update(params)
    render :partial => "item", :locals => { :item => item }
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  end
  
  def find_item
    @item = Item.find(params[:id])
  end  
end
