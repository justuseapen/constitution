require "rails_helper"

RSpec.describe CodeParser do
  let(:repository) { build(:repository) }

  describe "#parse" do
    it "extracts class definitions from Ruby files" do
      file = build(:codebase_file,
        path: "app/models/user.rb",
        content: "class User < ApplicationRecord\n  validates :name, presence: true\nend\n",
        repository: repository
      )

      parser = CodeParser.new(file)
      artifacts = parser.parse

      expect(artifacts.length).to be >= 1
      expect(artifacts.first[:name]).to eq("User")
    end

    it "extracts routes from routes.rb" do
      file = build(:codebase_file,
        path: "config/routes.rb",
        content: "Rails.application.routes.draw do\n  resources :users\n  get :health\nend\n",
        repository: repository
      )

      parser = CodeParser.new(file)
      artifacts = parser.parse

      route_names = artifacts.map { |a| a[:name] }
      expect(route_names).to include("users")
    end

    it "returns empty array for unsupported languages" do
      file = build(:codebase_file, path: "image.png", content: "binary", repository: repository)
      expect(CodeParser.new(file).parse).to eq([])
    end
  end

  describe "#chunk" do
    it "creates chunks from file content" do
      file = build(:codebase_file,
        path: "app/models/user.rb",
        content: "class User\n  def name\n    @name\n  end\nend\n",
        repository: repository
      )

      chunks = CodeParser.new(file).chunk
      expect(chunks).not_to be_empty
      expect(chunks.first[:content]).to be_present
      expect(chunks.first[:start_line]).to be_present
    end
  end
end
