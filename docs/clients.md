# Connecting clients

All clients use the same server. Each one gets its own token slot, so you can
lock out a single client by replacing its token and redeploying.

Generate tokens with:

```bash
openssl rand -hex 32
```

Use hex tokens everywhere. They avoid problems with special characters and are
required for ChatGPT and Gemini (see below).

Replace `mcp.example.com` with your domain.

| Client | Token slot | How the token is sent |
|---|---|---|
| Claude Code | `MCP_TOKEN_CLAUDE` | `Authorization: Bearer` header |
| Claude app (web, desktop, mobile) | `MCP_TOKEN_CLAUDE` | request header in the custom connector |
| ChatGPT | `MCP_TOKEN_CHATGPT` | token in the URL |
| Gemini app | `MCP_TOKEN_GEMINI` | token in the URL |
| Perplexity | `MCP_TOKEN_PERPLEXITY` | "API key" field |
| Abacus AI | `MCP_TOKEN_ABACUS` | header in the JSON config |
| Genspark | `MCP_TOKEN_GENSPARK` | request header field |
| Hermes, OpenClaw, others | own slot or `MCP_TOKEN_EXTRA_*` | `Authorization: Bearer` header |

Client interfaces change often. The steps below were verified in October 2026.

## Claude Code

Read the token without it ending up in your shell history:

```bash
read -s "T?Token: "          # zsh; in bash: read -s -p "Token: " T
claude mcp add --transport http second-brain https://mcp.example.com/mcp \
  --header "Authorization: Bearer $T" --scope user
unset T
```

## Claude app

Settings → Connectors → Add custom connector.

- URL: `https://mcp.example.com/mcp`
- Authentication: no sign-in
- Request header: `authorization` = `Bearer <token>`

A connector added once is available on web, desktop and mobile.

## ChatGPT

ChatGPT supports only OAuth or no authentication for custom MCP servers, so the
token is part of the URL.

- Server URL: `https://mcp.example.com/mcp/<MCP_TOKEN_CHATGPT>`
- Authentication: No authentication

Treat this URL like a password.

## Gemini app

Same approach as ChatGPT: the connector form only offers a URL and optional
OAuth.

- MCP server URL: `https://mcp.example.com/mcp/<MCP_TOKEN_GEMINI>` (no trailing slash)
- Client ID and client secret: leave empty

## Perplexity

Custom connector with:

- MCP server URL: `https://mcp.example.com/mcp`
- Authentication: API key, value `<token>`
- Transport: Streamable HTTP

## Abacus AI

MCP servers → Add via JSON:

```json
{
  "second_brain": {
    "url": "https://mcp.example.com/mcp",
    "headers": { "Authorization": "Bearer <token>" }
  }
}
```

Keep "make available to the whole organization" switched off unless you want
everyone in the organization to reach your vault.

## Genspark

Custom MCP server with URL `https://mcp.example.com/mcp` and the request header:

```json
{"Authorization": "Bearer <token>"}
```

## Hermes, OpenClaw and other agents

Add the server as a regular remote MCP server (Streamable HTTP) with URL and
`Authorization: Bearer <token>` header. Not tested by us yet.

The Basic Memory plugins for Hermes and OpenClaw start their own local Basic
Memory instance or use the hosted Basic Memory cloud. They do not connect to a
self-hosted server like this one.

## System instruction for every agent

Keep the rules in one place (`about-me/agent-rules` in the vault) and give each
agent only this short instruction:

```
You have MCP access to my second brain (Basic Memory, project "main").
Before your first task in a session, read the note about-me/agent-rules
and follow it. Your own folder is agents/<agent-name>/.
```
