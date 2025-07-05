class StandardFieldsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_standard_field, only: [:show, :edit, :update, :destroy]
  before_action :ensure_admin_access
  skip_authorization_check

  def index
    @standard_fields = StandardField.ordered
    @fields_by_category = @standard_fields.group_by(&:category)

    # 동적 카테고리 + 기존 하드코딩된 카테고리
    @categories = {}
    Category.active.ordered.each { |cat| @categories[cat.name] = cat.label }

    # 기존 하드코딩된 카테고리들도 포함
    legacy_categories = {
      'financial' => '재무',
      'operational' => '운영',
      'quality' => '품질',
      'patient' => '환자',
      'custom' => '사용자정의'
    }
    legacy_categories.each { |key, value| @categories[key] ||= value }

    @stats = {
      total_fields: @standard_fields.count,
      active_fields: @standard_fields.active.count,
      required_fields: @standard_fields.required.count,
      categories_count: @fields_by_category.keys.count
    }
  end

  def show
  end

  def new
    @standard_field = StandardField.new
    @standard_field.sort_order = StandardField.maximum(:sort_order).to_i + 1
  end

  def create
    @standard_field = StandardField.new(standard_field_params)

    if @standard_field.save
      redirect_to standard_fields_path, notice: '표준 필드가 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @standard_field.update(standard_field_params)
      redirect_to standard_fields_path, notice: '표준 필드가 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @standard_field.destroy
    redirect_to standard_fields_path, notice: '표준 필드가 삭제되었습니다.'
  end

  private

  def set_standard_field
    @standard_field = StandardField.find(params[:id])
  end

  def standard_field_params
    params.require(:standard_field).permit(:name, :label, :description, :data_type, :category,
                                          :is_required, :is_active, :sort_order, :default_value,
                                          validation_rules: {})
  end

  def ensure_admin_access
    redirect_to root_path, alert: '관리자만 접근할 수 있습니다.' unless current_user&.admin?
  end
end
