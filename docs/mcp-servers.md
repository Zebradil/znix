# MCP servers for agent tools

`znix.mcpServers` registers MCP servers in **every** enabled Claude Code profile — personal and the company
ones alike — and in opencode and Cursor. Entries are written in Claude Code's shape (`type` / `url` / `oauth` /
`headers`); the opencode and Cursor modules translate them into their own schemas.

Claude Code has no `settings.json` surface for MCP (verified on 2.1.234: an `mcpServers` key there is ignored), so
the entries are merged with `jq` into each profile's own state file, `$CLAUDE_CONFIG_DIR/.claude.json`, during
home-manager activation.

```nix
znix.mcpServers.personal-knowledge-base = self.lib.claude.personalKnowledgeBase;
```

Properties of the merge:

- Servers added by hand (`claude mcp add -s user …`) survive it — only the keys listed in Nix are written.
- A key dropped from Nix is **not** removed from the state file; clean it up with
  `claude mcp remove -s user <name>`.
- No secrets go through the Nix store. OAuth credentials are stored by each tool per config directory.

## opencode and Cursor

opencode gets the servers in `~/.config/opencode/opencode.json` under `mcp`, written wholesale like the rest of that
file (`type = "remote"`, plus `url`, `oauth`, `headers`). Its OAuth callback is
`http://127.0.0.1:<port>/mcp/oauth/callback` — a path Claude Code never uses, so it needs its own redirect URI
registered. The port is not part of that registration and `callbackPort` is stripped from the entry: opencode
redirects to a loopback IP literal, and Authelia implements RFC 8252 §7.3 port flexibility there, so any port opencode
picks matches. Sign in with `opencode mcp auth <name>`.

Cursor gets them in `~/.cursor/mcp.json` under `mcpServers`, merged with `jq` at activation because Cursor's UI
writes to that file too (same caveats as `.claude.json`: hand-added servers survive, removed ones need deleting by
hand). Cursor's schema has no `type` and takes a static OAuth client as `auth.CLIENT_ID`; its redirect URIs are
fixed and unconfigurable — and on `localhost`, which is not an IP literal and so gets no port flexibility:

```
http://localhost:8787/callback                              # desktop app and CLI
https://www.cursor.com/agents/mcp/oauth/callback            # web and Cursor cloud agents
```

`callbackPort` therefore has nothing to map onto on the Cursor side.

Claude Code is in the same position for the opposite reason: it redirects to `localhost`, not `127.0.0.1`
([claude-code#42765](https://github.com/anthropics/claude-code/issues/42765)), so its `callbackPort` has to stay
pinned and registered exactly. Authelia's matching only relaxes the port when *both* the registered and the requested
host are loopback IP literals with the same hostname, path, and query.

## Personal knowledge base

`personal-knowledge-base` points at [kb-mcp](https://github.com/zebradil/know-mcp) on
`https://kb-mcp.zebradil.dev/mcp`. The name is deliberate: a company knowledge base may get its own server later, and
`ai/AGENTS.md` tells agents the two never exchange content.

Auth is OAuth against Authelia (`https://auth.zebradil.dev`), which does **not** offer dynamic client registration —
its discovery document has no `registration_endpoint`. Every client therefore needs a pre-registered client id
(`oauth.clientId`, `auth.CLIENT_ID` for Cursor) and a redirect URI Authelia knows, listed under "sign in" below. They
all go on the existing public `kb-mcp` client (PKCE, no secret), which also serves claude.ai. That client lives in the
homelab repo, not here.

The client sets `requested_audience_mode: explicit`, so Authelia stamps `aud` only for a client that sends RFC 8707
`resource=https://kb-mcp.zebradil.dev/mcp`. If sign-in succeeds but every tool call comes back 401, that is the thing
to check first — decode the access token, and switch the mode to `implicit` if the client omits the parameter.

Then sign in once per profile — credentials are per config directory, so each profile needs its own run:

```sh
claude mcp login personal-knowledge-base            # personal
trv-claude mcp login personal-knowledge-base        # company
trv-claude-key mcp login personal-knowledge-base    # company, API key
opencode mcp auth personal-knowledge-base           # opencode
```

Cursor signs in from its MCP settings page. All told, the `kb-mcp` client carries these redirect URIs (registered in
the homelab repo's `prototypes/authelia/helm/authelia.yaml`):

```
http://localhost:41234/callback                     # Claude Code
http://127.0.0.1/mcp/oauth/callback                 # opencode, any port
http://localhost:8787/callback                      # Cursor desktop/CLI
https://www.cursor.com/agents/mcp/oauth/callback    # Cursor web
```

A static bearer token (`kbsk_…` in an `Authorization` header) also works and needs no IdP client, at the cost of
keeping the token reachable at launch time. Claude Code expands `${VAR}` inside header values from the environment,
so a token can stay out of the config file — but OAuth is the path this repo takes.

### The claude.ai connector

The same server is also connected as a claude.ai Custom Connector, which is what made it available in the personal
profile only (connectors follow the claude.ai account, and the company profiles use a different one). Keep it: it is
what serves claude.ai chats. Claude Code prefers a locally configured server over a connector pointing at the same
URL and lists the connector as hidden, so the profiles do not see the tools twice.

To hide claude.ai connectors in Claude Code entirely, `disableClaudeAiConnectors: true` in settings does it — but it
covers *all* connectors (Gmail, Calendar, Drive included), so it is not used here.
