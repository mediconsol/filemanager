class Etl::ExtractService < Etl::BaseEtlService
  def execute
    log_info("Starting data extraction for #{data_upload.file_name}")
    
    etl_job.start!
    
    begin
      case data_upload.file_type
      when 'text/csv'
        extract_from_csv
      when /excel|spreadsheet/
        extract_from_excel
      else
        raise "Unsupported file type: #{data_upload.file_type}"
      end
      
      etl_job.complete!(etl_job.processing_stats)
      log_info("Data extraction completed successfully")
      
    rescue => e
      handle_error(e, { stage: 'extract', file_type: data_upload.file_type })
    end
  end

  private

  def extract_from_csv
    require 'csv'
    
    file_path = data_upload.file_path
    raise "File not found: #{file_path}" unless File.exist?(file_path)
    
    raw_data = []
    headers = nil
    total_rows = 0
    processed_rows = 0
    error_rows = 0
    
    # 먼저 총 행 수 계산
    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      total_rows += 1
    end
    
    log_info("Total rows to extract: #{total_rows}")
    
    # 실제 데이터 추출
    CSV.foreach(file_path, headers: true, encoding: 'UTF-8') do |row|
      begin
        headers ||= row.headers
        
        # 빈 행 스킵
        next if row.to_h.values.all?(&:blank?)
        
        raw_record = {
          hospital_id: hospital.id,
          data_upload_id: data_upload.id,
          etl_job_id: etl_job.id,
          row_number: processed_rows + 1,
          source_data: row.to_h,
          extracted_at: Time.current
        }
        
        raw_data << raw_record
        processed_rows += 1
        
        # 배치 처리 (1000행씩)
        if raw_data.size >= 1000
          save_raw_data_batch(raw_data)
          raw_data.clear
          update_progress(processed_rows, total_rows)
        end
        
      rescue => e
        error_rows += 1
        log_error("Error processing row #{processed_rows + 1}: #{e.message}")
        
        # 오류가 너무 많으면 중단
        if error_rows > total_rows * 0.1 # 10% 이상 오류
          raise "Too many errors during extraction (#{error_rows}/#{total_rows})"
        end
      end
    end
    
    # 남은 데이터 저장
    save_raw_data_batch(raw_data) if raw_data.any?
    
    # 최종 통계 업데이트
    final_stats = {
      'total_rows' => total_rows,
      'processed_rows' => processed_rows,
      'error_rows' => error_rows,
      'success_rate' => total_rows > 0 ? ((processed_rows.to_f / total_rows) * 100).round(2) : 0,
      'headers' => headers
    }
    
    update_progress(processed_rows, total_rows, final_stats)
    
    log_info("CSV extraction completed: #{processed_rows}/#{total_rows} rows processed")
  end

  def extract_from_excel
    require 'roo'
    
    file_path = data_upload.file_path
    raise "File not found: #{file_path}" unless File.exist?(file_path)
    
    spreadsheet = Roo::Spreadsheet.open(file_path)
    headers = spreadsheet.row(1)
    total_rows = spreadsheet.last_row - 1 # 헤더 제외
    processed_rows = 0
    error_rows = 0
    raw_data = []
    
    log_info("Total rows to extract: #{total_rows}")
    
    (2..spreadsheet.last_row).each do |row_num|
      begin
        row_values = spreadsheet.row(row_num)
        
        # 빈 행 스킵
        next if row_values.compact.empty?
        
        # 헤더와 값을 매핑
        row_hash = {}
        headers.each_with_index do |header, index|
          row_hash[header] = row_values[index]
        end
        
        raw_record = {
          hospital_id: hospital.id,
          data_upload_id: data_upload.id,
          etl_job_id: etl_job.id,
          row_number: processed_rows + 1,
          source_data: row_hash,
          extracted_at: Time.current
        }
        
        raw_data << raw_record
        processed_rows += 1
        
        # 배치 처리 (1000행씩)
        if raw_data.size >= 1000
          save_raw_data_batch(raw_data)
          raw_data.clear
          update_progress(processed_rows, total_rows)
        end
        
      rescue => e
        error_rows += 1
        log_error("Error processing row #{row_num}: #{e.message}")
        
        # 오류가 너무 많으면 중단
        if error_rows > total_rows * 0.1 # 10% 이상 오류
          raise "Too many errors during extraction (#{error_rows}/#{total_rows})"
        end
      end
    end
    
    # 남은 데이터 저장
    save_raw_data_batch(raw_data) if raw_data.any?
    
    # 최종 통계 업데이트
    final_stats = {
      'total_rows' => total_rows,
      'processed_rows' => processed_rows,
      'error_rows' => error_rows,
      'success_rate' => total_rows > 0 ? ((processed_rows.to_f / total_rows) * 100).round(2) : 0,
      'headers' => headers
    }
    
    update_progress(processed_rows, total_rows, final_stats)
    
    log_info("Excel extraction completed: #{processed_rows}/#{total_rows} rows processed")
  end

  def save_raw_data_batch(raw_data)
    return if raw_data.empty?
    
    table_name = get_raw_table_name
    create_raw_table_if_not_exists(table_name)
    
    # 배치 삽입
    connection = ActiveRecord::Base.connection
    
    columns = raw_data.first.keys
    values = raw_data.map do |record|
      columns.map do |column|
        value = record[column]
        case value
        when Hash, Array
          connection.quote(value.to_json)
        when Time, DateTime
          connection.quote(value.iso8601)
        else
          connection.quote(value)
        end
      end
    end
    
    sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES "
    sql += values.map { |row| "(#{row.join(', ')})" }.join(', ')
    
    connection.execute(sql)
    
    log_info("Saved batch of #{raw_data.size} records to #{table_name}")
  end

  def create_raw_table_if_not_exists(table_name)
    connection = ActiveRecord::Base.connection
    
    unless connection.table_exists?(table_name)
      connection.create_table table_name do |t|
        t.references :hospital, null: false, foreign_key: true
        t.references :data_upload, null: false, foreign_key: true
        t.references :etl_job, null: false, foreign_key: true
        t.integer :row_number
        t.json :source_data
        t.datetime :extracted_at
        t.timestamps
      end
      
      # 인덱스 추가
      connection.add_index table_name, [:hospital_id, :data_upload_id]
      connection.add_index table_name, :etl_job_id
      connection.add_index table_name, :row_number
      
      log_info("Created raw table: #{table_name}")
    end
  end

  def get_raw_table_name
    "raw_#{data_upload.data_category || 'general'}_#{hospital.id}"
  end
end
