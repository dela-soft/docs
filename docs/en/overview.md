# Docs — overview

**Docs** is a layout and report editor application in the **DELTA+** project. It is meant for **automating printed forms**: you describe a document template once, then data is filled in when the document is produced.

Typical uses: HR and office printed forms, contract templates with counterparties, lists, certificates, statistical forms, and grouped reports — without manually laying out each copy.

## Purpose

- Create and edit **templates for printed forms and reports** (document layouts)
- Describe template-creation automation via the constructor (`.dtc`)
- Shape document structure (sections, pages, object placement)
- Bind form fields to automation expressions (**dela-script**)
- Build a finished document / report from a template (including from **Staff** — HR workflows)

## Files

| Extension | Purpose |
|-----------|---------|
| `.dlt` | Document layout / template (printed form, report) |
| `.dtc` | Description of template-creation automation using the constructor |

Exact format contracts and APIs will be filled in as documentation grows.

## Names

| Where | Name |
|-------|------|
| Documentation, product | **Docs** |
| Container / service | `delta:docs` |

## In the DELTA+ project

See [products and relationships](https://github.com/dela-soft/delta/blob/main/docs/en/products.md) in **DELTA+**.

In short:

- **Docs** — create and edit printed-form templates (layout, constructor, **dela-script** expressions)
- **Staff** (“DELTA+ Personal”) uses a template and Docs to produce HR documents and reports

## Русский

[Русская версия](../ru/overview.md)
