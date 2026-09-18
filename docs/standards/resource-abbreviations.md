# Resource abbreviations

> **Guidance for people using Varde Flyt.** This page is [non-normative](../index.md#status-of-this-documentation): its recommendations are not platform rules, and nothing here constrains how the platform is built.

Resource abbreviations are short, stable codes for a Product's *functional* type — what kind of thing it is, rather than what it is called.

They exist as shared vocabulary. Writing `gw` in a Resource name, a diagram, a runbook, or a conversation says "gateway" to everyone in the room without tying the wording to a Product's branding, which can change.

They are intentionally separate from Product display names and platform object IDs.

## What the platform actually generates

**The platform does not read these abbreviations, and none of them appears in a name it constructs.**

This is worth stating plainly, because the table below can look like a registry the code consults. It is not one. The provider resource names Varde Flyt generates are built from the Product ID and the instance key — the shapes are owned by [CONVENTIONS.md](../../CONVENTIONS.md) §19, and the Product ID itself by [CONVENTIONS.md](../../CONVENTIONS.md) §8. Nothing in the platform looks up an abbreviation, validates one, or would behave differently if this page were deleted.

So the audience for this page is a person choosing a name, writing a document, or explaining a system to a colleague. If you are implementing the platform, there is no requirement here to satisfy.

## Suggestions for choosing one

A resource abbreviation is easiest to live with when it:

- describes the Product's functional resource type rather than its marketing name;
- is lowercase ASCII;
- is two to four characters;
- stays the same once people have started using it;
- is distinct enough that two Products are not confused for one another;
- leaves out environment, region, customer, or version information — those belong in the surrounding name, if anywhere;
- is chosen deliberately rather than shortened mechanically from the display name.

None of these is checked by anything. They are the habits that make an abbreviation useful instead of another thing to look up.

## Product resource abbreviations

The abbreviations currently used when writing and talking about Varde Flyt Products:

| Product | Resource abbreviation | Rationale |
| --- | --- | --- |
| Rute | `gw` | Gateway |
| Kode | `dev` or `ide` | Developer environment / development workspace |
| Frende | `agt` | Agent |
| Vern | `dps` or `sec` | Data protection / security |
| Scene | `mcp` | MCP service/server, when this is the Product's primary role |
| Venn | `chat` | Chat/assistant surface |

Where two alternatives are listed, both are in use. Within one deployment it reads better to pick one and stay with it than to alternate.

Adding a new Product's abbreviation here first is a courtesy to the next reader, not a gate on anything.

## Platform object IDs are different

These abbreviations do not replace Varde Flyt object identifiers, which the platform very much does read.

Examples:

| Object | ID prefix |
| --- | --- |
| Organization | `ten_` |
| Project | `prj_` |
| Product | `prd_` |
| Resource | `pri_` |
| Operation | `op_` |

The full set of prefixes, and the rules for them, are owned by [CONVENTIONS.md](../../CONVENTIONS.md) §3.

An example relationship is therefore:

```text
Product:        prd_...
Resource:       pri_...
Product type:   gw
```

The opaque IDs establish identity. The abbreviation is a word people use about the Product.

## Future infrastructure abbreviations

This page may later collect generic infrastructure abbreviations — runtime, database, object storage, virtual machine. They are worth adding when people are already using them and want to agree on spelling. They are not worth inventing here in the hope that the platform adopts them: the platform's own naming is owned by [CONVENTIONS.md](../../CONVENTIONS.md) §14, and a word invented on this page has no effect on it.
