# 5. Offline dictionary, online translator

Date: 2026-08-23

## Status

Accepted

## Context

`translate-shell` (`trans`) backed nine shell aliases for en/ru/de lookups. Its
Google engine now answers `[ERROR] Google did not return results because rate
limiting is in effect`, Yandex has been broken for years, and upstream last
pushed in December 2024.

Two use cases were hiding behind one command, and they have opposite cost
profiles:

- **Single words**, where a definition, part of speech and phrasing matter.
  This is a finite dataset — it fits in 42MB and answers in milliseconds.
- **Phrases and sentences**, which need a translation model or a network call.

## Decision

Split them.

**Words** — `def` (en→ru, English definitions) and `defde` (en↔de) run `dictd`
against local databases. No daemon, no port: `dictd --inetd` speaks the DICT
protocol on stdin/stdout and exits, so lookups cannot collide and cost ~55ms.

**Phrases** — `tl <src>:<dst> <text>` wraps `mozhi`, trying google, yandex,
duckduckgo and deepl in turn and printing only the translation. `translate-shell`
is dropped.

## Consequences

Alternatives were measured on `aarch64-darwin` rather than judged by repo
activity, which turned out to be a poor predictor in both directions:

| candidate | verdict |
| --- | --- |
| `translatelocally` | Linux-only in nixpkgs, and none of its 31 models covers Russian |
| `argos-translate` | actively maintained, but 6s per lookup, 650MB of models, no ru↔de, and it fetches stanza resources from GitHub at runtime — not offline |
| `mozhi` | **chosen** — maintained, Darwin-native, real CLI, ~0.45s, google/yandex/duckduckgo/deepl all working; libre, mymemory and reverso do not |
| `translatepy` | last pushed 2024-07, *older* than the tool it would replace |
| `deep-translator` | `google` returns `TranslationNotFound`, `pons` dies in its scraper |
| `gtt` | maintained, but pulls `alsa-lib` and does not build on Darwin; TUI-only anyway |
| `crow-translate` | Linux-only in nixpkgs |

`translate-shell` was kept at first, with its aliases moved to `-e bing`, on the
conclusion that no maintained CLI alternative existed. That conclusion was an
artefact of a local firewall: it blocked mozhi's Go HTTP client while leaving
`curl` and `translate-shell` alone, so mozhi appeared to time out on every host
and to panic in `libmozhi/engines.go` — the panic being a nil dereference on a
blocked request. With the firewall out of the way mozhi works, is roughly four
times faster than `trans -e bing` (~0.45s against ~1.7s), and fails over across
engines by design. `translate-shell`'s own failures are genuine and unchanged:
its Google requests are rate-limited and its Yandex engine has been broken for
years.

The lesson worth keeping: when one binary fails to reach every host while another
reaches them all, suspect the local network policy before the binary.

Two upstream defects had to be worked around:

- `dictdDBs.*` and `mueller_eng2rus_pkg` declare `meta.platforms = linux` though
  they are data-only packages that build clean on Darwin. Handled by four
  entries under `modules/flake/workarounds/`, which the weekly probe will retire
  once nixpkgs relaxes the meta.
- The `.index` files FreeDict and WordNet ship are sorted in an order dictd's
  binary search does not share, so exact lookups miss at random. Measured over
  200 headwords drawn from the indexes themselves: WordNet found 147/200,
  `eng-deu` 112/200, `deu-eng` 60/200. `dictfmt -I` re-sorts an index into
  dictd's own collation and takes all three to ~200/200 (`deu-eng` needs
  `--utf8`, or every umlaut headword sorts to the wrong place).

  This one is **not** a `znix.workarounds` entry. A probe there proves a package
  *builds*, and these always did — it could never observe this being fixed
  upstream, so it would sit there reporting a false verdict forever. The rebuild
  lives in `modules/home/dict.nix` instead.

`znix.workarounds` gained support for nested attribute paths (`dictdDBs.eng2rus`),
since it previously addressed packages only by a flat top-level name.

Mueller's phonetic transcriptions are stored in a pre-Unicode encoding whose
display font is long gone — `/kæt/` is written `[kЭt]`. The substitution is 1:1,
so `dict-lookup` decodes it back to IPA, scoped to `[...]` so the Cyrillic
filling the Russian definitions is untouched, and applied to the Mueller section
only so the FreeDict databases' genuine IPA is never rewritten.

Not adopted: `wiktionary` as a database (513MB against WordNet's 32MB, for
etymology that is rarely wanted), and a ru→en dictionary — nixpkgs packages
none, and Russian words are looked up as phrases rather than defined.

LLM-backed translation was scoped out of this decision.
