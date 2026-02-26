FactoryBot.define do
  factory :codebase_file do
    path { "app/models/#{Faker::Internet.slug}.rb" }
    language { "ruby" }
    content { "class Sample\nend" }
    sha { Digest::SHA256.hexdigest(content) }
    repository
  end
end
