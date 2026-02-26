module SystemsHelper
  def system_color(system_type)
    {
      "service" => "#3B82F6",
      "library" => "#8B5CF6",
      "database" => "#10B981",
      "queue" => "#F59E0B",
      "external_api" => "#EF4444"
    }[system_type] || "#6B7280"
  end
end
