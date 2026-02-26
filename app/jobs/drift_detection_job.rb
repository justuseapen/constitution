class DriftDetectionJob < ApplicationJob
  queue_as :default

  def perform
    return unless GraphService.available?

    check_document_blueprint_drift
    check_blueprint_work_order_drift
  end

  private

  def check_document_blueprint_drift
    edges = GraphService.execute(
      "MATCH (d:Document)-[:DEFINES_FEATURE]->(b:Blueprint) " \
      "RETURN d.postgres_id AS doc_id, b.postgres_id AS bp_id"
    )

    edges.each do |edge|
      doc = Document.find_by(id: edge[:doc_id])
      bp = Blueprint.find_by(id: edge[:bp_id])
      next unless doc && bp
      next unless doc.updated_at > bp.updated_at

      DriftAlert.find_or_create_by!(
        source_type: "Document", source_id: doc.id,
        target_type: "Blueprint", target_id: bp.id,
        status: :open
      ) do |alert|
        alert.project = doc.project
        alert.message = "#{doc.title} was updated since #{bp.title} was last reviewed"
      end
    end
  end

  def check_blueprint_work_order_drift
    edges = GraphService.execute(
      "MATCH (b:Blueprint)-[:IMPLEMENTED_BY]->(w:WorkOrder) " \
      "RETURN b.postgres_id AS bp_id, w.postgres_id AS wo_id"
    )

    edges.each do |edge|
      bp = Blueprint.find_by(id: edge[:bp_id])
      wo = WorkOrder.find_by(id: edge[:wo_id])
      next unless bp && wo
      next unless bp.updated_at > wo.updated_at

      DriftAlert.find_or_create_by!(
        source_type: "Blueprint", source_id: bp.id,
        target_type: "WorkOrder", target_id: wo.id,
        status: :open
      ) do |alert|
        alert.project = bp.project
        alert.message = "#{bp.title} was updated since work order '#{wo.title}' was last reviewed"
      end
    end
  end
end
