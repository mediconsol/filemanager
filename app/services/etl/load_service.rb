class Etl::LoadService < Etl::BaseEtlService
  def execute
    log_info("Starting data loading for #{data_upload.file_name}")
    
    etl_job.start!
    
    begin
      staging_table_name = get_staging_table_name
      core_tables = determine_core_tables
      
      # Core 테이블들 생성
      core_tables.each { |table_name| create_core_table_if_not_exists(table_name) }
      
      # Staging 데이터를 Core 테이블로 로드
      load_staging_to_core(staging_table_name, core_tables)
      
      etl_job.complete!(etl_job.processing_stats)
      log_info("Data loading completed successfully")
      
    rescue => e
      handle_error(e, { stage: 'load', core_tables: core_tables })
    end
  end

  private

  def determine_core_tables
    case data_upload.data_category
    when 'financial'
      ['core_financial_data']
    when 'operational'
      ['core_operational_data']
    when 'quality'
      ['core_quality_data']
    when 'patient'
      ['core_patient_data']
    else
      ['core_general_data']
    end
  end

  def load_staging_to_core(staging_table_name, core_tables)
    connection = ActiveRecord::Base.connection
    
    # Staging 데이터 조회 (검증 오류가 없는 것만)
    staging_sql = "SELECT * FROM #{staging_table_name} WHERE etl_job_id = #{etl_job.id} AND (validation_errors IS NULL OR JSON_LENGTH(validation_errors) = 0) ORDER BY id"
    staging_records = connection.execute(staging_sql)
    
    total_rows = staging_records.count
    processed_rows = 0
    error_rows = 0
    
    log_info("Total staging records to load: #{total_rows}")
    
    # 각 Core 테이블로 데이터 로드
    core_tables.each do |core_table_name|
      load_to_core_table(staging_records, core_table_name)
    end
    
    # 통계 업데이트
    final_stats = {
      'total_rows' => total_rows,
      'processed_rows' => total_rows,
      'error_rows' => 0,
      'success_rate' => 100.0,
      'core_tables' => core_tables
    }
    
    update_progress(total_rows, total_rows, final_stats)
    
    log_info("Loading completed: #{total_rows} records loaded to #{core_tables.count} core tables")
  end

  def load_to_core_table(staging_records, core_table_name)
    connection = ActiveRecord::Base.connection
    mappings = get_field_mappings
    core_data = []
    
    staging_records.each do |staging_record|
      core_record = build_core_record(staging_record, mappings, core_table_name)
      core_data << core_record
      
      # 배치 처리 (1000행씩)
      if core_data.size >= 1000
        save_core_data_batch(core_table_name, core_data)
        core_data.clear
      end
    end
    
    # 남은 데이터 저장
    save_core_data_batch(core_table_name, core_data) if core_data.any?
    
    log_info("Loaded #{staging_records.count} records to #{core_table_name}")
  end

  def build_core_record(staging_record, mappings, core_table_name)
    record = {
      hospital_id: hospital.id,
      data_upload_id: data_upload.id,
      etl_job_id: etl_job.id,
      source_reference: staging_record['id'],
      data_category: data_upload.data_category,
      created_at: Time.current,
      updated_at: Time.current
    }
    
    # 매핑된 필드 추가
    mappings.each do |mapping|
      value = staging_record[mapping.target_field]
      record[mapping.target_field] = value
    end
    
    # 카테고리별 특별 처리
    case data_upload.data_category
    when 'financial'
      add_financial_fields(record, staging_record)
    when 'operational'
      add_operational_fields(record, staging_record)
    when 'quality'
      add_quality_fields(record, staging_record)
    when 'patient'
      add_patient_fields(record, staging_record)
    end
    
    record
  end

  def add_financial_fields(record, staging_record)
    # 재무 데이터 특별 필드
    record[:fiscal_year] = extract_fiscal_year(staging_record['date'])
    record[:fiscal_quarter] = extract_fiscal_quarter(staging_record['date'])
    record[:fiscal_month] = extract_fiscal_month(staging_record['date'])
    
    # 금액 정규화
    record[:revenue_normalized] = normalize_currency(staging_record['revenue'])
    record[:cost_normalized] = normalize_currency(staging_record['cost'])
  end

  def add_operational_fields(record, staging_record)
    # 운영 데이터 특별 필드
    record[:report_date] = staging_record['date']
    record[:report_year] = Date.parse(staging_record['date'].to_s).year rescue nil
    record[:report_month] = Date.parse(staging_record['date'].to_s).month rescue nil
    
    # 효율성 지표
    record[:efficiency_score] = calculate_efficiency_score(staging_record)
  end

  def add_quality_fields(record, staging_record)
    # 품질 데이터 특별 필드
    record[:assessment_date] = staging_record['date']
    record[:quality_tier] = determine_quality_tier(staging_record['satisfaction_score'])
    
    # 품질 점수 정규화 (0-100 스케일)
    record[:satisfaction_normalized] = normalize_satisfaction_score(staging_record['satisfaction_score'])
  end

  def add_patient_fields(record, staging_record)
    # 환자 데이터 특별 필드
    record[:admission_year] = Date.parse(staging_record['admission_date'].to_s).year rescue nil
    record[:admission_month] = Date.parse(staging_record['admission_date'].to_s).month rescue nil
    
    # 환자 분류
    record[:patient_category] = classify_patient(staging_record)
  end

  def save_core_data_batch(table_name, core_data)
    return if core_data.empty?
    
    connection = ActiveRecord::Base.connection
    
    columns = core_data.first.keys
    values = core_data.map do |record|
      columns.map do |column|
        value = record[column]
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
    
    sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES "
    sql += values.map { |row| "(#{row.join(', ')})" }.join(', ')
    
    connection.execute(sql)
    
    log_info("Saved batch of #{core_data.size} records to #{table_name}")
  end

  def create_core_table_if_not_exists(table_name)
    connection = ActiveRecord::Base.connection
    
    return if connection.table_exists?(table_name)
    
    connection.create_table table_name do |t|
      t.references :hospital, null: false, foreign_key: true
      t.references :data_upload, null: false, foreign_key: true
      t.references :etl_job, null: false, foreign_key: true
      t.integer :source_reference
      t.string :data_category
      
      # 공통 필드
      t.string :department
      t.date :date
      t.text :description
      
      case table_name
      when 'core_financial_data'
        add_financial_columns(t)
      when 'core_operational_data'
        add_operational_columns(t)
      when 'core_quality_data'
        add_quality_columns(t)
      when 'core_patient_data'
        add_patient_columns(t)
      else
        add_general_columns(t)
      end
      
      t.timestamps
    end
    
    # 인덱스 추가
    connection.add_index table_name, [:hospital_id, :data_category]
    connection.add_index table_name, :data_upload_id
    connection.add_index table_name, :etl_job_id
    connection.add_index table_name, :date if connection.column_exists?(table_name, :date)
    
    log_info("Created core table: #{table_name}")
  end

  def add_financial_columns(t)
    t.decimal :revenue, precision: 15, scale: 2
    t.decimal :cost, precision: 15, scale: 2
    t.decimal :profit, precision: 15, scale: 2
    t.decimal :budget, precision: 15, scale: 2
    t.decimal :profit_margin, precision: 5, scale: 2
    t.decimal :budget_variance, precision: 15, scale: 2
    t.decimal :budget_variance_percent, precision: 5, scale: 2
    t.string :account_code
    t.integer :fiscal_year
    t.integer :fiscal_quarter
    t.integer :fiscal_month
    t.decimal :revenue_normalized, precision: 15, scale: 2
    t.decimal :cost_normalized, precision: 15, scale: 2
  end

  def add_operational_columns(t)
    t.integer :bed_count
    t.integer :occupied_beds
    t.integer :staff_count
    t.integer :patient_count
    t.decimal :occupancy_rate, precision: 5, scale: 2
    t.decimal :staff_patient_ratio, precision: 5, scale: 2
    t.decimal :los_average, precision: 5, scale: 2
    t.decimal :turnover_rate, precision: 5, scale: 2
    t.date :report_date
    t.integer :report_year
    t.integer :report_month
    t.decimal :efficiency_score, precision: 5, scale: 2
  end

  def add_quality_columns(t)
    t.string :patient_id
    t.decimal :satisfaction_score, precision: 5, scale: 2
    t.string :satisfaction_grade
    t.boolean :readmission
    t.boolean :complication
    t.boolean :infection
    t.boolean :mortality
    t.date :assessment_date
    t.string :quality_tier
    t.decimal :satisfaction_normalized, precision: 5, scale: 2
  end

  def add_patient_columns(t)
    t.string :patient_id
    t.integer :age
    t.string :gender
    t.string :age_group
    t.date :admission_date
    t.date :discharge_date
    t.integer :length_of_stay
    t.string :diagnosis
    t.string :doctor
    t.integer :admission_year
    t.integer :admission_month
    t.string :patient_category
  end

  def add_general_columns(t)
    t.string :name
    t.string :category
    t.decimal :value, precision: 15, scale: 2
    t.json :metadata
  end

  # 헬퍼 메서드들
  def extract_fiscal_year(date_str)
    Date.parse(date_str.to_s).year rescue nil
  end

  def extract_fiscal_quarter(date_str)
    date = Date.parse(date_str.to_s) rescue nil
    return nil unless date
    ((date.month - 1) / 3) + 1
  end

  def extract_fiscal_month(date_str)
    Date.parse(date_str.to_s).month rescue nil
  end

  def normalize_currency(amount)
    amount.to_f.round(2)
  end

  def calculate_efficiency_score(record)
    # 간단한 효율성 점수 계산
    occupancy = record['occupancy_rate'].to_f
    ratio = record['staff_patient_ratio'].to_f
    
    return nil if occupancy.zero? && ratio.zero?
    
    # 가중 평균 (병상 가동률 70%, 직원 비율 30%)
    (occupancy * 0.7 + (ratio > 0 ? [100 / ratio, 100].min : 0) * 0.3).round(2)
  end

  def determine_quality_tier(score)
    score = score.to_f
    case score
    when 90..100 then 'Excellent'
    when 80..89 then 'Good'
    when 70..79 then 'Average'
    when 60..69 then 'Below Average'
    else 'Poor'
    end
  end

  def normalize_satisfaction_score(score)
    # 0-100 스케일로 정규화
    [score.to_f, 100].min.round(2)
  end

  def classify_patient(record)
    age = record['age'].to_i
    los = record['length_of_stay'].to_i
    
    if age < 18
      'Pediatric'
    elsif los > 30
      'Long-term'
    elsif los < 3
      'Short-term'
    else
      'Standard'
    end
  end
end
