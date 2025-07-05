class Etl::BaseEtlService
  attr_reader :etl_job, :data_upload, :hospital

  def initialize(etl_job)
    @etl_job = etl_job
    @data_upload = etl_job.data_upload
    @hospital = etl_job.hospital
  end

  def execute
    raise NotImplementedError, "Subclasses must implement execute method"
  end

  protected

  def log_info(message)
    Rails.logger.info("[ETL Job #{etl_job.id}] #{message}")
  end

  def log_error(message)
    Rails.logger.error("[ETL Job #{etl_job.id}] #{message}")
  end

  def update_progress(processed_rows, total_rows, additional_stats = {})
    stats = {
      'processed_rows' => processed_rows,
      'total_rows' => total_rows,
      'progress_percentage' => total_rows > 0 ? ((processed_rows.to_f / total_rows) * 100).round(1) : 0
    }.merge(additional_stats)

    etl_job.update!(processing_stats: stats)
  end

  def handle_error(error, context = {})
    error_details = {
      'error_class' => error.class.name,
      'error_message' => error.message,
      'backtrace' => error.backtrace&.first(10),
      'context' => context,
      'timestamp' => Time.current.iso8601
    }

    log_error("#{error.class.name}: #{error.message}")
    etl_job.fail!(error.message, error_details)
  end

  def get_field_mappings
    @field_mappings ||= data_upload.field_mappings.active.includes(:hospital)
  end

  def transform_value(source_value, mapping)
    return source_value if mapping.blank?

    case mapping.mapping_type
    when 'direct'
      transform_direct(source_value, mapping)
    when 'calculated'
      transform_calculated(source_value, mapping)
    when 'lookup'
      transform_lookup(source_value, mapping)
    when 'conditional'
      transform_conditional(source_value, mapping)
    else
      source_value
    end
  rescue => e
    log_error("Transform error for field #{mapping.target_field}: #{e.message}")
    source_value
  end

  def transform_direct(value, mapping)
    case mapping.data_type
    when 'integer'
      value.to_i
    when 'decimal'
      value.to_f
    when 'boolean'
      ['true', '1', 'yes', 'y', 't'].include?(value.to_s.downcase)
    when 'date'
      Date.parse(value.to_s) rescue nil
    when 'datetime'
      DateTime.parse(value.to_s) rescue nil
    else
      value.to_s
    end
  end

  def transform_calculated(value, mapping)
    # 간단한 계산 변환 (나중에 확장 가능)
    rules = mapping.transformation_rules || {}
    formula = rules['formula']
    
    return value unless formula.present?
    
    # 안전한 계산을 위한 기본 구현
    case formula
    when /multiply_by_(\d+\.?\d*)/
      multiplier = $1.to_f
      value.to_f * multiplier
    when /divide_by_(\d+\.?\d*)/
      divisor = $1.to_f
      divisor.zero? ? 0 : value.to_f / divisor
    when /add_(\d+\.?\d*)/
      addend = $1.to_f
      value.to_f + addend
    when /subtract_(\d+\.?\d*)/
      subtrahend = $1.to_f
      value.to_f - subtrahend
    else
      value
    end
  end

  def transform_lookup(value, mapping)
    # 룩업 테이블 변환 (나중에 구현)
    rules = mapping.transformation_rules || {}
    lookup_table = rules['lookup_table'] || {}
    
    lookup_table[value.to_s] || value
  end

  def transform_conditional(value, mapping)
    # 조건부 변환 (나중에 구현)
    rules = mapping.transformation_rules || {}
    conditions = rules['conditions'] || []
    
    conditions.each do |condition|
      if evaluate_condition(value, condition)
        return condition['result']
      end
    end
    
    value
  end

  def evaluate_condition(value, condition)
    operator = condition['operator']
    operand = condition['operand']
    
    case operator
    when 'equals'
      value.to_s == operand.to_s
    when 'contains'
      value.to_s.include?(operand.to_s)
    when 'starts_with'
      value.to_s.start_with?(operand.to_s)
    when 'ends_with'
      value.to_s.end_with?(operand.to_s)
    when 'greater_than'
      value.to_f > operand.to_f
    when 'less_than'
      value.to_f < operand.to_f
    else
      false
    end
  end

  def validate_transformed_data(transformed_row, mappings)
    errors = []
    
    mappings.each do |mapping|
      next unless mapping.is_required
      
      value = transformed_row[mapping.target_field]
      if value.blank?
        errors << "Required field '#{mapping.target_field}' is missing or empty"
      end
      
      # 데이터 타입 검증
      if value.present? && !valid_data_type?(value, mapping.data_type)
        errors << "Field '#{mapping.target_field}' has invalid data type. Expected: #{mapping.data_type}"
      end
    end
    
    errors
  end

  def valid_data_type?(value, expected_type)
    case expected_type
    when 'integer'
      value.to_s.match?(/^\d+$/)
    when 'decimal'
      value.to_s.match?(/^\d+\.?\d*$/)
    when 'boolean'
      ['true', 'false', '1', '0', 'yes', 'no', 'y', 'n', 't', 'f'].include?(value.to_s.downcase)
    when 'date'
      Date.parse(value.to_s) rescue false
    when 'datetime'
      DateTime.parse(value.to_s) rescue false
    else
      true # string은 항상 유효
    end
  end

  def create_staging_table_if_not_exists(table_name, mappings)
    # 동적으로 staging 테이블 생성 (간단한 구현)
    connection = ActiveRecord::Base.connection
    
    unless connection.table_exists?(table_name)
      connection.create_table table_name do |t|
        t.references :hospital, null: false, foreign_key: true
        t.references :data_upload, null: false, foreign_key: true
        t.references :etl_job, null: false, foreign_key: true
        
        mappings.each do |mapping|
          case mapping.data_type
          when 'integer'
            t.integer mapping.target_field
          when 'decimal'
            t.decimal mapping.target_field, precision: 15, scale: 2
          when 'boolean'
            t.boolean mapping.target_field
          when 'date'
            t.date mapping.target_field
          when 'datetime'
            t.datetime mapping.target_field
          else
            t.string mapping.target_field
          end
        end
        
        t.json :source_data
        t.json :validation_errors
        t.timestamps
      end
      
      log_info("Created staging table: #{table_name}")
    end
  end

  def get_staging_table_name
    "staging_#{data_upload.data_category || 'general'}_#{hospital.id}"
  end

  def get_core_table_name
    "core_#{data_upload.data_category || 'general'}"
  end
end
