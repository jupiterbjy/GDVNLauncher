class_name Globals
## Just a globals static namespace

const DEBUG := true

const VERSION: String = "0.0.2"

## Commit hash. This will be replaced in pipeline builds.
## Otherwise for editor build/export, it remains 'DEV'.
static var COMMIT_HASH: String = "DEV"
