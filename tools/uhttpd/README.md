# Remove obsolete browser connection quirks

Upstream review requested dropping the historical browser quirks entirely:
https://github.com/openwrt/uhttpd/pull/43#issuecomment-5759348841

This directory backports that change to shipped uhttpd revision
`3abcc89103799aaa79870fffcd58ec4370815024`. It contains source review materials;
it does not replace the existing IPKs, change firmware assembly or alter a
running modem.

## Change

Remove the unconditional Safari forced-close rule and the old IE POST
forced-close rule. Remove their now-unused UA classification, enum and request
field. The User-Agent header still follows ordinary header storage/forwarding;
it no longer controls connection lifetime.

There are no browser or version allowlists. The previous Safari/CriOS version
parsers and minimums are removed. Explicit `Connection: close`, HTTP/1.0,
configured keep-alive settings, timeout handling and other protocol-driven
close decisions remain unchanged. This intentionally retires the old-browser
workarounds rather than claiming that obsolete browser implementations work.

## Validation

`patches/100-remove-browser-quirks.patch` applies to pristine 3abcc891 sources.
The patched files were compared with the cross-build inputs. The WAS-110
GCC 7.5.0 MIPS32r2 soft-float/no-MIPS16 core build succeeds.

Run `python3 tools/uhttpd/test-keepalive.py /path/to/built/uhttpd` against a
native build. The identical real HTTP regression test is used upstream: eight
UA cases cover GET/POST reuse, ETag 304, explicit close, HTTP/1.0, keep-alive
disabled, and idle expiry/reconnection. It uses temporary files and loopback
only. UA strings test server header policy, not obsolete browser behavior.

Prior device switch experiments showed Safari loads improving from 4.08–4.54 s
to 0.42–2.13 s and CriOS from 4.47–6.72 s to 0.39–2.28 s. Both completed
45-second polling captures. Those builds bypassed the Safari close assignment;
they did not run this final removal patch or remove the IE quirk. The final
patch has not been installed on the modem. Current-master hardware behavior,
TLS/plugin integration and longer stability testing remain unverified.

Evidence: https://github.com/djGrrr/8311-was-110-firmware-builder/issues/54
Upstream: https://github.com/openwrt/uhttpd/issues/42
Upstream PR: https://github.com/openwrt/uhttpd/pull/43

## Package integration remains pending

The builder consumes prebuilt IPKs. Place the patch in the matching OpenWrt
uhttpd recipe's patch directory, normally
`package/network/services/uhttpd/patches/`, and increment its package release.

**Rebuild uhttpd and its Lua/ubus modules together.** Removing the request's UA
field changes a shared structure definition; do not combine the new core with
old binary plugins or deploy the earlier standalone-binary test procedure.
Use the firmware's compatible no-MIPS16 build configuration, validate the
matching package set in isolation, then replace the three corresponding IPKs
in `packages/basic/`. No SDK link-time libraries should replace modem libraries.
A firmware flash or permanent deployment is not part of this draft PR.
