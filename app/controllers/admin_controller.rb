# Web controller. Provides authenticated actions for use by administrators.
class AdminController < ApplicationController
  before_action :verify_admin
  before_action :verify_global_admin, only: [:admin_email, :send_admin_email]

  def index; end

  def error_reports
    @reports = if params[:uuid].present?
                 ErrorLog.where(uuid: params[:uuid])
               elsif current_user.is_global_admin
                 ErrorLog.all
               else
                 ErrorLog.where(community: RequestContext.community)
               end.order(created_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  def privileges
    @privileges = Privilege.all.user_sort({ term: params[:sort], default: :threshold },
                                          rep: :threshold, name: :name)
                           .paginate(page: params[:page], per_page: 20)
  end

  def show_privilege
    @privilege = Privilege.find_by name: params[:name]
    respond_to do |format|
      format.json { render json: @privilege }
    end
  end

  def update_privilege
    @privilege = Privilege.find_by name: params[:name]
    @privilege.update(threshold: params[:threshold])
    render json: { status: 'OK', privilege: @privilege }, status: 202
  end

  def admin_email; end

  def send_admin_email
    Thread.new do
      AdminMailer.with(body_markdown: params[:body_markdown], subject: params[:subject]).to_moderators.deliver_now
    end
    flash[:success] = 'Your email is being sent.'
    redirect_to admin_path
  end
end
