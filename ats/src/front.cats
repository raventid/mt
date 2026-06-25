// front.cats — JS glue for the MT frontend (the $extnam() counterparts).
// Same convention as the prelude: the ATS extern name === the JS name.
function MT_argv1() { return process.argv.length > 2 ? process.argv[2] : "" }
function MT_read_file(p) { return require('fs').readFileSync(p, 'utf8') }
function MT_die(s) { process.stderr.write("mt: " + s + "\n"); process.exit(1) }
