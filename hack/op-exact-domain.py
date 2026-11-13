#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["onepassword-sdk"]
# ///
"""Set 1Password autofill to "only fill on this exact host" for every website URL on a domain.

`op` cannot read or change autofill behavior, so this goes through the SDK.

Usage: hack/op-exact-domain.py ACCOUNT DOMAIN [--apply]
  e.g. hack/op-exact-domain.py my.1password.eu zebradil.dev

Without --apply it only prints what would change. Matches DOMAIN and all its subdomains.
Needs 1Password app > Settings > Developer > "Integrate with other apps" enabled.
"""
import asyncio
import sys
from urllib.parse import urlparse

from onepassword import AutofillBehavior, Client, DesktopAuth


def matches(url: str, domain: str) -> bool:
    host = urlparse(url if "://" in url else f"https://{url}").hostname or ""
    return host == domain or host.endswith("." + domain)


async def main(account: str, domain: str, apply: bool) -> None:
    client = await Client.authenticate(
        auth=DesktopAuth(account_name=account),
        integration_name="exact-domain-autofill",
        integration_version="1.0",
    )
    skipped = []
    for vault in await client.vaults.list():
        for overview in await client.items.list(vault.id):
            if not any(matches(w.url, domain) for w in overview.websites):
                continue
            item = await client.items.get(vault.id, overview.id)
            todo = [w for w in item.websites
                    if matches(w.url, domain) and w.autofill_behavior != AutofillBehavior.EXACTDOMAIN]
            for w in todo:
                print(f"{vault.title} / {item.title}: {w.url} {w.autofill_behavior.value} -> ExactDomain")
                w.autofill_behavior = AutofillBehavior.EXACTDOMAIN
            if todo and apply:
                try:
                    await client.items.put(item)
                except Exception as e:
                    # The SDK refuses to save items with field types it can't model, e.g. "sign in with".
                    skipped.append(f"{vault.title} / {item.title}: {e}")
    for s in skipped:
        print(f"SKIPPED, change in app: {s}")
    if not apply:
        print("dry run; pass --apply to save")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    asyncio.run(main(sys.argv[1], sys.argv[2], "--apply" in sys.argv[3:]))
