---
name: grill-me
description: Interview the user relentlessly about plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mention "grill me"
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one

If a question can be answered by exploring the codebase, explore the codebase instead

When the session arguments mention "prd" or "write prd" (or similar), invoke the `to-prd` skill automatically once all decisions are resolved — do not ask the user to run it separately.
