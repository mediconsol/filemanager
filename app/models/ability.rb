# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    # 로그인하지 않은 사용자는 아무 권한이 없음
    return unless user.present? && user.is_active?

    # 모든 사용자가 할 수 있는 기본 권한
    can :read, :dashboard
    can :read, User, id: user.id  # 자신의 정보만 읽기 가능
    can :update, User, id: user.id  # 자신의 정보만 수정 가능

    # 같은 병원 내에서만 데이터 접근 가능
    hospital_condition = { hospital_id: user.hospital_id }

    case user.role
    when 'admin'
      # 관리자: 모든 권한
      can :manage, :all

    when 'analyst'
      # 분석가: 데이터 업로드, 분석, 리포트 생성 가능
      can :read, :all
      can :manage, DataUpload, hospital_condition
      can :manage, FieldMapping, hospital_condition
      can :manage, AnalysisResult, hospital_condition
      can :manage, ReportSchedule, hospital_condition
      can :read, EtlJob, hospital_condition

      # 같은 병원의 사용자 정보 읽기 가능
      can :read, User, hospital_condition
      can :read, Hospital, id: user.hospital_id

    when 'viewer'
      # 뷰어: 읽기 전용
      can :read, DataUpload, hospital_condition
      can :read, FieldMapping, hospital_condition
      can :read, AnalysisResult, hospital_condition
      can :read, ReportSchedule, hospital_condition
      can :read, EtlJob, hospital_condition
      can :read, Hospital, id: user.hospital_id

      # 자신이 생성한 분석 결과는 관리 가능
      can :manage, AnalysisResult, hospital_condition.merge(user_id: user.id)
    end

    # 비활성 사용자는 모든 권한 제거
    cannot :manage, :all unless user.is_active?
  end
end
