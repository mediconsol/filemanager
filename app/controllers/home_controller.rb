class HomeController < ApplicationController
  # 로그인 전후 모두 접근 가능한 홈페이지
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # 로그인 상태에 따라 다른 내용 표시
    # 뷰에서 user_signed_in? 헬퍼로 분기 처리
  end
end
