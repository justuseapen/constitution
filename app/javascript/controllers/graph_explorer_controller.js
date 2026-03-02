import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = { rootUrl: String, neighborsUrl: String, impactUrl: String }
  static targets = ["canvas", "details", "sidebar"]

  connect() {
    this.nodes = []
    this.edges = []
    this.nodeMap = new Map()
    this.expandedNodes = new Set()
    this.selectedNode = null

    this.initSvg()
    this.loadRootNodes()
  }

  disconnect() {
    if (this.simulation) this.simulation.stop()
  }

  initSvg() {
    const svg = d3.select(this.canvasTarget)
    const width = this.canvasTarget.clientWidth || 800
    const height = this.canvasTarget.clientHeight || 600

    // Arrow marker
    svg.append("defs").append("marker")
      .attr("id", "arrow")
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 22)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .attr("fill", "#94a3b8")

    this.linkGroup = svg.append("g").attr("class", "links")
    this.nodeGroup = svg.append("g").attr("class", "nodes")

    this.simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.id).distance(120))
      .force("charge", d3.forceManyBody().strength(-250))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(35))
      .on("tick", () => this.tick())

    // Zoom
    const zoom = d3.zoom()
      .scaleExtent([0.2, 4])
      .on("zoom", (event) => {
        this.linkGroup.attr("transform", event.transform)
        this.nodeGroup.attr("transform", event.transform)
      })
    svg.call(zoom)
  }

  async loadRootNodes() {
    try {
      const response = await fetch(this.rootUrlValue, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()

      data.nodes.forEach(n => this.addNode(n))
      this.updateGraph()
    } catch (e) {
      console.error("Failed to load root nodes:", e)
    }
  }

  async expandNode(nodeData) {
    if (this.expandedNodes.has(nodeData.id)) return

    this.expandedNodes.add(nodeData.id)

    const idParts = nodeData.id.split("_")
    const nodeType = nodeData.type
    const nodeId = idParts.slice(1).join("_")

    try {
      const url = `${this.neighborsUrlValue}?node_type=${encodeURIComponent(nodeType)}&node_id=${encodeURIComponent(nodeId)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()

      data.nodes.forEach(n => this.addNode(n))
      data.edges.forEach(e => this.addEdge(e))
      this.updateGraph()
    } catch (e) {
      console.error("Failed to expand node:", e)
    }
  }

  async runImpactAnalysis(nodeData) {
    const idParts = nodeData.id.split("_")
    const nodeType = nodeData.type
    const nodeId = idParts.slice(1).join("_")

    try {
      const url = `${this.impactUrlValue}?node_type=${encodeURIComponent(nodeType)}&node_id=${encodeURIComponent(nodeId)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()

      // Highlight affected nodes
      const affectedIds = new Set(data.affected.map(a => a.id))
      this.nodeGroup.selectAll(".node-circle")
        .attr("stroke", d => affectedIds.has(d.id) ? "#ef4444" : "white")
        .attr("stroke-width", d => affectedIds.has(d.id) ? 3 : 2)

      this.updateDetails(nodeData, data)
    } catch (e) {
      console.error("Failed to run impact analysis:", e)
    }
  }

  addNode(node) {
    if (this.nodeMap.has(node.id)) return
    this.nodeMap.set(node.id, node)
    this.nodes.push(node)
  }

  addEdge(edge) {
    const key = `${edge.source}->${edge.target}`
    const exists = this.edges.some(e => {
      const s = typeof e.source === "object" ? e.source.id : e.source
      const t = typeof e.target === "object" ? e.target.id : e.target
      return `${s}->${t}` === key
    })
    if (!exists) this.edges.push(edge)
  }

  updateGraph() {
    // Links
    const link = this.linkGroup.selectAll("line")
      .data(this.edges, d => {
        const s = typeof d.source === "object" ? d.source.id : d.source
        const t = typeof d.target === "object" ? d.target.id : d.target
        return `${s}->${t}`
      })

    link.exit().remove()

    link.enter()
      .append("line")
      .attr("stroke", "#94a3b8")
      .attr("stroke-width", 1.5)
      .attr("marker-end", "url(#arrow)")

    // Nodes
    const nodeSelection = this.nodeGroup.selectAll("g.node")
      .data(this.nodes, d => d.id)

    nodeSelection.exit().remove()

    const enter = nodeSelection.enter()
      .append("g")
      .attr("class", "node")
      .style("cursor", "pointer")
      .call(d3.drag()
        .on("start", (event, d) => {
          if (!event.active) this.simulation.alphaTarget(0.3).restart()
          d.fx = d.x
          d.fy = d.y
        })
        .on("drag", (event, d) => {
          d.fx = event.x
          d.fy = event.y
        })
        .on("end", (event, d) => {
          if (!event.active) this.simulation.alphaTarget(0)
          d.fx = null
          d.fy = null
        })
      )
      .on("click", (event, d) => {
        event.stopPropagation()
        this.selectNode(d)
      })
      .on("dblclick", (event, d) => {
        event.stopPropagation()
        this.expandNode(d)
      })

    enter.append("circle")
      .attr("class", "node-circle")
      .attr("r", d => this.nodeRadius(d))
      .attr("fill", d => this.nodeColor(d))
      .attr("stroke", "white")
      .attr("stroke-width", 2)

    enter.append("text")
      .text(d => this.truncate(d.name, 16))
      .attr("text-anchor", "middle")
      .attr("dy", d => this.nodeRadius(d) + 14)
      .attr("font-size", 11)
      .attr("fill", "#374151")
      .attr("pointer-events", "none")

    // Update simulation
    this.simulation.nodes(this.nodes)
    this.simulation.force("link").links(this.edges)
    this.simulation.alpha(0.5).restart()
  }

  tick() {
    this.linkGroup.selectAll("line")
      .attr("x1", d => d.source.x)
      .attr("y1", d => d.source.y)
      .attr("x2", d => d.target.x)
      .attr("y2", d => d.target.y)

    this.nodeGroup.selectAll("g.node")
      .attr("transform", d => `translate(${d.x},${d.y})`)
  }

  selectNode(nodeData) {
    this.selectedNode = nodeData

    // Highlight selected
    this.nodeGroup.selectAll(".node-circle")
      .attr("stroke", d => d.id === nodeData.id ? "#2563eb" : "white")
      .attr("stroke-width", d => d.id === nodeData.id ? 3 : 2)

    this.showNodeDetails(nodeData)
  }

  showNodeDetails(node) {
    const expanded = this.expandedNodes.has(node.id)
    const props = Object.entries(node)
      .filter(([k]) => !["id", "x", "y", "vx", "vy", "fx", "fy", "index"].includes(k))
      .map(([k, v]) => `<div class="flex justify-between py-1 border-b border-gray-100">
        <span class="text-xs text-gray-500">${k}</span>
        <span class="text-xs font-medium text-gray-900">${v}</span>
      </div>`).join("")

    this.detailsTarget.innerHTML = `
      <div class="space-y-3">
        <div>
          <span class="inline-block px-2 py-0.5 text-xs font-medium rounded-full" style="background: ${this.nodeColor(node)}20; color: ${this.nodeColor(node)}">
            ${node.type}
          </span>
        </div>
        <h3 class="font-semibold text-gray-900">${node.name}</h3>
        <div class="space-y-0">${props}</div>
        <div class="pt-2 space-y-2">
          ${expanded ? "" : `<button data-action="click->graph-explorer#handleExpand" data-node-id="${node.id}" class="w-full px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700">Expand Neighbors</button>`}
          <button data-action="click->graph-explorer#handleImpact" data-node-id="${node.id}" class="w-full px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100">Impact Analysis</button>
        </div>
      </div>
    `
  }

  handleExpand(event) {
    const nodeId = event.currentTarget.dataset.nodeId
    const node = this.nodeMap.get(nodeId)
    if (node) this.expandNode(node)
  }

  handleImpact(event) {
    const nodeId = event.currentTarget.dataset.nodeId
    const node = this.nodeMap.get(nodeId)
    if (node) this.runImpactAnalysis(node)
  }

  updateDetails(node, impactData) {
    const count = impactData.affected ? impactData.affected.length : 0
    const depth = impactData.depth || 0

    this.detailsTarget.innerHTML += `
      <div class="mt-3 p-3 bg-red-50 rounded-lg">
        <h4 class="text-sm font-semibold text-red-800">Impact Analysis</h4>
        <p class="text-xs text-red-700 mt-1">${count} affected node${count !== 1 ? "s" : ""}, depth ${depth}</p>
        ${impactData.affected ? impactData.affected.map(a => `
          <div class="text-xs text-red-600 mt-1">${a.type}: ${a.name || a.id}</div>
        `).join("") : ""}
      </div>
    `
  }

  nodeColor(node) {
    const colors = {
      ServiceSystem: "#3b82f6",
      Repository: "#8b5cf6",
      ExtractedArtifact: "#10b981",
      Document: "#f59e0b",
      Blueprint: "#ef4444",
      route: "#06b6d4",
      controller: "#8b5cf6",
      model: "#10b981",
      service: "#f97316",
      api_client: "#ef4444",
      event_emitter: "#eab308"
    }
    return colors[node.type] || colors[node.artifact_type] || "#6b7280"
  }

  nodeRadius(node) {
    const sizes = { ServiceSystem: 24, Repository: 18, ExtractedArtifact: 12 }
    return sizes[node.type] || 14
  }

  truncate(str, max) {
    return str && str.length > max ? str.substring(0, max - 1) + "\u2026" : str
  }
}
