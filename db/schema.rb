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

ActiveRecord::Schema[8.1].define(version: 2026_03_02_171108) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "agent_conversations", force: :cascade do |t|
    t.bigint "conversable_id", null: false
    t.string "conversable_type", null: false
    t.datetime "created_at", null: false
    t.string "model_name"
    t.string "model_provider"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["conversable_type", "conversable_id"], name: "idx_on_conversable_type_conversable_id_7de6cb368b"
    t.index ["user_id"], name: "index_agent_conversations_on_user_id"
  end

  create_table "agent_messages", force: :cascade do |t|
    t.bigint "agent_conversation_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_conversation_id"], name: "index_agent_messages_on_agent_conversation_id"
  end

  create_table "app_keys", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_app_keys_on_project_id"
    t.index ["token"], name: "index_app_keys_on_token", unique: true
  end

  create_table "blueprint_versions", force: :cascade do |t|
    t.bigint "blueprint_id", null: false
    t.text "body_snapshot"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "diff_from_previous"
    t.datetime "updated_at", null: false
    t.integer "version_number"
    t.index ["blueprint_id"], name: "index_blueprint_versions_on_blueprint_id"
    t.index ["created_by_id"], name: "index_blueprint_versions_on_created_by_id"
  end

  create_table "blueprints", force: :cascade do |t|
    t.integer "blueprint_type", default: 0
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "document_id"
    t.bigint "project_id", null: false
    t.string "status", default: "draft"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.integer "version", default: 0
    t.index ["created_by_id"], name: "index_blueprints_on_created_by_id"
    t.index ["document_id"], name: "index_blueprints_on_document_id"
    t.index ["project_id"], name: "index_blueprints_on_project_id"
    t.index ["updated_by_id"], name: "index_blueprints_on_updated_by_id"
  end

  create_table "codebase_chunks", force: :cascade do |t|
    t.string "chunk_type"
    t.bigint "codebase_file_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536
    t.integer "end_line"
    t.integer "start_line"
    t.datetime "updated_at", null: false
    t.index ["codebase_file_id"], name: "index_codebase_chunks_on_codebase_file_id"
    t.index ["embedding"], name: "index_codebase_chunks_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "codebase_files", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "language"
    t.datetime "last_indexed_at"
    t.string "path", null: false
    t.bigint "repository_id", null: false
    t.string "sha"
    t.datetime "updated_at", null: false
    t.index ["repository_id", "path"], name: "index_codebase_files_on_repository_id_and_path", unique: true
    t.index ["repository_id"], name: "index_codebase_files_on_repository_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.bigint "commentable_id", null: false
    t.string "commentable_type", null: false
    t.datetime "created_at", null: false
    t.boolean "resolved", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "document_versions", force: :cascade do |t|
    t.text "body_snapshot"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "diff_from_previous"
    t.bigint "document_id", null: false
    t.datetime "updated_at", null: false
    t.integer "version_number"
    t.index ["created_by_id"], name: "index_document_versions_on_created_by_id"
    t.index ["document_id"], name: "index_document_versions_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.integer "document_type", default: 0
    t.bigint "project_id", null: false
    t.string "status", default: "draft"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.integer "version", default: 0
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["project_id"], name: "index_documents_on_project_id"
    t.index ["updated_by_id"], name: "index_documents_on_updated_by_id"
  end

  create_table "drift_alerts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message"
    t.bigint "project_id", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.integer "status", default: 0
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_drift_alerts_on_project_id"
    t.index ["source_type", "source_id"], name: "index_drift_alerts_on_source_type_and_source_id"
    t.index ["status"], name: "index_drift_alerts_on_status"
    t.index ["target_type", "target_id"], name: "index_drift_alerts_on_target_type_and_target_id"
  end

  create_table "extracted_artifacts", force: :cascade do |t|
    t.integer "artifact_type", null: false
    t.bigint "codebase_file_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_type"], name: "index_extracted_artifacts_on_artifact_type"
    t.index ["codebase_file_id", "name", "artifact_type"], name: "index_extracted_artifacts_on_file_name_and_type", unique: true
    t.index ["codebase_file_id"], name: "index_extracted_artifacts_on_codebase_file_id"
  end

  create_table "feedback_items", force: :cascade do |t|
    t.text "body"
    t.integer "category", default: 0
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.integer "score"
    t.string "source"
    t.integer "status", default: 0
    t.string "submitted_by_email"
    t.jsonb "technical_context", default: {}
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_feedback_items_on_category"
    t.index ["project_id"], name: "index_feedback_items_on_project_id"
    t.index ["status"], name: "index_feedback_items_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.boolean "read", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "phases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_phases_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "status", default: 0
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_projects_on_team_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_branch", default: "main"
    t.integer "indexing_status", default: 0, null: false
    t.datetime "last_indexed_at"
    t.string "name", null: false
    t.integer "provider", default: 0, null: false
    t.bigint "service_system_id", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["service_system_id", "name"], name: "index_repositories_on_service_system_id_and_name", unique: true
    t.index ["service_system_id"], name: "index_repositories_on_service_system_id"
  end

  create_table "service_systems", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "repo_url"
    t.integer "system_type", default: 0
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_service_systems_on_team_id"
  end

  create_table "system_dependencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dependency_type", default: 0
    t.text "description"
    t.jsonb "metadata", default: {}
    t.bigint "source_system_id", null: false
    t.bigint "target_system_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_system_id", "target_system_id", "dependency_type"], name: "idx_sys_deps_unique", unique: true
    t.index ["source_system_id"], name: "index_system_dependencies_on_source_system_id"
    t.index ["target_system_id"], name: "index_system_dependencies_on_target_system_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  create_table "work_order_executions", force: :cascade do |t|
    t.string "branch_name"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "log"
    t.integer "pid"
    t.string "pull_request_url"
    t.bigint "repository_id"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.bigint "triggered_by_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_order_id", null: false
    t.index ["repository_id"], name: "index_work_order_executions_on_repository_id"
    t.index ["triggered_by_id"], name: "index_work_order_executions_on_triggered_by_id"
    t.index ["work_order_id", "status"], name: "index_work_order_executions_on_work_order_id_and_status"
    t.index ["work_order_id"], name: "index_work_order_executions_on_work_order_id"
  end

  create_table "work_orders", force: :cascade do |t|
    t.text "acceptance_criteria"
    t.bigint "assignee_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "implementation_plan"
    t.jsonb "metadata", default: {}
    t.bigint "phase_id"
    t.integer "position", default: 0
    t.integer "priority", default: 1
    t.bigint "project_id", null: false
    t.integer "status", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_work_orders_on_assignee_id"
    t.index ["phase_id"], name: "index_work_orders_on_phase_id"
    t.index ["priority"], name: "index_work_orders_on_priority"
    t.index ["project_id"], name: "index_work_orders_on_project_id"
    t.index ["status"], name: "index_work_orders_on_status"
  end

  add_foreign_key "agent_conversations", "users"
  add_foreign_key "agent_messages", "agent_conversations"
  add_foreign_key "app_keys", "projects"
  add_foreign_key "blueprint_versions", "blueprints"
  add_foreign_key "blueprints", "documents"
  add_foreign_key "blueprints", "projects"
  add_foreign_key "codebase_chunks", "codebase_files"
  add_foreign_key "codebase_files", "repositories"
  add_foreign_key "comments", "users"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "documents", "projects"
  add_foreign_key "drift_alerts", "projects"
  add_foreign_key "extracted_artifacts", "codebase_files"
  add_foreign_key "feedback_items", "projects"
  add_foreign_key "notifications", "users"
  add_foreign_key "phases", "projects"
  add_foreign_key "projects", "teams"
  add_foreign_key "repositories", "service_systems"
  add_foreign_key "service_systems", "teams"
  add_foreign_key "system_dependencies", "service_systems", column: "source_system_id"
  add_foreign_key "system_dependencies", "service_systems", column: "target_system_id"
  add_foreign_key "users", "teams"
  add_foreign_key "work_order_executions", "repositories"
  add_foreign_key "work_order_executions", "users", column: "triggered_by_id"
  add_foreign_key "work_order_executions", "work_orders"
  add_foreign_key "work_orders", "phases"
  add_foreign_key "work_orders", "projects"
end
