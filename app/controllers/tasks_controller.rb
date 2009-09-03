class TasksController < ApplicationController
  unloadable
  before_filter :authorize
  before_filter :find_item, :only => [:index, :create ]
  before_filter :find_project, :only => [:index, :create]
  
  def index
    render :partial => "items/item", :collection => @item.children
  end
  
  private
  
  def find_project
    @project = if params[:project_id]
                 Project.find(params[:project_id])
               else
                 @item.issue.project_id
               end
  end
  
  def find_item
    @item = Item.find(params[:item_id])
  end  
end
