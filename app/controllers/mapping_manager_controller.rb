class MappingManagerController < ApplicationController
  before_action :set_data_upload, only: [:show, :edit, :update, :save_mapping, :preview]
  load_and_authorize_resource :field_mapping, except: [:save_mapping, :preview]

  def index
    @data_uploads = current_hospital.data_uploads
                                   .includes(:user, :field_mappings)
                                   .where(status: ['completed', 'processing'])
                                   .order(created_at: :desc)
                                   .page(params[:page])
                                   .per(20)

    # 매핑 통계
    @mapping_stats = {
      total_uploads: @data_uploads.count,
      mapped_uploads: @data_uploads.joins(:field_mappings).distinct.count,
      total_mappings: current_hospital.field_mappings.active.count,
      pending_mappings: @data_uploads.left_joins(:field_mappings)
                                    .where(field_mappings: { id: nil })
                                    .count
    }
  end

  def show
    authorize! :read, FieldMapping

    @field_mappings = @data_upload.field_mappings.includes(:hospital)
    @source_fields = extract_source_fields(@data_upload)
    @target_fields = get_standard_fields(@data_upload.data_category)
    @existing_mappings = build_existing_mappings_hash(@field_mappings)
  end

  def edit
    authorize! :update, FieldMapping

    @field_mappings = @data_upload.field_mappings.includes(:hospital)
    @source_fields = extract_source_fields(@data_upload)
    @target_fields = get_standard_fields(@data_upload.data_category)
    @existing_mappings = build_existing_mappings_hash(@field_mappings)
  end

  def update
    authorize! :update, FieldMapping

    if params[:mappings].present?
      result = update_field_mappings(params[:mappings])

      if result[:success]
        redirect_to mapping_manager_path(@data_upload),
                    notice: "#{result[:updated]}개의 매핑이 업데이트되었습니다."
      else
        redirect_to edit_mapping_manager_path(@data_upload),
                    alert: "매핑 업데이트 중 오류가 발생했습니다: #{result[:error]}"
      end
    else
      redirect_to edit_mapping_manager_path(@data_upload),
                  alert: "매핑 데이터가 없습니다."
    end
  end

  def save_mapping
    authorize! :update, FieldMapping

    begin
      mapping_data = JSON.parse(request.body.read)
      result = save_field_mappings(mapping_data['mappings'])

      render json: {
        success: result[:success],
        message: result[:message],
        updated_count: result[:updated],
        created_count: result[:created]
      }
    rescue JSON::ParserError => e
      render json: { success: false, message: "잘못된 JSON 형식입니다." }, status: :bad_request
    rescue => e
      render json: { success: false, message: "매핑 저장 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  def preview
    authorize! :read, FieldMapping

    @preview_data = generate_mapping_preview(@data_upload)
    render json: @preview_data
  end

  private

  def set_data_upload
    @data_upload = current_hospital.data_uploads.find(params[:id])
  end

  def extract_source_fields(data_upload)
    return [] unless data_upload.original_data.present?

    headers = data_upload.original_data['headers'] || []
    headers.map.with_index do |header, index|
      {
        name: header,
        index: index,
        type: detect_field_type(data_upload, header),
        sample_values: get_sample_values(data_upload, header)
      }
    end
  end

  def detect_field_type(data_upload, field_name)
    return 'string' unless data_upload.original_data['preview_rows'].present?

    sample_values = data_upload.original_data['preview_rows']
                               .map { |row| row[field_name] }
                               .compact

    return 'string' if sample_values.empty?

    # 숫자 타입 감지
    if sample_values.all? { |v| v.to_s.match?(/^\d+$/) }
      return 'integer'
    elsif sample_values.all? { |v| v.to_s.match?(/^\d+\.?\d*$/) }
      return 'decimal'
    elsif sample_values.any? { |v| v.to_s.match?(/^\d{4}-\d{2}-\d{2}/) }
      return 'date'
    else
      return 'string'
    end
  end

  def get_sample_values(data_upload, field_name)
    return [] unless data_upload.original_data['preview_rows'].present?

    data_upload.original_data['preview_rows']
               .map { |row| row[field_name] }
               .compact
               .uniq
               .first(3)
  end

  def get_standard_fields(category)
    case category
    when 'financial'
      financial_standard_fields
    when 'operational'
      operational_standard_fields
    when 'quality'
      quality_standard_fields
    when 'patient'
      patient_standard_fields
    else
      common_standard_fields
    end
  end

  def financial_standard_fields
    [
      { name: 'revenue', label: '수익', type: 'decimal', required: true, description: '총 수익 금액' },
      { name: 'cost', label: '비용', type: 'decimal', required: true, description: '총 비용 금액' },
      { name: 'department', label: '부서', type: 'string', required: true, description: '부서명' },
      { name: 'date', label: '날짜', type: 'date', required: true, description: '거래 날짜' },
      { name: 'account_code', label: '계정코드', type: 'string', required: false, description: '회계 계정 코드' },
      { name: 'description', label: '설명', type: 'string', required: false, description: '거래 설명' },
      { name: 'budget', label: '예산', type: 'decimal', required: false, description: '예산 금액' },
      { name: 'variance', label: '차이', type: 'decimal', required: false, description: '예산 대비 차이' }
    ]
  end

  def operational_standard_fields
    [
      { name: 'bed_count', label: '병상수', type: 'integer', required: true, description: '총 병상 수' },
      { name: 'occupied_beds', label: '사용병상', type: 'integer', required: true, description: '사용 중인 병상 수' },
      { name: 'department', label: '부서', type: 'string', required: true, description: '부서명' },
      { name: 'date', label: '날짜', type: 'date', required: true, description: '기준 날짜' },
      { name: 'staff_count', label: '직원수', type: 'integer', required: false, description: '근무 직원 수' },
      { name: 'patient_count', label: '환자수', type: 'integer', required: false, description: '입원 환자 수' },
      { name: 'los_average', label: '평균재원일수', type: 'decimal', required: false, description: '평균 재원 일수' },
      { name: 'turnover_rate', label: '회전율', type: 'decimal', required: false, description: '병상 회전율' }
    ]
  end

  def quality_standard_fields
    [
      { name: 'patient_id', label: '환자ID', type: 'string', required: true, description: '환자 식별자' },
      { name: 'satisfaction_score', label: '만족도점수', type: 'decimal', required: true, description: '환자 만족도 점수' },
      { name: 'department', label: '부서', type: 'string', required: true, description: '진료과' },
      { name: 'date', label: '날짜', type: 'date', required: true, description: '평가 날짜' },
      { name: 'readmission', label: '재입원여부', type: 'boolean', required: false, description: '재입원 여부' },
      { name: 'complication', label: '합병증여부', type: 'boolean', required: false, description: '합병증 발생 여부' },
      { name: 'infection', label: '감염여부', type: 'boolean', required: false, description: '병원감염 여부' },
      { name: 'mortality', label: '사망여부', type: 'boolean', required: false, description: '사망 여부' }
    ]
  end

  def patient_standard_fields
    [
      { name: 'patient_id', label: '환자ID', type: 'string', required: true, description: '환자 식별자' },
      { name: 'age', label: '나이', type: 'integer', required: true, description: '환자 나이' },
      { name: 'gender', label: '성별', type: 'string', required: true, description: '환자 성별' },
      { name: 'admission_date', label: '입원일', type: 'date', required: true, description: '입원 날짜' },
      { name: 'discharge_date', label: '퇴원일', type: 'date', required: false, description: '퇴원 날짜' },
      { name: 'diagnosis', label: '진단명', type: 'string', required: false, description: '주 진단명' },
      { name: 'department', label: '진료과', type: 'string', required: false, description: '담당 진료과' },
      { name: 'doctor', label: '담당의', type: 'string', required: false, description: '담당 의사' }
    ]
  end

  def common_standard_fields
    [
      { name: 'id', label: 'ID', type: 'string', required: true, description: '고유 식별자' },
      { name: 'name', label: '이름', type: 'string', required: true, description: '이름' },
      { name: 'date', label: '날짜', type: 'date', required: true, description: '기준 날짜' },
      { name: 'value', label: '값', type: 'decimal', required: true, description: '수치 값' },
      { name: 'category', label: '카테고리', type: 'string', required: false, description: '분류' },
      { name: 'description', label: '설명', type: 'string', required: false, description: '설명' }
    ]
  end

  def build_existing_mappings_hash(field_mappings)
    field_mappings.each_with_object({}) do |mapping, hash|
      hash[mapping.source_field] = {
        target_field: mapping.target_field,
        mapping_type: mapping.mapping_type,
        transformation_rules: mapping.transformation_rules,
        is_required: mapping.is_required,
        is_active: mapping.is_active
      }
    end
  end

  def update_field_mappings(mappings_params)
    updated_count = 0
    created_count = 0

    ActiveRecord::Base.transaction do
      mappings_params.each do |source_field, mapping_data|
        next if mapping_data[:target_field].blank?

        mapping = @data_upload.field_mappings.find_or_initialize_by(
          source_field: source_field,
          hospital: current_hospital
        )

        mapping.assign_attributes(
          target_field: mapping_data[:target_field],
          mapping_type: mapping_data[:mapping_type] || 'direct',
          transformation_rules: mapping_data[:transformation_rules],
          is_required: mapping_data[:is_required] || false,
          is_active: mapping_data[:is_active] != false
        )

        if mapping.save
          mapping.persisted? ? updated_count += 1 : created_count += 1
        else
          raise "매핑 저장 실패: #{mapping.errors.full_messages.join(', ')}"
        end
      end
    end

    { success: true, updated: updated_count, created: created_count }
  rescue => e
    { success: false, error: e.message }
  end

  def save_field_mappings(mappings_data)
    updated_count = 0
    created_count = 0

    ActiveRecord::Base.transaction do
      # 기존 매핑 비활성화
      @data_upload.field_mappings.update_all(is_active: false)

      mappings_data.each do |mapping_data|
        next if mapping_data['target_field'].blank?

        mapping = @data_upload.field_mappings.find_or_initialize_by(
          source_field: mapping_data['source_field'],
          hospital: current_hospital
        )

        was_persisted = mapping.persisted?

        mapping.assign_attributes(
          target_field: mapping_data['target_field'],
          mapping_type: mapping_data['mapping_type'] || 'direct',
          data_type: mapping_data['data_type'] || 'string',
          transformation_rules: mapping_data['transformation_rules'],
          validation_rules: mapping_data['validation_rules'],
          is_required: mapping_data['is_required'] || false,
          is_active: true,
          description: mapping_data['description']
        )

        if mapping.save
          was_persisted ? updated_count += 1 : created_count += 1
        else
          raise "매핑 저장 실패: #{mapping.errors.full_messages.join(', ')}"
        end
      end
    end

    {
      success: true,
      message: "매핑이 성공적으로 저장되었습니다.",
      updated: updated_count,
      created: created_count
    }
  rescue => e
    { success: false, message: e.message }
  end

  def generate_mapping_preview(data_upload)
    mappings = data_upload.field_mappings.active
    preview_rows = data_upload.original_data['preview_rows'] || []

    mapped_data = preview_rows.first(5).map do |row|
      mapped_row = {}
      mappings.each do |mapping|
        source_value = row[mapping.source_field]
        mapped_row[mapping.target_field] = transform_value(source_value, mapping)
      end
      mapped_row
    end

    {
      headers: mappings.pluck(:target_field),
      rows: mapped_data,
      mapping_count: mappings.count
    }
  end

  def transform_value(value, mapping)
    return value if mapping.transformation_rules.blank?

    # 간단한 변환 규칙 적용
    rules = mapping.transformation_rules

    case mapping.mapping_type
    when 'calculated'
      # 계산 로직 (나중에 구현)
      value
    when 'lookup'
      # 룩업 테이블 (나중에 구현)
      value
    when 'conditional'
      # 조건부 변환 (나중에 구현)
      value
    else
      # 직접 매핑
      value
    end
  end
end
