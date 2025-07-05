class Etl::TransformService < Etl::BaseEtlService
  def execute
    log_info("Starting data transformation for #{data_upload.file_name}")
    
    etl_job.start!
    
    begin
      mappings = get_field_mappings
      
      if mappings.empty?
        raise "No field mappings found for data upload #{data_upload.id}"
      end
      
      raw_table_name = get_raw_table_name
      staging_table_name = get_staging_table_name
      
      # Staging 테이블 생성
      create_staging_table_if_not_exists(staging_table_name, mappings)
      
      # Raw 데이터 변환
      transform_raw_data(raw_table_name, staging_table_name, mappings)
      
      etl_job.complete!(etl_job.processing_stats)
      log_info("Data transformation completed successfully")
      
    rescue => e
      handle_error(e, { stage: 'transform', mappings_count: mappings&.count })
    end
  end

  private

  def transform_raw_data(raw_table_name, staging_table_name, mappings)
    connection = ActiveRecord::Base.connection
    
    # Raw 데이터 조회
    raw_data_sql = "SELECT * FROM #{raw_table_name} WHERE etl_job_id = #{etl_job.id} ORDER BY row_number"
    raw_records = connection.execute(raw_data_sql)
    
    total_rows = raw_records.count
    processed_rows = 0
    error_rows = 0
    transformed_data = []
    
    log_info("Total raw records to transform: #{total_rows}")
    
    raw_records.each do |raw_record|
      begin
        source_data = JSON.parse(raw_record['source_data'])
        transformed_row = transform_row(source_data, mappings)
        validation_errors = validate_transformed_data(transformed_row, mappings)
        
        staging_record = {
          hospital_id: hospital.id,
          data_upload_id: data_upload.id,
          etl_job_id: etl_job.id,
          source_data: source_data,
          validation_errors: validation_errors,
          created_at: Time.current,
          updated_at: Time.current
        }
        
        # 변환된 필드 추가
        mappings.each do |mapping|
          staging_record[mapping.target_field] = transformed_row[mapping.target_field]
        end
        
        transformed_data << staging_record
        processed_rows += 1
        
        if validation_errors.any?
          error_rows += 1
          log_error("Validation errors for row #{raw_record['row_number']}: #{validation_errors.join(', ')}")
        end
        
        # 배치 처리 (500행씩)
        if transformed_data.size >= 500
          save_staging_data_batch(staging_table_name, transformed_data, mappings)
          transformed_data.clear
          update_progress(processed_rows, total_rows)
        end
        
      rescue => e
        error_rows += 1
        log_error("Error transforming row #{raw_record['row_number']}: #{e.message}")
        
        # 오류가 너무 많으면 중단
        if error_rows > total_rows * 0.2 # 20% 이상 오류
          raise "Too many errors during transformation (#{error_rows}/#{total_rows})"
        end
      end
    end
    
    # 남은 데이터 저장
    save_staging_data_batch(staging_table_name, transformed_data, mappings) if transformed_data.any?
    
    # 최종 통계 업데이트
    final_stats = {
      'total_rows' => total_rows,
      'processed_rows' => processed_rows,
      'error_rows' => error_rows,
      'valid_rows' => processed_rows - error_rows,
      'success_rate' => total_rows > 0 ? (((processed_rows - error_rows).to_f / total_rows) * 100).round(2) : 0,
      'mappings_applied' => mappings.count
    }
    
    update_progress(processed_rows, total_rows, final_stats)
    
    log_info("Transformation completed: #{processed_rows}/#{total_rows} rows processed, #{error_rows} errors")
  end

  def transform_row(source_data, mappings)
    transformed_row = {}
    
    mappings.each do |mapping|
      source_value = source_data[mapping.source_field]
      transformed_value = transform_value(source_value, mapping)
      transformed_row[mapping.target_field] = transformed_value
    end
    
    # 추가 계산 필드
    transformed_row = apply_calculated_fields(transformed_row, mappings)
    
    transformed_row
  end

  def apply_calculated_fields(transformed_row, mappings)
    # 카테고리별 특별한 계산 필드 적용
    case data_upload.data_category
    when 'financial'
      apply_financial_calculations(transformed_row)
    when 'operational'
      apply_operational_calculations(transformed_row)
    when 'quality'
      apply_quality_calculations(transformed_row)
    when 'patient'
      apply_patient_calculations(transformed_row)
    end
    
    transformed_row
  end

  def apply_financial_calculations(row)
    # 수익률 계산
    if row['revenue'].present? && row['cost'].present?
      revenue = row['revenue'].to_f
      cost = row['cost'].to_f
      row['profit'] = revenue - cost
      row['profit_margin'] = cost > 0 ? ((revenue - cost) / revenue * 100).round(2) : 0
    end
    
    # 예산 대비 실적
    if row['budget'].present? && row['revenue'].present?
      budget = row['budget'].to_f
      revenue = row['revenue'].to_f
      row['budget_variance'] = revenue - budget
      row['budget_variance_percent'] = budget > 0 ? ((revenue - budget) / budget * 100).round(2) : 0
    end
    
    row
  end

  def apply_operational_calculations(row)
    # 병상 가동률 계산
    if row['bed_count'].present? && row['occupied_beds'].present?
      total_beds = row['bed_count'].to_i
      occupied = row['occupied_beds'].to_i
      row['occupancy_rate'] = total_beds > 0 ? (occupied.to_f / total_beds * 100).round(2) : 0
    end
    
    # 직원 대 환자 비율
    if row['staff_count'].present? && row['patient_count'].present?
      staff = row['staff_count'].to_i
      patients = row['patient_count'].to_i
      row['staff_patient_ratio'] = staff > 0 ? (patients.to_f / staff).round(2) : 0
    end
    
    row
  end

  def apply_quality_calculations(row)
    # 만족도 등급
    if row['satisfaction_score'].present?
      score = row['satisfaction_score'].to_f
      row['satisfaction_grade'] = case score
                                  when 90..100 then 'A'
                                  when 80..89 then 'B'
                                  when 70..79 then 'C'
                                  when 60..69 then 'D'
                                  else 'F'
                                  end
    end
    
    row
  end

  def apply_patient_calculations(row)
    # 재원일수 계산
    if row['admission_date'].present? && row['discharge_date'].present?
      admission = Date.parse(row['admission_date'].to_s) rescue nil
      discharge = Date.parse(row['discharge_date'].to_s) rescue nil
      
      if admission && discharge
        row['length_of_stay'] = (discharge - admission).to_i
      end
    end
    
    # 나이 그룹
    if row['age'].present?
      age = row['age'].to_i
      row['age_group'] = case age
                         when 0..17 then '소아'
                         when 18..39 then '청년'
                         when 40..64 then '중년'
                         else '노년'
                         end
    end
    
    row
  end

  def save_staging_data_batch(table_name, staging_data, mappings)
    return if staging_data.empty?
    
    connection = ActiveRecord::Base.connection
    
    # 컬럼 목록 생성
    base_columns = %w[hospital_id data_upload_id etl_job_id source_data validation_errors created_at updated_at]
    mapping_columns = mappings.map(&:target_field)
    all_columns = base_columns + mapping_columns
    
    # 값 배열 생성
    values = staging_data.map do |record|
      all_columns.map do |column|
        value = record[column] || record[column.to_sym]
        case value
        when Hash, Array
          connection.quote(value.to_json)
        when Time, DateTime
          connection.quote(value.iso8601)
        when Date
          connection.quote(value.to_s)
        when TrueClass, FalseClass
          value
        when Numeric
          value
        else
          connection.quote(value.to_s)
        end
      end
    end
    
    # SQL 생성 및 실행
    sql = "INSERT INTO #{table_name} (#{all_columns.join(', ')}) VALUES "
    sql += values.map { |row| "(#{row.join(', ')})" }.join(', ')
    
    connection.execute(sql)
    
    log_info("Saved batch of #{staging_data.size} transformed records to #{table_name}")
  end

  def get_raw_table_name
    "raw_#{data_upload.data_category || 'general'}_#{hospital.id}"
  end
end
