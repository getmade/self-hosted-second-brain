# Second Brain for humans and AI agents

A self-hosted knowledge base made of plain Markdown files. You read and write it
in Obsidian. Your AI tools (Claude, ChatGPT, Gemini, Perplexity, Claude Code,
your own agents) search and extend it over MCP, with semantic search.

One vault, one server, every assistant works with the same knowledge.

```
Obsidian (your devices) <-- Git --> private vault repository <-- Git --> vault-sync
                                                                              |
AI clients -- HTTPS + token --> gateway --> basic-memory --> vault (Markdown)
                                                 |
                                         index (SQLite + vectors)
```

| Service | Role |
|---|---|
| `basic-memory` | [Basic Memory](https://github.com/basicmachines-co/basic-memory) MCP server: full-text and semantic search, reads and writes the Markdown files |
| `gateway` | [Caddy](https://caddyserver.com): checks a token for every request before it reaches the MCP server |
| `vault-sync` | Syncs the vault with a private Git repository, enforces read-only and hidden folders |

There is no separate vector database. Basic Memory keeps its index and vectors
in SQLite. The index can be rebuilt from the files at any time.

## What you get

- **Plain files you own.** Markdown in a Git repository. No lock-in.
- **Semantic search in many languages.** A local multilingual embedding model;
  notes are not sent to an embedding API.
- **One token per client.** Lock out a single client without touching the others.
- **Folder rules for agents.** Read-only folders, a hidden private folder, a
  shared docs folder and one folder per agent.
- **Works with clients that cannot send headers.** ChatGPT and the Gemini app
  connect with a secret URL.

## Before you start: two things to know

**1. Basic Memory has no authentication of its own.** Its HTTP endpoint is
unprotected. That is why `basic-memory` has no public port and only `gateway`
is exposed. Never route your domain to `basic-memory` directly.

**2. Basic Memory writes into your notes.** When indexing, it adds a metadata
header to every Markdown file that does not have one:

```
---
title: Pricing
type: note
permalink: main/knowledge/pricing
---
```

This cannot be switched off in version 0.23.2. Obsidian shows it as
"Properties". The text below it stays unchanged.

## Vault structure

| Folder | Content | Agents read | Agents write |
|---|---|---|---|
| `private/` | your private notes | no | no |
| `about-me/` | your preferences and the rules for all agents | yes | no |
| `knowledge/` | general, reviewed knowledge | yes | no |
| `docs/` | documentation: servers, workflows, where things are | yes | yes |
| `agents/<name>/` | logs and results per agent | yes | yes |
| `inbox/` | proposals for `knowledge/` and `about-me/` | yes | yes |
| `inbox/_rejected/` | rejected agent writes, not indexed | no | no |

A starter vault with these folders and a ready-made `about-me/agent-rules.md`
is in [`vault-template/`](vault-template/).

### How the rules are enforced

Basic Memory has no per-folder permissions. `vault-sync` enforces them on every
sync run (default: every 120 seconds):

- **Read-only folders** (`knowledge/`, `about-me/`) only change through Git,
  that is from Obsidian. If an agent writes there, its version is copied to
  `inbox/_rejected/` and the file is reset. Deleted files are restored.
- **Hidden folders** (`private/`) are never checked out on the server (Git
  sparse checkout). Basic Memory never sees them, so they do not appear in
  search results. Anything an agent puts there is moved to `inbox/_rejected/`.

Limits:

- Protection kicks in at the next sync run, not instantly.
- The metadata header is not protected, because Basic Memory writes it itself.
- Rules apply to all clients equally. There are no per-agent permissions:
  `agents/<name>/` is a convention, not a lock.
- Hidden notes are still stored in your Git repository. Never put passwords or
  keys in the vault; use a password manager.
- On conflicting edits, the Obsidian version wins. The agent version stays in
  the Git history.

## Setup

### Requirements

- A server with Docker Compose, for example a small VPS with
  [Coolify](https://coolify.io). The multilingual embedding model needs
  noticeably more RAM than the English default model.
- A domain or subdomain pointing to the server.
- A GitHub account (or any Git host) for the private vault repository.
- Outbound internet access on first start: Basic Memory downloads the embedding
  model from huggingface.co.

### 1. Create the vault repository

1. Create a new **private**, empty repository just for your notes, e.g. `my-vault`.
   Keep it separate from this configuration repository.
2. Optionally copy the contents of `vault-template/` into it as a starting point.
3. Create a fine-grained personal access token with access to this one
   repository only and the permission "Contents: Read and write".

### 2. Deploy

**Coolify**

1. New resource → Docker Compose → this repository (or your fork) as source.
2. Add the environment variables from [`.env.example`](.env.example). Set at
   least one `MCP_TOKEN_*`, plus `VAULT_GIT_REMOTE` and `VAULT_GIT_TOKEN`.
3. Assign your domain to the service **`gateway`**, port **8080**.
   Not to `basic-memory`.
4. Deploy.

**Plain Docker Compose**

```bash
cp .env.example .env    # fill in the values
docker compose up -d --build
```

Then put a reverse proxy with HTTPS (Caddy, Traefik, nginx) in front of
`gateway:8080`.

The first start takes a few minutes while the embedding model downloads.

### 3. Check

```bash
# Without token: must return 401
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://mcp.example.com/mcp

# With token: must return 200
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://mcp.example.com/mcp \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}'
```

### 4. Connect Obsidian

On every computer:

```bash
git config --global credential.helper osxkeychain   # macOS: remember the credentials
git clone https://github.com/<you>/my-vault.git ~/my-vault
```

Use your GitHub username and a personal access token as password.

1. Open the folder in Obsidian as a vault.
2. Install the community plugin "Git".
3. Enable automatic commit-and-sync and pull, e.g. every 5 minutes, and
   "pull on startup".

On iPhone and iPad the Git plugin is unreliable. Use the Claude, ChatGPT or
Gemini app to read and write notes there, or a Git client such as Working Copy.

Do not sync the vault folder with iCloud or Dropbox at the same time as Git:
two sync systems on the same files corrupt the repository sooner or later.

### 5. Connect your AI clients

See [docs/clients.md](docs/clients.md) for Claude Code, Claude, ChatGPT, Gemini,
Perplexity, Abacus AI, Genspark and custom agents.

## Operations

- **Backup:** the vault lives in your Git repository. The index (`bm-state`
  volume) needs no backup.
- **Update:** raise `BASIC_MEMORY_VERSION` and redeploy. Read the Basic Memory
  changelog first; the project moves fast.
- **Change the embedding model:** afterwards run `basic-memory reindex --embeddings`
  in the `basic-memory` container, otherwise old and new vectors do not match.
- **Stale search results:** if deleted or moved notes still show up, run
  `basic-memory reindex --full` in the `basic-memory` container.
- **Lock out a client:** replace its token and redeploy.
- **Add a client:** use a spare `MCP_TOKEN_EXTRA_*` slot, or add a new slot to
  `docker-compose.yml` and `gateway/Caddyfile`.
- **English-only notes:** set `EMBEDDING_MODEL=bge-small-en-v1.5` to save RAM.

## Security notes

- Every readable folder is sent to the AI services you connect. Think about what
  belongs in `private/` before connecting third-party services.
- Tokens in URLs (ChatGPT, Gemini) are weaker than header tokens: they can end
  up in client settings or logs. Use a separate token for each and replace it if
  it leaks.
- Never commit real tokens. `.env` is git-ignored.

## Configuration reference

| Variable | Default | Purpose |
|---|---|---|
| `MCP_TOKEN_*` | empty | access tokens, at least 32 characters; empty slots grant nothing |
| `VAULT_GIT_REMOTE` | empty | HTTPS URL of the private vault repository |
| `VAULT_GIT_TOKEN` | empty | access token for that repository |
| `VAULT_GIT_BRANCH` | `main` | branch to sync |
| `VAULT_SYNC_INTERVAL` | `120` | seconds between sync runs |
| `VAULT_PROTECTED_PATHS` | `knowledge about-me` | read-only folders, space-separated |
| `VAULT_HIDDEN_PATHS` | `private` | folders never checked out on the server |
| `BASIC_MEMORY_VERSION` | `0.23.2` | Basic Memory image tag |
| `EMBEDDING_MODEL` | multilingual MiniLM | FastEmbed model for semantic search |
| `EMBEDDING_DIMENSIONS` | `384` | must match the model |
| `LOG_LEVEL` | `INFO` | Basic Memory log level |

## Status

Running in production since October 2026 with Basic Memory 0.23.2 on Coolify,
with Claude Code, Claude, ChatGPT, Gemini, Perplexity, Abacus AI and Genspark.
Hermes and OpenClaw are not tested yet.

## Credits

- [Basic Memory](https://github.com/basicmachines-co/basic-memory) by Basic Machines (AGPL-3.0)
- [Caddy](https://caddyserver.com) (Apache-2.0)
- [Obsidian](https://obsidian.md) and the
  [Obsidian Git](https://github.com/Vinzent03/obsidian-git) plugin

This repository contains only configuration and scripts. It does not include or
modify Basic Memory's code; the image is pulled from its official registry.

## License

Copyright (C) 2026 GET MADE.

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE).
In short: you may use, change and share it, also commercially. If you
distribute a modified version or offer it as a network service, you must
publish your changes under the same license.

### Commercial licensing

Want to use or build on this project without the AGPL obligations, for example
in a closed product or a managed service? Commercial licenses are available
from GET MADE: [getmade.eu](https://getmade.eu).

### Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md)
first: contributions are accepted under terms that keep commercial licensing
possible.
