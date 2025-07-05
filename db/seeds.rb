# 병원경영분석시스템 시드 데이터
# This file should ensure the existence of records required to run the application in every environment.

puts "Creating seed data for Hospital Management Analysis System..."

# 1. 기본 병원 생성
default_hospital = Hospital.find_or_create_by!(domain: 'default') do |hospital|
  hospital.name = '서울대학교병원'
  hospital.plan = 'enterprise'
  hospital.address = '서울특별시 종로구 대학로 101'
  hospital.phone = '02-2072-2114'
  hospital.email = 'admin@snuh.org'
  hospital.license_number = 'HOS-2024-001'
  hospital.is_active = true
  hospital.settings = {
    is_default: true,
    timezone: 'Asia/Seoul',
    currency: 'KRW',
    language: 'ko'
  }
end

# 2. 추가 병원들 생성
hospitals_data = [
  {
    name: '삼성서울병원',
    domain: 'samsung',
    plan: 'enterprise',
    address: '서울특별시 강남구 일원로 81',
    phone: '02-3410-2114',
    email: 'admin@smc.samsung.co.kr',
    license_number: 'HOS-2024-002'
  },
  {
    name: '아산병원',
    domain: 'asan',
    plan: 'pro',
    address: '서울특별시 송파구 올림픽로43길 88',
    phone: '02-3010-3114',
    email: 'admin@amc.seoul.kr',
    license_number: 'HOS-2024-003'
  },
  {
    name: '세브란스병원',
    domain: 'severance',
    plan: 'pro',
    address: '서울특별시 서대문구 연세로 50-1',
    phone: '02-2228-5800',
    email: 'admin@yuhs.ac',
    license_number: 'HOS-2024-004'
  }
]

hospitals_data.each do |hospital_data|
  Hospital.find_or_create_by!(domain: hospital_data[:domain]) do |hospital|
    hospital.assign_attributes(hospital_data)
    hospital.is_active = true
    hospital.settings = {
      timezone: 'Asia/Seoul',
      currency: 'KRW',
      language: 'ko'
    }
  end
end

puts "Created #{Hospital.count} hospitals"

# 3. 관리자 사용자 생성
admin_user = User.find_or_create_by!(email: 'admin@hospital.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.hospital = default_hospital
  user.name = '시스템 관리자'
  user.role = 'admin'
  user.department = 'IT'
  user.position = '시스템 관리자'
  user.phone = '02-1234-5678'
  user.is_active = true
end

# 4. 분석가 사용자 생성
analyst_user = User.find_or_create_by!(email: 'analyst@hospital.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.hospital = default_hospital
  user.name = '데이터 분석가'
  user.role = 'analyst'
  user.department = '경영기획팀'
  user.position = '선임연구원'
  user.phone = '02-1234-5679'
  user.is_active = true
end

# 5. 일반 사용자 생성
viewer_user = User.find_or_create_by!(email: 'viewer@hospital.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.hospital = default_hospital
  user.name = '일반 사용자'
  user.role = 'viewer'
  user.department = '진료과'
  user.position = '과장'
  user.phone = '02-1234-5680'
  user.is_active = true
end

puts "Created #{User.count} users"

# 6. 샘플 데이터 업로드 기록 생성
sample_uploads = [
  {
    file_name: 'financial_data_2024_q1.xlsx',
    file_size: 2_048_576,
    file_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    status: 'completed',
    data_category: 'financial',
    total_rows: 1500,
    processed_rows: 1485,
    error_rows: 15
  },
  {
    file_name: 'patient_data_2024_q1.csv',
    file_size: 5_242_880,
    file_type: 'text/csv',
    status: 'completed',
    data_category: 'patient',
    total_rows: 3200,
    processed_rows: 3200,
    error_rows: 0
  },
  {
    file_name: 'operational_metrics_2024.xlsx',
    file_size: 1_048_576,
    file_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    status: 'processing',
    data_category: 'operational',
    total_rows: 800,
    processed_rows: 650,
    error_rows: 5
  }
]

sample_uploads.each do |upload_data|
  DataUpload.find_or_create_by!(
    hospital: default_hospital,
    user: analyst_user,
    file_name: upload_data[:file_name]
  ) do |upload|
    upload.assign_attributes(upload_data.except(:file_name))
    upload.processing_started_at = 1.hour.ago if upload.status == 'processing'
    upload.processing_completed_at = 30.minutes.ago if upload.status == 'completed'
  end
end

puts "Created #{DataUpload.count} data uploads"

# 7. 샘플 분석 결과 생성
sample_analyses = [
  {
    analysis_type: 'financial',
    parameters: { period: '2024-Q1', department: 'all' },
    result_data: {
      total_revenue: 1_250_000_000,
      profit_margin: 15.2,
      cost_breakdown: {
        personnel: 60,
        equipment: 25,
        supplies: 15
      }
    },
    chart_config: {
      type: 'bar',
      data: {
        labels: ['인건비', '장비비', '소모품비'],
        datasets: [{
          data: [60, 25, 15],
          backgroundColor: ['#FF6384', '#36A2EB', '#FFCE56']
        }]
      }
    }
  },
  {
    analysis_type: 'operational',
    parameters: { period: '2024-Q1', metric: 'bed_occupancy' },
    result_data: {
      average_occupancy: 85.3,
      peak_occupancy: 95.2,
      low_occupancy: 72.1,
      trend: 'increasing'
    }
  },
  {
    analysis_type: 'quality',
    parameters: { period: '2024-Q1', indicator: 'patient_satisfaction' },
    result_data: {
      satisfaction_score: 92.5,
      response_rate: 78.3,
      improvement_areas: ['대기시간', '의료진 친절도']
    }
  }
]

sample_analyses.each do |analysis_data|
  AnalysisResult.find_or_create_by!(
    hospital: default_hospital,
    user: analyst_user,
    analysis_type: analysis_data[:analysis_type]
  ) do |analysis|
    analysis.assign_attributes(analysis_data.except(:analysis_type))
  end
end

puts "Created #{AnalysisResult.count} analysis results"

puts "Seed data creation completed successfully!"
puts ""
puts "Login credentials:"
puts "Admin: admin@hospital.com / password123"
puts "Analyst: analyst@hospital.com / password123"
puts "Viewer: viewer@hospital.com / password123"
