module Tools
  class BaseTool
    def name
      raise NotImplementedError
    end

    def definition
      raise NotImplementedError
    end

    def call(arguments)
      raise NotImplementedError
    end

    private

    def authenticate!(arguments)
      token = arguments["api_token"]
      raise "Authentication required: provide api_token" unless token
      user = User.joins(:team).find_by(authentication_token: token)
      raise "Invalid API token" unless user
      user
    end

    def find_project(user, project_id)
      user.team.projects.find(project_id)
    end
  end
end
