class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_document, only: [ :show, :edit, :update, :destroy ]

  def index
    @documents = @project.documents.order(created_at: :desc)
  end

  def show
  end

  def new
    @document = @project.documents.build
  end

  def create
    @document = @project.documents.build(document_params)
    @document.created_by = current_user
    if @document.save
      redirect_to project_document_path(@project, @document), notice: "Document created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @document.updated_by = current_user
    if @document.update(document_params)
      @document.create_version!(current_user)
      redirect_to project_document_path(@project, @document), notice: "Document updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def import
    file = params[:file]
    unless file
      redirect_to project_documents_path(@project), alert: "Please select a file to import."
      return
    end

    document = Importers::DocumentImporter.new(
      project: @project,
      user: current_user,
      file: file,
      document_type: params[:document_type]&.to_sym || :feature_requirement
    ).import!

    redirect_to project_document_path(@project, document), notice: "Document imported successfully."
  rescue StandardError => e
    redirect_to project_documents_path(@project), alert: "Import failed: #{e.message}"
  end

  def destroy
    @document.destroy
    redirect_to project_documents_path(@project), notice: "Document deleted."
  end

  private

  def set_project
    @project = current_user.team.projects.find(params[:project_id])
  end

  def set_document
    @document = @project.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :body, :document_type)
  end
end
