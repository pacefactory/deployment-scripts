---
title: "Ghosting configuration"
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.social.yml
  - compose/docker-compose.expresso-010.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Ghosting configuration

Two build variables control whether unghosted snapshot images can be seen.
They are declared in the `base` fragment and reach several services.

| Variable | Default | Reaches | Source |
|---|---|---|---|
| `WEBGUI_FORCE_GHOSTING` | `true` | `auditgui` (`WEBGUI_FORCE_GHOSTING`), `social_web_app` (`SOCIAL_FORCE_GHOSTING`) | `compose/docker-compose.base.yml:17-19,262`; `compose/docker-compose.social.yml:29` |
| `DBSERVER_DISABLE_SNAPSHOT_IMAGES` | `true` | `dbserver`, `service_gifwrapper` | `compose/docker-compose.base.yml:26-28,159,289` |
| `WEBGUI_UNGHOSTED_CAMERA_LIST` | `""` | `auditgui` | `compose/docker-compose.base.yml:20-22,263` |
| `WEBGUI_DEFAULT_GHOSTING_TYPE` | `ghosted` | `auditgui`, `social_web_app` (`SOCIAL_DEFAULT_GHOSTING_TYPE`) | `compose/docker-compose.base.yml:23-25,264`; `compose/docker-compose.social.yml:30` |

## Modes

| Mode | `WEBGUI_FORCE_GHOSTING` | `DBSERVER_DISABLE_SNAPSHOT_IMAGES` | Effect (as described by the fragments) |
|---|---|---|---|
| Hard (default) | `true` | `true` | Ghosting toggle locked in the web UI; dbserver does not register unghosted snapshot endpoints ("hard ghosting enforcement", `base.yml:27`). |
| Soft | `true` | `false` | Toggle locked, but cameras in `WEBGUI_UNGHOSTED_CAMERA_LIST` may be shown unghosted; dbserver snapshot endpoints available. |
| None | `false` | `false` | Users control ghosting. |

`WEBGUI_DEFAULT_GHOSTING_TYPE` selects the initial style only, one of
`no_image`, `edges`, `edges_inverted`, `ghosted`, `ghosted_blur`, `color_invert`
(`base.yml:24`); it is independent of the lock.

When dbserver snapshot endpoints are disabled, `service_gifwrapper` and
`expresso_server` read snapshot JPEGs directly from a read-only mount of the
`dbserver-data` volume (`compose/docker-compose.base.yml:289-292`,
`compose/docker-compose.expresso-010.yml:47-50,71-75`).

Semantics inside each service (what "locked" means in the UI, fallback for an
unrecognised style) are owned by scv3_webgui, social_web_app and scv2_dbserver.

## Migration

New deployments default to hard mode. Existing deployments that rely on
`WEBGUI_UNGHOSTED_CAMERA_LIST` must set `DBSERVER_DISABLE_SNAPSHOT_IMAGES=false`
in `.env` to keep soft mode.
