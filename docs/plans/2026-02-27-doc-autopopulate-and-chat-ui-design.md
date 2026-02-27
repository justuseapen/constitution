# Design: Auto-populate Documents on Repo Connection & Agent Chat UI

**Date:** 2026-02-27
**Status:** Approved

## Problem

1. When a project is created and a repo is connected, the two default seed documents (Product Overview, Technical Requirements) remain empty placeholders. The existing `GenerateRequirementsJob` creates *separate* "(Auto-Generated)" documents instead of updating the seed docs.
2. The AI Agent chat sidebar does not work - sending a message produces no response. The UI is also too minimal for a good experience (no markdown rendering, no loading states, no message history).

## Design

### Part 1: Auto-populate Seed Documents on Repo Indexing

**Strategy:** Update seed documents in-place when repo indexing completes.

**Changes to `GenerateRequirementsJob`:**
- Find existing documents by `project + document_type` instead of by title with "(Auto-Generated)" suffix.
- Update the existing seed document's body with AI-generated content.
- Create a DocumentVersion snapshot before overwriting so the empty placeholder is preserved in history.
- Remove the "(Auto-Generated)" title suffix - keep original titles.
- Set document status to `"ai_generated"` so the UI can display a badge.
- Only create a new document if one with the matching `document_type` doesn't already exist (fallback).

**Better AI prompts:**
- Product Overview prompt: Generate sections based on actual repo structure - what the app does, key technologies, target users inferred from the codebase.
- Technical Requirements prompt: Generate sections based on extracted artifacts - data models, API routes, services, dependencies, infrastructure patterns found in the code.

**No changes to project creation flow.** Seed documents still get created with placeholder content via `Project.seed_documents`. They get populated when a repo is connected and indexing completes.

### Part 2: Fix & Upgrade Agent Chat

#### 2a: Debug and fix the root cause

Likely issues to investigate:
- System prompt not injected into the messages array in `AgentChatJob`
- ActionCable subscription channel name mismatch
- CSRF token handling in the Stimulus fetch call
- OpenRouter client configuration in development
- Missing error handling (failures silently swallowed)

#### 2b: Replace chat UI

**Approach:** Use `streaming-markdown` (3kB, zero-dependency) for markdown rendering + custom Stimulus controller for chat UX.

**Why not NLUX or other full libraries:** NLUX introduces its own adapter pattern that conflicts with the existing ActionCable streaming setup. The Rails/Hotwire stack is best served by Stimulus controllers. `streaming-markdown` gives us the key rendering capability at minimal cost.

**Chat UI features:**

| Feature | Implementation |
|---------|---------------|
| Resizable sidebar | CSS resize or drag handle, default ~400px width |
| Streaming markdown | `streaming-markdown` library parses chunks as they arrive via ActionCable |
| Code highlighting | highlight.js integration (triggered after streaming completes) |
| Message styling | User messages right-aligned (gray), assistant left-aligned (blue) with role avatar |
| Loading indicator | Animated dots shown after send, hidden on first delta |
| Auto-scroll | Scroll to bottom during streaming; pause if user scrolls up |
| Copy button | On code blocks (via highlight.js plugin) and full messages |
| Message history | Load previous AgentMessage records on controller connect |
| Input behavior | Enter to send, Shift+Enter for newline (textarea instead of input) |
| Error handling | Display error message in chat if job fails |

**Stimulus controller changes:**
- Replace the current `agent_chat_controller.js` entirely.
- New controller handles: ActionCable subscription, message sending via fetch, streaming markdown rendering, auto-scroll, resize, message history loading.
- Add a new endpoint or turbo frame to load conversation history on page load.

**Sidebar partial changes:**
- Replace `_sidebar.html.erb` with a properly structured chat layout.
- Add drag handle for resizing.
- Use textarea instead of single-line input.
- Include message history container pre-populated via server-rendered HTML or JSON endpoint.

**Backend changes:**
- Add `AgentChatJob` error handling - broadcast an error message type on failure.
- Inject system prompt as first message in the messages array sent to OpenRouter.
- Add a `GET /agent_chats` endpoint to return conversation history for a given conversable.
- Add ActionCable error broadcasting.

## Dependencies

- `streaming-markdown` npm package (or vendored JS file, ~3kB)
- `highlight.js` for code block syntax highlighting (may already be available)
- No new gems required

## Out of Scope

- Changing the document editor itself
- Adding new document types
- Multi-model selection in chat
- File/image upload in chat
