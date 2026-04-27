---
trigger: manual
---

# Generate Release Notes

When this rule is manually triggered, generate release notes for the upcoming release by analyzing recent commit history.

## Instructions:
1. Use the `run_command` tool to execute `git log main..HEAD --oneline` (or equivalent branch comparison) to find all new commits in the current branch.
2. Review the commit messages and categorize the changes into features, bug fixes, and maintenance/chores.
3. Formulate a structured and readable summary of the changes.
4. Output the release notes by creating an artifact named `release_notes.md` containing the summary.
