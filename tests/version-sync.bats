#!/usr/bin/env bats

@test "marketplace plugin metadata is bumped to 0.2.2" {
  root_version="$(python3 -c 'import json; print(json.load(open("/Users/ray/Documents/projects/ryskill-marketplace/plugin.json"))["version"])')"
  claude_version="$(python3 -c 'import json; print(json.load(open("/Users/ray/Documents/projects/ryskill-marketplace/.claude-plugin/plugin.json"))["version"])')"

  [ "$root_version" = "0.2.2" ]
  [ "$claude_version" = "0.2.2" ]
}
