# Testing Guide

Canonical testing and verification policy for this repo.

## Rules

- Never claim tests passed unless they were executed to completion.
- Run the smallest meaningful verification for the changed behavior first.
- Distinguish compile/build confidence from behavior-risk confidence.
- After a bug fix or behavior change, rerun the relevant verification before handoff.
- Prefer deterministic tests and explicit evidence over broad “should be fine” claims.
- If the repo standardizes wrappers for tests, use them instead of ad-hoc raw commands.

## Current state

- The Swift test surface is not fully defined yet.
- When the main package/project lands, update this guide with the canonical test commands, schemes, and destinations.
