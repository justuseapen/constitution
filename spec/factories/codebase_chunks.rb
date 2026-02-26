FactoryBot.define do
  factory :codebase_chunk do
    content { "def sample_method\n  true\nend" }
    chunk_type { "method" }
    start_line { 1 }
    end_line { 3 }
    codebase_file
  end
end
