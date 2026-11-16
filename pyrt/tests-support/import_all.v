module main

// Keep every runtime module active in the V checker; unused imports are skipped.
// The checker must see this as a top-level program beside pyrt/, not inside pyrt/.
// From the project root:
//   cp pyrt/tests-support/import_all.v ./pyrt_import_all.v
//   v -check ./pyrt_import_all.v
//   v -W -check ./pyrt_import_all.v
//   rm ./pyrt_import_all.v
import pyrt
import pyrt.argparse
import pyrt.base64
import pyrt.collections
import pyrt.datetime
import pyrt.hashlib
import pyrt.json
import pyrt.logging
import pyrt.mcptypes
import pyrt.pathlib
import pyrt.pyos
import pyrt.pysys
import pyrt.pytime
import pyrt.random
import pyrt.re
import pyrt.secrets
import pyrt.shutil
import pyrt.sqlite3
import pyrt.subprocess
import pyrt.tempfile
import pyrt.uuid

fn main() {
    _ := pyrt.Value(1)
    _ := sizeof(argparse.ArgumentParser)
    _ := sizeof(base64.DecodeOptions)
    _ := sizeof(collections.Entry)
    _ := sizeof(datetime.Time)
    _ := sizeof(hashlib.Hash)
    _ := json.json_decode_error
    _ := logging.notset_level
    _ := sizeof(mcptypes.TextContentOptions)
    _ := sizeof(pathlib.Path)
    _ := pyos.environ
    _ := pysys.maxsize
    _ := pytime.time_
    _ := random.seed
    _ := re.ignorecase
    _ := secrets.token_bytes
    _ := shutil.rmtree
    _ := sizeof(sqlite3.Row)
    _ := subprocess.pipe
    _ := sizeof(tempfile.TempOptions)
    _ := sizeof(uuid.UUID)
}
