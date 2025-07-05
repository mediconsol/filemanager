# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_05_075056) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_results", force: :cascade do |t|
    t.bigint "hospital_id", null: false
    t.bigint "user_id", null: false
    t.string "analysis_type"
    t.text "parameters"
    t.text "result_data"
    t.text "chart_config"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["hospital_id"], name: "index_analysis_results_on_hospital_id"
    t.index ["user_id"], name: "index_analysis_results_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "label", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_categories_on_is_active"
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["sort_order"], name: "index_categories_on_sort_order"
  end

  create_table "data_uploads", force: :cascade do |t|
    t.bigint "hospital_id", null: false
    t.bigint "user_id", null: false
    t.string "file_name", null: false
    t.integer "file_size"
    t.string "file_type"
    t.string "status", default: "pending"
    t.string "data_category"
    t.text "file_path"
    t.text "original_data"
    t.text "processed_data"
    t.text "validation_errors"
    t.text "error_message"
    t.integer "total_rows"
    t.integer "processed_rows"
    t.integer "error_rows"
    t.datetime "processing_started_at"
    t.datetime "processing_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_data_uploads_on_created_at"
    t.index ["data_category"], name: "index_data_uploads_on_data_category"
    t.index ["hospital_id"], name: "index_data_uploads_on_hospital_id"
    t.index ["status"], name: "index_data_uploads_on_status"
    t.index ["user_id"], name: "index_data_uploads_on_user_id"
  end

  create_table "etl_jobs", force: :cascade do |t|
    t.bigint "hospital_id", null: false
    t.bigint "data_upload_id", null: false
    t.string "job_type"
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.integer "processed_records"
    t.integer "total_records"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_upload_id"], name: "index_etl_jobs_on_data_upload_id"
    t.index ["hospital_id"], name: "index_etl_jobs_on_hospital_id"
  end

  create_table "field_mappings", force: :cascade do |t|
    t.bigint "hospital_id", null: false
    t.bigint "data_upload_id"
    t.string "source_field", null: false
    t.string "target_field", null: false
    t.string "mapping_type", default: "direct"
    t.string "data_type"
    t.text "transformation_rules"
    t.text "validation_rules"
    t.boolean "is_required", default: false
    t.boolean "is_active", default: true
    t.string "description"
    t.integer "order_index"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_upload_id"], name: "index_field_mappings_on_data_upload_id"
    t.index ["hospital_id"], name: "index_field_mappings_on_hospital_id"
    t.index ["is_active"], name: "index_field_mappings_on_is_active"
    t.index ["mapping_type"], name: "index_field_mappings_on_mapping_type"
    t.index ["source_field", "target_field"], name: "index_field_mappings_on_source_field_and_target_field"
  end

  create_table "hospitals", force: :cascade do |t|
    t.string "name", null: false
    t.string "plan", default: "basic"
    t.string "domain"
    t.text "settings"
    t.string "address"
    t.string "phone"
    t.string "email"
    t.string "license_number"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_hospitals_on_domain", unique: true
    t.index ["is_active"], name: "index_hospitals_on_is_active"
    t.index ["name"], name: "index_hospitals_on_name"
  end

  create_table "report_executions", force: :cascade do |t|
    t.bigint "report_schedule_id", null: false
    t.string "status"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "file_path"
    t.integer "file_size"
    t.text "error_message"
    t.integer "execution_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_schedule_id"], name: "index_report_executions_on_report_schedule_id"
  end

  create_table "report_schedules", force: :cascade do |t|
    t.bigint "hospital_id", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.text "description"
    t.string "report_type"
    t.string "schedule_type"
    t.text "schedule_config"
    t.text "recipients"
    t.datetime "last_run_at"
    t.datetime "next_run_at"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "active"
    t.index ["hospital_id"], name: "index_report_schedules_on_hospital_id"
    t.index ["status"], name: "index_report_schedules_on_status"
    t.index ["user_id"], name: "index_report_schedules_on_user_id"
  end

  create_table "standard_fields", force: :cascade do |t|
    t.string "name", null: false
    t.string "label", null: false
    t.text "description"
    t.string "data_type", default: "string", null: false
    t.string "category", null: false
    t.boolean "is_required", default: false
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.json "validation_rules"
    t.string "default_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "sort_order"], name: "index_standard_fields_on_category_and_sort_order"
    t.index ["is_active"], name: "index_standard_fields_on_is_active"
    t.index ["name"], name: "index_standard_fields_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "hospital_id", null: false
    t.string "name", null: false
    t.string "role", default: "viewer"
    t.string "department"
    t.string "position"
    t.string "phone"
    t.boolean "is_active", default: true
    t.datetime "last_login_at"
    t.string "avatar_url"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["department"], name: "index_users_on_department"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["hospital_id", "email"], name: "index_users_on_hospital_id_and_email", unique: true
    t.index ["hospital_id"], name: "index_users_on_hospital_id"
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "analysis_results", "hospitals"
  add_foreign_key "analysis_results", "users"
  add_foreign_key "data_uploads", "hospitals"
  add_foreign_key "data_uploads", "users"
  add_foreign_key "etl_jobs", "data_uploads"
  add_foreign_key "etl_jobs", "hospitals"
  add_foreign_key "field_mappings", "data_uploads"
  add_foreign_key "field_mappings", "hospitals"
  add_foreign_key "report_executions", "report_schedules"
  add_foreign_key "report_schedules", "hospitals"
  add_foreign_key "report_schedules", "users"
  add_foreign_key "users", "hospitals"
end
