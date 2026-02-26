import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = { url: String }
  static targets = ["graph"]

  connect() {
    fetch(this.urlValue, { headers: { "Accept": "application/json" } })
      .then(r => r.json())
      .then(data => this.render(data))
  }

  render(data) {
    const width = this.graphTarget.clientWidth || 800
    const height = 500

    const svg = d3.select(this.graphTarget)
      .append("svg")
      .attr("width", width)
      .attr("height", height)

    const colorMap = {
      service: "#3B82F6", library: "#8B5CF6", database: "#10B981",
      queue: "#F59E0B", external_api: "#EF4444"
    }

    const edgeColorMap = {
      http_api: "#3B82F6", rabbitmq: "#F59E0B", grpc: "#8B5CF6",
      database_shared: "#10B981", event_bus: "#F97316", sdk: "#6B7280"
    }

    const simulation = d3.forceSimulation(data.nodes)
      .force("link", d3.forceLink(data.edges).id(d => d.id).distance(150))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))

    // Arrow markers
    svg.append("defs").selectAll("marker")
      .data(Object.keys(edgeColorMap))
      .join("marker")
      .attr("id", d => `arrow-${d}`)
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 25)
      .attr("markerWidth", 8)
      .attr("markerHeight", 8)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .attr("fill", d => edgeColorMap[d])

    const link = svg.append("g")
      .selectAll("line")
      .data(data.edges)
      .join("line")
      .attr("stroke", d => edgeColorMap[d.type] || "#999")
      .attr("stroke-width", 2)
      .attr("marker-end", d => `url(#arrow-${d.type})`)

    const linkLabel = svg.append("g")
      .selectAll("text")
      .data(data.edges)
      .join("text")
      .text(d => d.type.replace(/_/g, " "))
      .attr("font-size", 10)
      .attr("fill", "#6B7280")
      .attr("text-anchor", "middle")

    const node = svg.append("g")
      .selectAll("g")
      .data(data.nodes)
      .join("g")
      .call(d3.drag()
        .on("start", (event, d) => { if (!event.active) simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y })
        .on("drag", (event, d) => { d.fx = event.x; d.fy = event.y })
        .on("end", (event, d) => { if (!event.active) simulation.alphaTarget(0); d.fx = null; d.fy = null })
      )

    node.append("circle")
      .attr("r", 20)
      .attr("fill", d => colorMap[d.type] || "#999")

    node.append("text")
      .text(d => d.name)
      .attr("text-anchor", "middle")
      .attr("dy", 35)
      .attr("font-size", 12)
      .attr("fill", "#374151")

    simulation.on("tick", () => {
      link
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y)

      linkLabel
        .attr("x", d => (d.source.x + d.target.x) / 2)
        .attr("y", d => (d.source.y + d.target.y) / 2 - 5)

      node.attr("transform", d => `translate(${d.x},${d.y})`)
    })
  }
}
