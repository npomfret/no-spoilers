#!/usr/bin/env python3
"""The App Store Connect session that writes, and the one key that can.

Split out of `testflight_distribute.py` on 2026-08-22, when it stopped being
the only thing here that writes. It was correct while there was one writer and
would have been wrong the moment there were two: the App Manager key id would
have been spelled in two files, or the second writer would have imported the
first — making a listing edit load the TestFlight delivery tool for no reason
beyond which one happened to be written first.

**The read/write split this belongs to is unchanged, and is the point.**
`appstore_status.py` holds the shared read machinery and issues `GET`s alone, so
it is safe to run at any moment, including when things look wrong. Everything
that writes goes through the session here and says `--apply` before it acts.

There is no `Client` here and no token signing: both come from
`appstore_status`, because a second implementation of ES256 signing is a second
thing to get wrong. What is here is the key that is allowed to write and the
verb that does it.

The invariants — that a 403 hint names the key, and that the write key is not
the read-only one — are asserted in `testflight_distribute --selftest`, which
imports these names.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request

import appstore_status as asc

# An App Manager key. The Developer-level key `appstore_status.py` uses reads
# every endpoint these tools touch and is then refused the write with an empty
# 403, which is the least helpful error in this API — see `_hint`.
ADMIN_KEY_ID = "ASC6H3SL2D"


def _hint(code: int) -> str:
    """The two failures worth naming, because neither says what it means.

    A 403 from this API arrives with an empty `detail` and is indistinguishable
    from a malformed body, which sends you rewriting a request that was fine.
    """
    if code == 403:
        return (
            "\n\nA 403 here is almost always the key rather than the request: an App "
            "Store Connect key at Developer level reads all of this and is refused "
            f"every write. {ADMIN_KEY_ID} must still be an App Manager key."
        )
    if code == 401:
        return "\n\nA 401 means the .p8 is not an App Store Connect key, or the issuer is wrong."
    return ""


class Session:
    """Signs with `appstore_status`'s token, and writes, which it does not."""

    def __init__(self) -> None:
        key = asc.key_path(ADMIN_KEY_ID)
        if not key.exists():
            raise SystemExit(
                f"no private key at {key}\n"
                f"{ADMIN_KEY_ID} must be an App Manager key, downloadable once from "
                "App Store Connect > Users and Access > Integrations. The Developer key "
                "the rest of this repo uses cannot write."
            )
        self.bearer = asc.token(asc.ISSUER_ID, ADMIN_KEY_ID, key)

    def _call(self, method: str, path: str, body: dict | None = None) -> dict:
        request = urllib.request.Request(
            asc.API + path,
            data=json.dumps(body).encode() if body is not None else None,
            method=method,
            headers={
                "Authorization": f"Bearer {self.bearer}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=asc.TIMEOUT) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:400]
            raise SystemExit(f"{method} {path} -> HTTP {error.code}\n{detail}{_hint(error.code)}")

    def get(self, path: str) -> dict:
        return self._call("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self._call("POST", path, body)

    def patch(self, path: str, body: dict) -> dict:
        return self._call("PATCH", path, body)
