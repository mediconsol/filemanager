class Report::GeneratorService
  attr_reader :report_schedule, :hospital

  def initialize(report_schedule)
    @report_schedule = report_schedule
    @hospital = report_schedule.hospital
  end

  def generate
    Rails.logger.info("[Report Generator] Starting report generation for #{report_schedule.name}")
    
    begin
      # 리포트 데이터 수집
      report_data = collect_report_data
      
      # 리포트 생성
      file_path = case report_schedule.format
                  when 'pdf'
                    generate_pdf_report(report_data)
                  when 'excel'
                    generate_excel_report(report_data)
                  when 'html'
                    generate_html_report(report_data)
                  else
                    raise "Unsupported format: #{report_schedule.format}"
                  end
      
      Rails.logger.info("[Report Generator] Report generated successfully: #{file_path}")
      
      {
        success: true,
        file_path: file_path,
        file_size: File.size(file_path)
      }
      
    rescue => e
      Rails.logger.error("[Report Generator] Report generation failed: #{e.message}")
      
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def collect_report_data
    template_id = report_schedule.report_config_value('template_id', 'dashboard_summary')
    
    case template_id
    when 'dashboard_summary'
      collect_dashboard_data
    when 'financial_report'
      collect_financial_data
    when 'operational_report'
      collect_operational_data
    when 'quality_report'
      collect_quality_data
    when 'custom_report'
      collect_custom_data
    else
      collect_dashboard_data
    end
  end

  def collect_dashboard_data
    {
      title: "#{hospital.name} 대시보드 요약",
      generated_at: Time.current,
      period: get_report_period,
      kpi_summary: collect_kpi_data,
      trend_charts: collect_trend_data,
      department_performance: collect_department_data
    }
  end

  def collect_financial_data
    {
      title: "#{hospital.name} 재무 리포트",
      generated_at: Time.current,
      period: get_report_period,
      revenue_analysis: collect_revenue_data,
      cost_analysis: collect_cost_data,
      budget_variance: collect_budget_data
    }
  end

  def collect_operational_data
    {
      title: "#{hospital.name} 운영 리포트",
      generated_at: Time.current,
      period: get_report_period,
      bed_occupancy: collect_bed_data,
      staff_efficiency: collect_staff_data,
      patient_flow: collect_patient_flow_data
    }
  end

  def collect_quality_data
    {
      title: "#{hospital.name} 품질 리포트",
      generated_at: Time.current,
      period: get_report_period,
      patient_satisfaction: collect_satisfaction_data,
      quality_indicators: collect_quality_indicators,
      outcome_metrics: collect_outcome_data
    }
  end

  def collect_custom_data
    selected_analyses = report_schedule.report_config_value('selected_analyses', [])
    
    analyses_data = hospital.analysis_results
                           .where(id: selected_analyses)
                           .includes(:user)
                           .map do |analysis|
      {
        id: analysis.id,
        name: analysis.description.presence || "분석 ##{analysis.id}",
        type: analysis.analysis_type,
        result_data: analysis.result_data,
        chart_config: analysis.chart_config,
        created_at: analysis.created_at,
        user: analysis.user.name
      }
    end
    
    {
      title: "#{hospital.name} 사용자 정의 리포트",
      generated_at: Time.current,
      period: get_report_period,
      selected_analyses: analyses_data
    }
  end

  def collect_kpi_data
    # 실제 구현에서는 데이터베이스에서 조회
    {
      total_revenue: calculate_total_revenue,
      total_patients: calculate_total_patients,
      bed_occupancy_rate: calculate_bed_occupancy,
      staff_efficiency: calculate_staff_efficiency
    }
  end

  def collect_trend_data
    # 최근 12개월 트렌드 데이터
    months = 12.times.map { |i| i.months.ago.beginning_of_month }
    
    {
      revenue_trend: months.map { |month| [month.strftime('%Y-%m'), rand(100_000_000..150_000_000)] },
      patient_trend: months.map { |month| [month.strftime('%Y-%m'), rand(800..1200)] },
      occupancy_trend: months.map { |month| [month.strftime('%Y-%m'), rand(75..95)] }
    }
  end

  def collect_department_data
    # 부서별 성과 데이터
    departments = ['내과', '외과', '소아과', '산부인과', '응급의학과']
    
    departments.map do |dept|
      {
        name: dept,
        revenue: rand(50_000_000..100_000_000),
        patients: rand(200..500),
        satisfaction: rand(85..98),
        efficiency: rand(80..95)
      }
    end
  end

  def collect_revenue_data
    {
      total_revenue: calculate_total_revenue,
      revenue_by_department: collect_department_revenue,
      revenue_growth: calculate_revenue_growth
    }
  end

  def collect_cost_data
    {
      total_cost: calculate_total_cost,
      cost_breakdown: {
        personnel: rand(60..70),
        equipment: rand(20..30),
        supplies: rand(10..20)
      },
      cost_trend: collect_trend_data[:revenue_trend].map { |month, _| [month, rand(80_000_000..120_000_000)] }
    }
  end

  def collect_budget_data
    {
      budget_vs_actual: {
        budget: rand(1_000_000_000..1_500_000_000),
        actual: calculate_total_revenue,
        variance: rand(-10..15)
      }
    }
  end

  def collect_bed_data
    {
      total_beds: rand(200..300),
      occupied_beds: rand(150..250),
      occupancy_rate: calculate_bed_occupancy,
      occupancy_trend: collect_trend_data[:occupancy_trend]
    }
  end

  def collect_staff_data
    {
      total_staff: rand(300..500),
      staff_patient_ratio: rand(1.5..2.5),
      efficiency_score: calculate_staff_efficiency
    }
  end

  def collect_patient_flow_data
    {
      admissions: rand(800..1200),
      discharges: rand(750..1150),
      average_los: rand(3.5..7.2),
      emergency_visits: rand(1500..2500)
    }
  end

  def collect_satisfaction_data
    {
      overall_satisfaction: rand(85..98),
      satisfaction_by_department: collect_department_data.map { |dept| [dept[:name], dept[:satisfaction]] },
      satisfaction_trend: collect_trend_data[:occupancy_trend].map { |month, _| [month, rand(85..98)] }
    }
  end

  def collect_quality_indicators
    {
      readmission_rate: rand(5..15),
      infection_rate: rand(1..5),
      mortality_rate: rand(1..3),
      complication_rate: rand(2..8)
    }
  end

  def collect_outcome_data
    {
      patient_outcomes: {
        excellent: rand(60..80),
        good: rand(15..25),
        fair: rand(5..15),
        poor: rand(0..5)
      }
    }
  end

  def get_report_period
    case report_schedule.frequency
    when 'daily'
      Date.current.strftime('%Y년 %m월 %d일')
    when 'weekly'
      start_date = Date.current.beginning_of_week
      end_date = Date.current.end_of_week
      "#{start_date.strftime('%Y년 %m월 %d일')} ~ #{end_date.strftime('%m월 %d일')}"
    when 'monthly'
      Date.current.strftime('%Y년 %m월')
    when 'quarterly'
      quarter = (Date.current.month - 1) / 3 + 1
      "#{Date.current.year}년 #{quarter}분기"
    when 'yearly'
      Date.current.strftime('%Y년')
    else
      Date.current.strftime('%Y년 %m월 %d일')
    end
  end

  def calculate_total_revenue
    # 실제 구현에서는 데이터베이스 쿼리
    rand(1_000_000_000..1_500_000_000)
  end

  def calculate_total_patients
    rand(800..1200)
  end

  def calculate_bed_occupancy
    rand(75..95)
  end

  def calculate_staff_efficiency
    rand(80..95)
  end

  def calculate_total_cost
    rand(800_000_000..1_200_000_000)
  end

  def calculate_revenue_growth
    rand(-5..15)
  end

  def collect_department_revenue
    collect_department_data.map { |dept| [dept[:name], dept[:revenue]] }
  end

  def generate_pdf_report(data)
    # PDF 생성 (실제로는 Prawn gem 등 사용)
    file_path = generate_file_path('pdf')
    
    # 간단한 텍스트 파일로 대체 (실제로는 PDF 생성)
    File.open(file_path, 'w') do |file|
      file.write("PDF Report: #{data[:title]}\n")
      file.write("Generated at: #{data[:generated_at]}\n")
      file.write("Period: #{data[:period]}\n\n")
      file.write("Report data would be formatted as PDF here.\n")
    end
    
    file_path
  end

  def generate_excel_report(data)
    # Excel 생성 (실제로는 Axlsx gem 등 사용)
    file_path = generate_file_path('xlsx')
    
    # 간단한 텍스트 파일로 대체 (실제로는 Excel 생성)
    File.open(file_path, 'w') do |file|
      file.write("Excel Report: #{data[:title]}\n")
      file.write("Generated at: #{data[:generated_at]}\n")
      file.write("Period: #{data[:period]}\n\n")
      file.write("Report data would be formatted as Excel here.\n")
    end
    
    file_path
  end

  def generate_html_report(data)
    file_path = generate_file_path('html')
    
    html_content = generate_html_content(data)
    
    File.open(file_path, 'w') do |file|
      file.write(html_content)
    end
    
    file_path
  end

  def generate_html_content(data)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>#{data[:title]}</title>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .header { border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
          .section { margin-bottom: 30px; }
          .kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; }
          .kpi-card { border: 1px solid #ddd; padding: 20px; border-radius: 5px; text-align: center; }
          table { width: 100%; border-collapse: collapse; margin-top: 10px; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>#{data[:title]}</h1>
          <p>생성일시: #{data[:generated_at].strftime('%Y년 %m월 %d일 %H:%M')}</p>
          <p>기간: #{data[:period]}</p>
        </div>
        
        #{generate_html_sections(data)}
      </body>
      </html>
    HTML
  end

  def generate_html_sections(data)
    sections = []
    
    if data[:kpi_summary]
      sections << generate_kpi_section(data[:kpi_summary])
    end
    
    if data[:department_performance]
      sections << generate_department_section(data[:department_performance])
    end
    
    if data[:selected_analyses]
      sections << generate_analyses_section(data[:selected_analyses])
    end
    
    sections.join("\n")
  end

  def generate_kpi_section(kpi_data)
    <<~HTML
      <div class="section">
        <h2>주요 성과 지표 (KPI)</h2>
        <div class="kpi-grid">
          <div class="kpi-card">
            <h3>총 수익</h3>
            <p>#{number_with_delimiter(kpi_data[:total_revenue])}원</p>
          </div>
          <div class="kpi-card">
            <h3>총 환자수</h3>
            <p>#{number_with_delimiter(kpi_data[:total_patients])}명</p>
          </div>
          <div class="kpi-card">
            <h3>병상 가동률</h3>
            <p>#{kpi_data[:bed_occupancy_rate]}%</p>
          </div>
          <div class="kpi-card">
            <h3>직원 효율성</h3>
            <p>#{kpi_data[:staff_efficiency]}%</p>
          </div>
        </div>
      </div>
    HTML
  end

  def generate_department_section(dept_data)
    rows = dept_data.map do |dept|
      "<tr>
        <td>#{dept[:name]}</td>
        <td>#{number_with_delimiter(dept[:revenue])}원</td>
        <td>#{number_with_delimiter(dept[:patients])}명</td>
        <td>#{dept[:satisfaction]}%</td>
        <td>#{dept[:efficiency]}%</td>
      </tr>"
    end.join
    
    <<~HTML
      <div class="section">
        <h2>부서별 성과</h2>
        <table>
          <thead>
            <tr>
              <th>부서</th>
              <th>수익</th>
              <th>환자수</th>
              <th>만족도</th>
              <th>효율성</th>
            </tr>
          </thead>
          <tbody>
            #{rows}
          </tbody>
        </table>
      </div>
    HTML
  end

  def generate_analyses_section(analyses_data)
    analyses_html = analyses_data.map do |analysis|
      "<div style='border: 1px solid #ddd; padding: 15px; margin-bottom: 15px; border-radius: 5px;'>
        <h4>#{analysis[:name]}</h4>
        <p><strong>유형:</strong> #{analysis[:type].humanize}</p>
        <p><strong>생성자:</strong> #{analysis[:user]}</p>
        <p><strong>생성일:</strong> #{analysis[:created_at].strftime('%Y-%m-%d %H:%M')}</p>
        <p>분석 결과 데이터가 여기에 표시됩니다.</p>
      </div>"
    end.join
    
    <<~HTML
      <div class="section">
        <h2>선택된 분석 결과</h2>
        #{analyses_html}
      </div>
    HTML
  end

  def generate_file_path(extension)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "#{report_schedule.name.parameterize}_#{timestamp}.#{extension}"
    
    reports_dir = Rails.root.join('storage', 'reports', hospital.id.to_s)
    FileUtils.mkdir_p(reports_dir)
    
    reports_dir.join(filename).to_s
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
