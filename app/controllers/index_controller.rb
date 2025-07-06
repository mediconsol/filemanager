class IndexController < ApplicationController
  # 메인 랜딩 페이지 - 로그인 없이도 접근 가능

  def show
    # 메인 랜딩 페이지
    # 로그인 상태에 관계없이 모든 사용자에게 표시
  end

  def index
    # index 액션도 추가
    render :show
  end
end
