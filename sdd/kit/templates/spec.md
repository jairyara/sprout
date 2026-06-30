# Spec — {{FEATURE}}

> Written by `sdd-spec` from `sdd/spec.prompt.md`. This is the source of truth for the
> feature. The plan, the build, and the verification all trace back to the acceptance
> criteria below. Keep it free of implementation detail.

- **Status:** draft
- **Created:** {{DATE}}

## Goal

<!-- the outcome, in 1–3 sentences -->

## Users & job-to-be-done

<!-- who, and what they're trying to accomplish -->

## Acceptance criteria

<!-- numbered so plan/verify can reference them as AC1, AC2, … -->
1. 
2. 

## Non-goals

- 

## Constraints & assumptions

- 

## Contract

<!-- The interface at any front/back or service boundary: data shapes + API. Fill this ONLY
if the feature crosses such a boundary. It's the source of truth two agents build against in
parallel (see the orchestration "waves" flow) — freeze it before fanning work out, or the
sides diverge and integration breaks. Interface only, not implementation. Leave as "N/A" for
a single-surface feature. -->

- **Data shapes:** <!-- e.g. User { id: string; email: string; invitedAt: ISO8601 } -->
- **API / endpoints:** <!-- e.g. POST /invites {email} -> 201 {inviteId} | 409 {error} -->

## Resolved questions

<!-- decisions made while drafting (was an open question → now answered) -->
- 
