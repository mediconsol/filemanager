class ApplicationController < ActionController::Base
  # Temporarily disable browser restrictions for debugging
  # allow_browser versions: :modern

  # Temporarily disable all authentication for debugging
  # before_action :authenticate_user!, except: [:welcome]
  # before_action :configure_permitted_parameters, if: :devise_controller?

  # Temporarily disable authorization for debugging
  # include CanCan::ControllerAdditions
  # check_authorization unless: :devise_controller?, except: [:welcome]

  # Welcome page for testing
  def welcome
    render plain: "🏥 Hospital Management System is working!\n\nRails #{Rails.version}\nRuby #{RUBY_VERSION}\nEnvironment: #{Rails.env}\nTime: #{Time.current}"
  end

  # 권한 오류 처리
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden, content_type: 'text/html' }
      format.html { redirect_to main_app.root_url, alert: exception.message }
      format.js   { head :forbidden, content_type: 'text/html' }
    end
  end

  protected

  # Devise 파라미터 허용
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :hospital_id, :department, :position, :phone])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :department, :position, :phone, :avatar_url])
  end



  # 현재 사용자의 병원
  def current_hospital
    @current_hospital ||= current_user&.hospital
  end
  helper_method :current_hospital

  # 관리자 권한 체크
  def ensure_admin!
    redirect_to root_path, alert: '관리자 권한이 필요합니다.' unless current_user&.admin?
  end

  # 분석가 이상 권한 체크
  def ensure_analyst_or_admin!
    unless current_user&.admin? || current_user&.analyst?
      redirect_to root_path, alert: '분석가 이상의 권한이 필요합니다.'
    end
  end

  # 같은 병원 사용자인지 체크
  def ensure_same_hospital!(resource)
    unless resource.hospital_id == current_user.hospital_id
      redirect_to root_path, alert: '접근 권한이 없습니다.'
    end
  end
end
