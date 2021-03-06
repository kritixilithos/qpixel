class CategoriesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :homepage, :rss_feed]
  before_action :verify_admin, except: [:index, :show, :homepage, :rss_feed]
  before_action :set_category, except: [:index, :homepage, :new, :create]
  before_action :verify_view_access, except: [:index, :homepage, :new, :create]

  def index
    @categories = Category.all.order(:sequence, :name)
    respond_to do |format|
      format.html {}
      format.json do
        render json: @categories
      end
    end
  end

  def show
    update_last_visit(@category)
    set_list_posts
  end

  def homepage
    @category = Category.where(is_homepage: true).first
    update_last_visit(@category)
    set_list_posts
    render :show
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new category_params
    if @category.save
      if @category.is_homepage
        Category.where.not(id: @category.id).update_all(is_homepage: false)
      end
      flash[:success] = 'Your category was created.'
      Rails.cache.delete "#{RequestContext.community_id}/header_categories"
      redirect_to category_path(@category)
    else
      flash[:danger] = 'There were some errors while trying to save your category.'
      render :new
    end
  end

  def edit; end

  def update
    if @category.update category_params
      if @category.is_homepage
        Category.where.not(id: @category.id).update_all(is_homepage: false)
      end
      flash[:success] = 'Your category was updated.'
      Rails.cache.delete "#{RequestContext.community_id}/header_categories"
      redirect_to category_path(@category)
    else
      flash[:danger] = 'There were some errors while trying to save your category.'
      render :new
    end
  end

  def destroy
    unless @category.destroy
      flash[:danger] = "Couldn't delete that category."
    end
    redirect_back fallback_location: categories_path
  end

  def rss_feed
    set_list_posts
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :short_wiki, :tag_set_id, :is_homepage, :min_trust_level, :button_text,
                                     :color_code, :min_view_trust_level, :license_id, :sequence,
                                     display_post_types: [], post_type_ids: [], required_tag_ids: [],
                                     topic_tag_ids: [], moderator_tag_ids: [])
  end

  def verify_view_access
    unless (current_user&.trust_level || 0) >= (@category.min_view_trust_level || -1)
      not_found
    end
  end

  def set_list_posts
    sort_params = { activity: { last_activity: :desc }, age: { created_at: :desc }, score: { score: :desc },
                    lottery: [Arel.sql('(RAND() - ? * DATEDIFF(CURRENT_TIMESTAMP, posts.created_at)) DESC'),
                              SiteSetting['LotteryAgeDeprecationSpeed']],
                    native: Arel.sql('att_source IS NULL DESC, last_activity DESC') }
    sort_param = sort_params[params[:sort]&.to_sym] || { last_activity: :desc }
    @posts = @category.posts.undeleted.where(post_type_id: @category.display_post_types)
                      .includes(:post_type, :tags).list_includes.paginate(page: params[:page], per_page: 50)
                      .order(sort_param)
  end

  def update_last_visit(category)
    return unless current_user.present?

    key = "#{RequestContext.community_id}/#{current_user.id}/#{category.id}/last_visit"
    RequestContext.redis.set key, DateTime.now.to_s
    Rails.cache.delete key
  end
end
