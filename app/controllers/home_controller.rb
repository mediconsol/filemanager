class HomeController < ApplicationController
  # 로그인 전후 모두 접근 가능한 홈페이지
  skip_before_action :authenticate_user!, only: [:index]

  def index
    # 완전히 단순화된 홈페이지
    render plain: "🏥 Hospital Management System\n\n" +
                  (user_signed_in? ? "환영합니다, #{current_user.email}님!" : "로그인이 필요합니다.") +
                  "\n\nTime: #{Time.current}"
  end
end
