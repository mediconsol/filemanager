class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:show, :edit, :update, :destroy]
  before_action :ensure_admin_access
  skip_authorization_check

  def index
    @categories = Category.ordered.includes(:standard_fields)
    @stats = {
      total_categories: @categories.count,
      active_categories: @categories.active.count,
      total_fields: StandardField.count,
      active_fields: StandardField.active.count
    }
  end

  def show
    @fields = @category.standard_fields.ordered
    @field_stats = {
      total: @fields.count,
      active: @fields.active.count,
      required: @fields.required.count
    }
  end

  def new
    @category = Category.new
    @category.sort_order = Category.maximum(:sort_order).to_i + 1
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: '카테고리가 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to category_path(@category), notice: '카테고리가 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.standard_fields.any?
      redirect_to categories_path, alert: '이 카테고리에 속한 필드가 있어 삭제할 수 없습니다.'
    else
      @category.destroy
      redirect_to categories_path, notice: '카테고리가 삭제되었습니다.'
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :label, :description, :is_active, :sort_order)
  end

  def ensure_admin_access
    redirect_to root_path, alert: '관리자만 접근할 수 있습니다.' unless current_user&.admin?
  end
end
