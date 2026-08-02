# Document model

A short map of Docs concepts. API and wire details will be added as documentation grows.

## Section

A document consists of one or more **sections**.

Each section has:

- a single **page format** (size, orientation, margins);
- section text flow and root placement objects.

Different formats (for example portrait and landscape) are **different sections** one after another, not different formats inside one section.

## Page

Sheet parameters for a section: width/height, margins, and the work area inside the margins (`WorkWidth` / `WorkHeight`).

Placement object coordinates are **relative to the work area** (excluding margins). Margins are applied when the sheet is rendered.

## Placement

Floating objects on the sheet: text, panels, shapes, and so on.

- Root objects belong to the section.
- Objects inside a **panel** use coordinates relative to that panel.

Examples — in [examples/](../../examples/) (as files appear).

## Русский

[Русская версия](../ru/document-model.md)
