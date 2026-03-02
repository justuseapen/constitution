module Importers
  class GitImporter
    def initialize(project:, user:, url:, service_system: nil)
      @project = project
      @user = user
      @url = url
      @service_system = service_system || find_or_create_system
    end

    def import!
      repository = create_repository
      trigger_indexing(repository)
      repository
    end

    private

    def create_repository
      name = extract_repo_name(@url)
      @service_system.repositories.create!(
        name: name,
        url: @url,
        default_branch: detect_default_branch
      )
    end

    def trigger_indexing(repository)
      CodebaseIndexJob.perform_later(repository.id, project_id: @project.id, user_id: @user.id)
    end

    def find_or_create_system
      name = extract_repo_name(@url)
      @project.team.service_systems.find_or_create_by!(name: name) do |sys|
        sys.system_type = :service
      end
    end

    def extract_repo_name(url)
      url.split("/").last.sub(/\.git$/, "")
    end

    def detect_default_branch
      "main"
    end
  end
end
