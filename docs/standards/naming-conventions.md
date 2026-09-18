# Naming conventions

> **Guidance for people using Varde Flyt.** This page is [non-normative](../index.md#status-of-this-documentation): its recommendations are not platform rules, and nothing here constrains how the platform is built.

Consistent names make Resources easier to understand, operate, search, and automate.

Everything on this page is a **suggestion** — a house style, offered because names chosen without one drift apart and become hard to scan. None of it is validated. The platform requires that a display name is not empty and — for a Resource — not absurdly long; it does not check the shape of a name at all, and it will not refuse one for departing from any recommendation here.

Varde Flyt does separate **human-readable names** from **stable technical identity**, and that part is not a matter of taste. A name explains what something is for. An ID establishes what object it is. The rules for identifiers are owned by [CONVENTIONS.md](../../CONVENTIONS.md) §3.

## General principles

Names tend to work well when they are:

- short enough to scan easily;
- descriptive to another person without extra context;
- based on workload or purpose rather than implementation details;
- stable enough that ordinary infrastructure changes do not make the name misleading;
- lowercase, where a machine-readable name or slug is called for.

These usually age badly inside a name:

- personal names;
- dates that will become stale;
- cloud-provider resource types, unless the resource itself represents that concept;
- generated IDs;
- temporary implementation technologies.

Secrets and sensitive customer data are the one exception to the advisory framing of this page: a name is displayed, logged, and searched, so it is never a place for either.

## Organizations

Use the recognizable customer or business name as the display name.

The Organization display name is not its technical identity and may change independently of the underlying platform identifier.

## Projects

Project names read best when they describe a logical workload, team, environment, or responsibility boundary.

Examples:

```text
customer-service
finance-automation
ai-platform
internal-development
```

## Resources

For simple deployments, a descriptive workload name is enough:

```text
customer-support
code-environment
ai-gateway
```

When more context is useful, this order is a reasonable default:

```text
<workload>-<purpose>-<environment>
```

Examples:

```text
customer-support-chat-prod
finance-gateway-prod
engineering-code-dev
```

An environment token adds nothing when the surrounding Project already makes the environment obvious.

## Display names versus IDs

Display names are for people and may be mutable.

Platform IDs are opaque, immutable identifiers such as:

```text
ten_...
prj_...
prd_...
pri_...
```

Do not derive authorization, ownership, or automation identity from a mutable display name. Unlike the rest of this page, that is a real platform rule and not a style preference: keying data by a display name is refused by [CONVENTIONS.md](../../CONVENTIONS.md) §3, and [SECURITY.md](../../SECURITY.md) §2 requires that identity be enforced server-side rather than taken from a label.

## Product resource abbreviations

A Product may have a short abbreviation describing its functional resource type, independent of its marketing name — **Rute** is an AI Gateway, so people write:

```text
gw
```

This is vocabulary for people writing names and documents. The platform does not read it, and it never appears in a name the platform generates.

See [Resource abbreviations](resource-abbreviations.md).
