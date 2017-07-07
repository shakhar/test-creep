path = require('path')
fs = require('fs')
istanbul = require('istanbul')

hook = istanbul.hook
Instrumenter = require('./coffeeCoverage').CoverageInstrumentor
Collector = istanbul.Collector
instrumenter = new Instrumenter()
Report = istanbul.Report
collector = undefined
globalAdded = false
fileMap = {}

###*
# Facade for all coverage operations support node as well as browser cases
#
# Usage:
# ```
#  //Node unit tests
#  var coverage = require('/path/to/this/file');
#  coverage.hookRequire(); // hooks require for instrumentation
#  coverage.addInstrumentCandidate(file); // adds a file that needs to be instrumented; should be called before file is `require`d
#
#  //Browser tests
#  var coverage = require('/path/to/this/file');
#  var instrumentedCode = coverage.instrumentFile(file); //alternatively, use `instrumentCode` if you have already loaded the code
#  //collect coverage from the browser
#  // this coverage will be stored as `window.__coverage__`
#  // and...
#  coverage.addCoverage(coverageObject); // rinse and repeat
#  ```
#
#  //in all cases, add an exit handler to the process
#  process.once('exit', function () { coverage.writeReports(outputDir); }); //write coverage reports
###

###*
# adds a file as a candidate for instrumentation when require is hooked
# @method addInstrumentCandidate
# @param file the file to add as an instrumentation candidate
###

addInstrumentCandidate = (file) ->
  file = path.resolve(file)
  fileMap[file] = true
  return

###*
# hooks require to instrument all files that have been specified as instrumentation candidates
# @method hookRequire
# @param verbose true for debug messages
###

hookRequire = (verbose) ->

  matchFn = (file) ->

    ###
    var match = fileMap[file],
        what = match ? 'Hooking' : 'NOT hooking';
    if (verbose) { console.log(what + file); }
    return match;
    ###

    res = file.indexOf('node_modules') == -1
    what = if res then 'Hooking ' else 'NOT hooking '
    console.log what + file if verbose
    res

  transformFn = (source, fileName, options={}) =>
    result = instrumenter.instrumentCoffee.call instrumenter, fileName, source, options
    return result.init + result.js

  hook.hookRequire matchFn, transformFn, { extensions: [".coffee"] }
  return

###*
# unhooks require hooks that have been installed
# @method unhookRequire
###

unhookRequire = ->
  hook.unhookRequire()
  return

getCollector = ->
  getCollectorInternal false

###*
# returns the coverage collector, creating one if necessary and automatically
# adding the contents of the global coverage object. You can use this method
# in an exit handler to get the accumulated coverage.
###

getCollectorInternal = (createNew) ->
  if !collector or createNew
    collector = new Collector
  if globalAdded and !createNew
    return collector
  if global['__coverage__']
    collector.addInternal global['__coverage__'], true
    globalAdded = true
  else
    console.error 'No global coverage found for the node process'
  collector

###*
# adds coverage to the collector for browser test cases
# @param coverageObject the coverage object to add
###

addCoverage = (coverageObject) ->
  if !collector
    collector = new Collector

  collector.add coverageObject

###*
# returns the merged coverage for the collector
###

getFinalCoverage = ->
  getCollector().getFinalCoverage()

###*
# writes reports for an array of JSON files representing partial coverage information
# @method writeReportsFor
# @param fileList array of file names containing partial coverage objects
# @param dir the output directory for reports
###

writeReportsFor = (fileList, dir) ->
  `var collector`
  collector = new Collector

  fileList.forEach (file) ->
    coverage = JSON.parse(fs.readFileSync(file, 'utf8'))
    collector.addCoverage coverage

  writeReportsInternal dir, collector

###*
# writes reports for everything accumulated by the collector
# @method writeReports
# @param dir the output directory for reports
###

writeReports = (dir) ->
  writeReportsInternal dir, getCollector()

writeReportsInternal = (dir, collector) ->
  dir = dir or process.cwd()
  reports = [
    Report.create('lcov', dir: dir)
    Report.create('text')
    Report.create('text-summary')
  ]
  reports.forEach (report) ->
    report.writeReport collector, true

###*
# returns the instrumented version of the code specified
# @param {String} code the code to instrument
# @param {String} file the file from which the code was load
# @return {String} the instrumented version of the code in the file
###

instrumentCode = (code, filename) ->
  filename = path.resolve(filename)
  instrumenter.instrumentSync code, filename

###*
# returns the instrumented version of the code present in the specified file
# @param file the file to load
# @return {String} the instrumented version of the code in the file
###

instrumentFile = (file) ->
  filename = path.resolve(file)
  instrumentCode fs.readFileSync(file, 'utf8'), file

module.exports =
  addInstrumentCandidate: addInstrumentCandidate
  hookRequire: hookRequire
  unhookRequire: unhookRequire
  instrumentCode: instrumentCode
  instrumentFile: instrumentFile
  addCoverage: addCoverage
  writeReports: writeReports
  getCollectorInternal: getCollectorInternal