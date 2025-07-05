class DataUploadsController < ApplicationController
  before_action :set_data_upload, only: [:show, :edit, :update, :destroy, :process_data, :progress]
  load_and_authorize_resource except: [:process_data, :progress]

  def index
    @data_uploads = current_hospital.data_uploads
                                   .includes(:user)
                                   .order(created_at: :desc)
                                   .page(params[:page])
                                   .per(20)

    # 필터링
    @data_uploads = @data_uploads.where(status: params[:status]) if params[:status].present?
    @data_uploads = @data_uploads.where(data_category: params[:category]) if params[:category].present?

    # 통계
    @upload_stats = {
      total: current_hospital.data_uploads.count,
      pending: current_hospital.data_uploads.pending.count,
      processing: current_hospital.data_uploads.processing.count,
      completed: current_hospital.data_uploads.completed.count,
      failed: current_hospital.data_uploads.failed.count
    }
  end

  def new
    @data_upload = current_hospital.data_uploads.build
  end

  def create
    if params[:files].present?
      results = []

      params[:files].each do |file|
        upload = create_upload_from_file(file)
        results << upload if upload.persisted?
      end

      render json: {
        success: true,
        uploads: results.map { |u| upload_json(u) },
        message: "#{results.count}개 파일이 업로드되었습니다."
      }
    else
      @data_upload = current_hospital.data_uploads.build(data_upload_params)
      @data_upload.user = current_user

      if @data_upload.save
        redirect_to @data_upload, notice: '파일이 성공적으로 업로드되었습니다.'
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
    @processing_logs = @data_upload.validation_errors || []
  end

  def edit
  end

  def update
    if @data_upload.update(data_upload_params)
      redirect_to @data_upload, notice: '업로드 정보가 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @data_upload.destroy
    redirect_to data_uploads_path, notice: '업로드가 삭제되었습니다.'
  end

  def process_data
    authorize! :update, @data_upload

    if @data_upload.pending?
      # ProcessDataUploadJob.perform_later(@data_upload)  # 백그라운드 잡은 나중에 구현
      @data_upload.start_processing!
      render json: { success: true, message: '데이터 처리가 시작되었습니다.' }
    else
      render json: { success: false, message: '이미 처리된 파일입니다.' }
    end
  end

  def progress
    authorize! :read, @data_upload

    render json: {
      status: @data_upload.status,
      total_rows: @data_upload.total_rows,
      processed_rows: @data_upload.processed_rows,
      error_rows: @data_upload.error_rows,
      progress_percentage: calculate_progress(@data_upload)
    }
  end

  private

  def set_data_upload
    @data_upload = current_hospital.data_uploads.find(params[:id])
  end

  def data_upload_params
    return {} unless params[:data_upload].present?
    params.require(:data_upload).permit(:file_name, :data_category, :file)
  end

  def create_upload_from_file(file)
    upload = current_hospital.data_uploads.build(
      user: current_user,
      file_name: file.original_filename,
      file_size: file.size,
      file_type: file.content_type,
      data_category: detect_category(file.original_filename)
    )

    if upload.save
      # 파일 저장
      save_uploaded_file(upload, file)

      # 기본 검증
      validate_file_format(upload, file)

      upload
    else
      upload
    end
  end

  def save_uploaded_file(upload, file)
    upload_dir = Rails.root.join('storage', 'uploads', current_hospital.id.to_s)
    FileUtils.mkdir_p(upload_dir)

    file_path = upload_dir.join("#{upload.id}_#{upload.file_name}")
    File.open(file_path, 'wb') do |f|
      f.write(file.read)
    end

    upload.update(file_path: file_path.to_s)
  end

  def validate_file_format(upload, file)
    errors = []

    # 파일 크기 체크 (100MB 제한)
    if file.size > 100.megabytes
      errors << "파일 크기가 100MB를 초과합니다."
    end

    # 파일 형식 체크
    unless DataUpload::ALLOWED_FILE_TYPES.include?(file.content_type)
      errors << "지원하지 않는 파일 형식입니다. (CSV, Excel만 지원)"
    end

    # 파일 내용 미리보기
    begin
      preview_data = extract_file_preview(file)
      upload.update(
        original_data: preview_data,
        total_rows: preview_data[:row_count],
        validation_errors: errors
      )
    rescue => e
      errors << "파일을 읽을 수 없습니다: #{e.message}"
      upload.update(
        status: 'failed',
        error_message: errors.join(', '),
        validation_errors: errors
      )
    end
  end

  def extract_file_preview(file)
    file.rewind

    case file.content_type
    when 'text/csv'
      extract_csv_preview(file)
    when /excel|spreadsheet/
      extract_excel_preview(file)
    else
      { headers: [], preview_rows: [], row_count: 0 }
    end
  end

  def extract_csv_preview(file)
    require 'csv'

    rows = []
    CSV.foreach(file.path, headers: true, encoding: 'UTF-8') do |row|
      rows << row.to_h
      break if rows.count >= 5  # 미리보기는 5행만
    end

    total_rows = CSV.read(file.path, headers: true).count

    {
      headers: rows.first&.keys || [],
      preview_rows: rows,
      row_count: total_rows
    }
  end

  def extract_excel_preview(file)
    require 'roo'

    spreadsheet = Roo::Spreadsheet.open(file.path)
    headers = spreadsheet.row(1)

    preview_rows = []
    (2..6).each do |i|  # 2-6행 미리보기
      row = spreadsheet.row(i)
      break if row.compact.empty?

      row_hash = {}
      headers.each_with_index do |header, index|
        row_hash[header] = row[index]
      end
      preview_rows << row_hash
    end

    {
      headers: headers,
      preview_rows: preview_rows,
      row_count: spreadsheet.last_row - 1  # 헤더 제외
    }
  end

  def detect_category(filename)
    case filename.downcase
    when /financial|finance|revenue|cost|budget/
      'financial'
    when /patient|medical|clinical/
      'patient'
    when /operation|bed|staff|resource/
      'operational'
    when /quality|satisfaction|outcome/
      'quality'
    else
      nil
    end
  end

  def calculate_progress(upload)
    return 0 if upload.total_rows.nil? || upload.total_rows.zero?
    ((upload.processed_rows.to_f / upload.total_rows) * 100).round(1)
  end

  def upload_json(upload)
    {
      id: upload.id,
      file_name: upload.file_name,
      status: upload.status,
      file_size: upload.file_size_mb,
      data_category: upload.data_category,
      created_at: upload.created_at.strftime('%Y-%m-%d %H:%M'),
      errors: upload.validation_errors || []
    }
  end
end
