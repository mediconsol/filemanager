class AnalysisExplorerController < ApplicationController
  before_action :set_analysis_result, only: [:show, :edit, :update, :destroy, :duplicate]
  load_and_authorize_resource :analysis_result, except: [:create_analysis, :get_data, :save_analysis]

  def index
    authorize! :read, AnalysisResult

    @analysis_results = current_hospital.analysis_results
                                       .includes(:user)
                                       .order(created_at: :desc)
                                       .page(params[:page])
                                       .per(20)

    # 필터링
    @analysis_results = @analysis_results.by_type(params[:type]) if params[:type].present?
    @analysis_results = @analysis_results.by_user(params[:user_id]) if params[:user_id].present?

    # 분석 통계
    @analysis_stats = {
      total: current_hospital.analysis_results.count,
      financial: current_hospital.analysis_results.by_type('financial').count,
      operational: current_hospital.analysis_results.by_type('operational').count,
      quality: current_hospital.analysis_results.by_type('quality').count,
      patient: current_hospital.analysis_results.by_type('patient').count,
      custom: current_hospital.analysis_results.by_type('custom').count
    }

    # 사용 가능한 데이터 소스
    @data_sources = get_available_data_sources
  end

  def show
    authorize! :read, @analysis_result

    @chart_config = @analysis_result.chart_config || {}
    @result_data = @analysis_result.result_data || {}
    @parameters = @analysis_result.parameters || {}
  end

  def new
    authorize! :create, AnalysisResult

    @analysis_result = current_hospital.analysis_results.build
    @data_sources = get_available_data_sources
    @chart_types = get_chart_types
    @analysis_types = AnalysisResult::ANALYSIS_TYPES
  end

  def create
    authorize! :create, AnalysisResult

    @analysis_result = current_hospital.analysis_results.build(analysis_result_params)
    @analysis_result.user = current_user

    if @analysis_result.save
      redirect_to @analysis_result, notice: '분석이 생성되었습니다.'
    else
      @data_sources = get_available_data_sources
      @chart_types = get_chart_types
      @analysis_types = AnalysisResult::ANALYSIS_TYPES
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @analysis_result

    @data_sources = get_available_data_sources
    @chart_types = get_chart_types
    @analysis_types = AnalysisResult::ANALYSIS_TYPES
  end

  def update
    authorize! :update, @analysis_result

    if @analysis_result.update(analysis_result_params)
      redirect_to @analysis_result, notice: '분석이 수정되었습니다.'
    else
      @data_sources = get_available_data_sources
      @chart_types = get_chart_types
      @analysis_types = AnalysisResult::ANALYSIS_TYPES
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @analysis_result

    @analysis_result.destroy
    redirect_to analysis_explorer_index_path, notice: '분석이 삭제되었습니다.'
  end

  def create_analysis
    authorize! :create, AnalysisResult

    begin
      analysis_params = JSON.parse(request.body.read)

      # 분석 실행
      result = execute_analysis(analysis_params)

      render json: {
        success: true,
        data: result[:data],
        chart_config: result[:chart_config],
        summary: result[:summary]
      }

    rescue JSON::ParserError => e
      render json: { success: false, message: "잘못된 JSON 형식입니다." }, status: :bad_request
    rescue => e
      Rails.logger.error("Analysis execution error: #{e.message}")
      render json: { success: false, message: "분석 실행 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  def get_data
    authorize! :read, AnalysisResult

    begin
      data_source = params[:data_source]
      filters = params[:filters] || {}

      data = fetch_data_from_source(data_source, filters)

      render json: {
        success: true,
        data: data[:rows],
        columns: data[:columns],
        total_rows: data[:total_rows]
      }

    rescue => e
      Rails.logger.error("Data fetch error: #{e.message}")
      render json: { success: false, message: "데이터 조회 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  def save_analysis
    authorize! :create, AnalysisResult

    begin
      analysis_data = JSON.parse(request.body.read)

      analysis_result = current_hospital.analysis_results.create!(
        user: current_user,
        analysis_type: analysis_data['analysis_type'] || 'custom',
        parameters: analysis_data['parameters'] || {},
        result_data: analysis_data['result_data'] || {},
        chart_config: analysis_data['chart_config'] || {},
        description: analysis_data['description']
      )

      render json: {
        success: true,
        message: "분석이 저장되었습니다.",
        analysis_id: analysis_result.id
      }

    rescue JSON::ParserError => e
      render json: { success: false, message: "잘못된 JSON 형식입니다." }, status: :bad_request
    rescue => e
      Rails.logger.error("Analysis save error: #{e.message}")
      render json: { success: false, message: "분석 저장 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
    end
  end

  def duplicate
    authorize! :create, AnalysisResult

    new_analysis = @analysis_result.dup
    new_analysis.user = current_user
    new_analysis.description = "#{@analysis_result.description} (복사본)"
    new_analysis.created_at = Time.current

    if new_analysis.save
      redirect_to new_analysis, notice: '분석이 복사되었습니다.'
    else
      redirect_to @analysis_result, alert: '분석 복사 중 오류가 발생했습니다.'
    end
  end

  private

  def set_analysis_result
    @analysis_result = current_hospital.analysis_results.find(params[:id])
  end

  def analysis_result_params
    params.require(:analysis_result).permit(:analysis_type, :description, :parameters, :result_data, :chart_config)
  end

  def get_available_data_sources
    sources = []

    # Core 테이블들 확인
    connection = ActiveRecord::Base.connection

    %w[financial operational quality patient general].each do |category|
      table_name = "core_#{category}_data"
      if connection.table_exists?(table_name)
        sources << {
          name: table_name,
          label: "#{category.humanize} 데이터",
          category: category,
          table_name: table_name
        }
      end
    end

    sources
  end

  def get_chart_types
    [
      { value: 'line', label: '선 차트', icon: 'fas fa-chart-line' },
      { value: 'bar', label: '막대 차트', icon: 'fas fa-chart-bar' },
      { value: 'column', label: '세로 막대 차트', icon: 'fas fa-chart-column' },
      { value: 'pie', label: '파이 차트', icon: 'fas fa-chart-pie' },
      { value: 'area', label: '영역 차트', icon: 'fas fa-chart-area' },
      { value: 'scatter', label: '산점도', icon: 'fas fa-braille' },
      { value: 'table', label: '테이블', icon: 'fas fa-table' }
    ]
  end

  def execute_analysis(params)
    data_source = params['data_source']
    chart_type = params['chart_type']
    filters = params['filters'] || {}
    group_by = params['group_by']
    aggregate = params['aggregate'] || {}

    # 데이터 조회
    data = fetch_data_from_source(data_source, filters)

    # 그룹화 및 집계
    if group_by.present?
      data = group_and_aggregate_data(data, group_by, aggregate)
    end

    # 차트 설정 생성
    chart_config = generate_chart_config(chart_type, data, params)

    # 요약 통계
    summary = generate_summary(data)

    {
      data: data,
      chart_config: chart_config,
      summary: summary
    }
  end

  def fetch_data_from_source(data_source, filters = {})
    connection = ActiveRecord::Base.connection

    # 기본 쿼리
    sql = "SELECT * FROM #{data_source} WHERE hospital_id = #{current_hospital.id}"

    # 필터 적용
    filters.each do |column, filter_config|
      next unless filter_config.present?

      case filter_config['type']
      when 'date_range'
        if filter_config['start_date'].present? && filter_config['end_date'].present?
          sql += " AND #{column} BETWEEN '#{filter_config['start_date']}' AND '#{filter_config['end_date']}'"
        end
      when 'number_range'
        if filter_config['min'].present?
          sql += " AND #{column} >= #{filter_config['min']}"
        end
        if filter_config['max'].present?
          sql += " AND #{column} <= #{filter_config['max']}"
        end
      when 'text'
        if filter_config['value'].present?
          sql += " AND #{column} ILIKE '%#{filter_config['value']}%'"
        end
      when 'select'
        if filter_config['values'].present? && filter_config['values'].any?
          values = filter_config['values'].map { |v| "'#{v}'" }.join(',')
          sql += " AND #{column} IN (#{values})"
        end
      end
    end

    sql += " ORDER BY created_at DESC LIMIT 1000"

    # 쿼리 실행
    result = connection.execute(sql)

    # 컬럼 정보 추출
    columns = result.fields.map do |field|
      {
        name: field,
        type: detect_column_type(data_source, field)
      }
    end

    # 데이터 변환
    rows = result.map do |row|
      row_hash = {}
      result.fields.each_with_index do |field, index|
        row_hash[field] = row[index]
      end
      row_hash
    end

    {
      rows: rows,
      columns: columns,
      total_rows: rows.count
    }
  end

  def group_and_aggregate_data(data, group_by, aggregate)
    grouped_data = data[:rows].group_by { |row| row[group_by] }

    result_rows = grouped_data.map do |group_value, rows|
      result_row = { group_by => group_value }

      aggregate.each do |column, function|
        values = rows.map { |row| row[column] }.compact.map(&:to_f)

        case function
        when 'sum'
          result_row["#{column}_sum"] = values.sum
        when 'avg'
          result_row["#{column}_avg"] = values.empty? ? 0 : (values.sum / values.count).round(2)
        when 'count'
          result_row["#{column}_count"] = values.count
        when 'min'
          result_row["#{column}_min"] = values.min || 0
        when 'max'
          result_row["#{column}_max"] = values.max || 0
        end
      end

      result_row
    end

    {
      rows: result_rows,
      columns: data[:columns],
      total_rows: result_rows.count
    }
  end

  def generate_chart_config(chart_type, data, params)
    case chart_type
    when 'line', 'bar', 'column', 'area'
      generate_xy_chart_config(chart_type, data, params)
    when 'pie'
      generate_pie_chart_config(data, params)
    when 'scatter'
      generate_scatter_chart_config(data, params)
    when 'table'
      generate_table_config(data, params)
    else
      {}
    end
  end

  def generate_xy_chart_config(chart_type, data, params)
    x_axis = params['x_axis']
    y_axis = params['y_axis']

    chart_data = data[:rows].map do |row|
      [row[x_axis], row[y_axis]]
    end

    {
      type: chart_type,
      data: chart_data,
      options: {
        title: params['title'] || "#{y_axis} by #{x_axis}",
        x_axis_title: x_axis,
        y_axis_title: y_axis,
        responsive: true
      }
    }
  end

  def generate_pie_chart_config(data, params)
    label_column = params['label_column']
    value_column = params['value_column']

    chart_data = data[:rows].map do |row|
      [row[label_column], row[value_column]]
    end

    {
      type: 'pie',
      data: chart_data,
      options: {
        title: params['title'] || "#{value_column} by #{label_column}",
        responsive: true
      }
    }
  end

  def generate_scatter_chart_config(data, params)
    x_axis = params['x_axis']
    y_axis = params['y_axis']

    chart_data = data[:rows].map do |row|
      [row[x_axis], row[y_axis]]
    end

    {
      type: 'scatter',
      data: chart_data,
      options: {
        title: params['title'] || "#{y_axis} vs #{x_axis}",
        x_axis_title: x_axis,
        y_axis_title: y_axis,
        responsive: true
      }
    }
  end

  def generate_table_config(data, params)
    {
      type: 'table',
      data: data[:rows],
      columns: data[:columns],
      options: {
        title: params['title'] || "데이터 테이블",
        responsive: true,
        pagination: true
      }
    }
  end

  def generate_summary(data)
    total_rows = data[:rows].count

    numeric_columns = data[:columns].select { |col| %w[integer decimal].include?(col[:type]) }

    summary = {
      total_rows: total_rows,
      numeric_summaries: {}
    }

    numeric_columns.each do |column|
      column_name = column[:name]
      values = data[:rows].map { |row| row[column_name] }.compact.map(&:to_f)

      if values.any?
        summary[:numeric_summaries][column_name] = {
          sum: values.sum.round(2),
          avg: (values.sum / values.count).round(2),
          min: values.min,
          max: values.max,
          count: values.count
        }
      end
    end

    summary
  end

  def detect_column_type(table_name, column_name)
    connection = ActiveRecord::Base.connection
    column = connection.columns(table_name).find { |col| col.name == column_name }

    return 'string' unless column

    case column.type
    when :integer
      'integer'
    when :decimal, :float
      'decimal'
    when :boolean
      'boolean'
    when :date
      'date'
    when :datetime, :timestamp
      'datetime'
    else
      'string'
    end
  end
end
