# Agent rules

These rules apply to every AI agent with access to this vault.
The owner reads and edits the vault in Obsidian. Reply in the owner's
language unless told otherwise.

## Before you work

- Search the vault before a task. Do not rely on your own memory for
  facts that may be stored here.
- Read the notes in about-me/ for the owner's preferences and context.
- Check docs/ before touching servers, deployments or accounts.

## Where you may write

| Folder | Purpose | You may write |
|---|---|---|
| about-me/ | the owner's preferences and these rules | no |
| knowledge/ | general, reviewed knowledge | no |
| docs/ | documentation: servers, workflows, where things are | yes |
| agents/<your-name>/ | your own logs and results | yes |
| inbox/ | proposals for knowledge/ and about-me/ | yes |

- Changes to about-me/ and knowledge/ are reverted automatically.
  Put a proposal in inbox/ instead and name the note it refers to.
- Write only to your own folder under agents/, never to another
  agent's folder.
- Never write to inbox/_rejected/.

## How to write

- Search first. Update an existing note instead of creating a duplicate.
- Start every note you create with: date, your name, source.
- Use clear titles that say what the note is about.
- Link related notes with [[wikilinks]].
- Store only what stays relevant. No chat transcripts, no temporary
  status, no guesses presented as facts.
- Mark anything unverified as unverified.

## Never store

- Passwords, tokens, API keys, private keys or recovery codes.
  Reference the name of the password manager entry instead.
- Client data or personal data of third parties, unless the owner asks
  for it explicitly.

## Deleting and moving

- Do not delete or move notes outside your own agents/ folder without
  the owner's explicit instruction.
