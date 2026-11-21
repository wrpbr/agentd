# Third-party notices

Safeguard uses pinned upstream components. Their copyright notices and
licenses remain in each submodule:

| Component | Location | License |
| --- | --- | --- |
| tree-sitter | `third_party/tree-sitter` | MIT |
| JavaScript grammar | `third_party/tree-sitter-javascript` | MIT |
| TypeScript grammar | `third_party/tree-sitter-typescript` | MIT |
| doctest | `third_party/doctest` | MIT |
| bats-core | `tests/test_helper/bats-core` | MIT |
| bats-assert | `tests/test_helper/bats-assert` | CC0-1.0 |
| bats-file | `tests/test_helper/bats-file` | CC0-1.0 |
| bats-support | `tests/test_helper/bats-support` | CC0-1.0 |

The repository-map design and adapted tag queries draw on
[aider's RepoMap](https://github.com/Aider-AI/aider) (Apache-2.0).
Safeguard implements the graph and ranking in C++ and adjusts queries for
its native parser. The upstream license is included in
[licenses/aider.txt](licenses/aider.txt).

Release archives include the licenses of the linked runtime components.
