fs = require('fs')
path = require('path')
execSync = require('execSync')
mocha = require('mocha')
consts = require('./consts')
coverage = require('./coverage')

selective = 
  depsTree: {}
  testsToRun: {}
  verbose: false

  init: ->
    selective.log 'initializing selective execution...'
    @loadDepsTree()
    @loadChangedFiles()

  loadDepsTree: ->
    if fs.existsSync(consts.depsFile)
      deps = fs.readFileSync(consts.depsFile)
      @depsTree = JSON.parse(deps)
      selective.log 'loading deps tree from disk:\n' + deps

    selective.log 'done loading deps tree'

  saveDepsTree: ->
    deps = JSON.stringify(@depsTree, null, 4)
    fs.writeFileSync consts.depsFile, deps
    selective.log 'saved deps tree to disk:\n' + deps

  cleanCoverageCounts: ->
    selective.log 'trying to clean coverage report...'

    return if typeof __coverage__ == 'undefined'

    for file of __coverage__
      for line of __coverage__[file].s
        __coverage__[file].s[line] = 0

    selective.log 'coverage report clean'

  updateCoverageCounts: (test) ->
    `var coverage`
    selective.log 'updating coverage count for test ' + test.title + '...'
    coverage = @getCurrentCoverage()
    selective.log 'coverage for test:\n' + JSON.stringify(coverage, null, 4)
    console.log test.parent.title
    @depsTree[test.file] ?= {}
    @depsTree[test.file][test.parent.title] ?= {}
    @depsTree[test.file][test.parent.title][test.title] = coverage
    selective.log 'total coverage:\n' + JSON.stringify(@depsTree, null, 4)

  removeFromCoverage: (test) ->
    selective.log 'removing coverage count for test ' + test.title + '...'
    delete @depsTree[test.file]?[test.parent.title]?[test.title]

  getCurrentCoverage: ->
    return if typeof __coverage__ == 'undefined'

    selective.log('current coverage:\n' + JSON.stringify(__coverage__, null, 4))
    res = []

    for file of __coverage__
      for line of __coverage__[file].s
        if __coverage__[file].s[line] > 0
          relative = path.relative(process.cwd(), file)
          res.push relative
          break
    res

  loadChangedFiles: ->
    selective.log 'loading changed files...'
    selective.log 'process.env[gitstatus]: ' + process.env['gitstatus']
    changedFiles = {}

    #using env var is good for testing of the test-select library 
    diff = process.env['gitstatus'] or execSync.stdout('git status')
    selective.log 'diff is:\n' + diff

    rePattern = new RegExp(/(modified|deleted|added):\s*(.*)/g)
    match = rePattern.exec(diff)

    while match != null
      selective.log 'changed file: ' + match[2]
      changedFiles[match[2]] = true
      match = rePattern.exec(diff)

    selective.log 'deps tree:\n' + JSON.stringify(@depsTree, null, 4)
    selective.log 'changed files:\n' + JSON.stringify(changedFiles, null, 4)

    for testFile of @depsTree
      for parent of @depsTree[testFile]
        for test of @depsTree[testFile][parent]
          @testsToRun[test] = false
          for file of @depsTree[testFile][parent][test]
            if changedFiles[@depsTree[testFile][parent][test][file]]
              @testsToRun[test] = true

    selective.log 'tests to run\n' + JSON.stringify(@testsToRun, null, 4)
  
  log: (str) -> console.log str + '\n' if @verbose

selective.log 'starting selective execution'
selective.verbose = process.argv.indexOf('--verbose') != -1
coverage.hookRequire selective.verbose
selective.init()

mocha.Runner::runTests = (suite, fn) ->
  self = this
  tests = suite.tests.slice()
  test = undefined

  next = (err) ->
    # if we bail after first err
    if self.failures and suite._bail
      return fn()
    # next test          
    test = tests.shift()
    # all done
    if !test
      return fn()
    #**this is the line added for selective testing    
    if selective.testsToRun[test.title] == false
      selective.log 'skipping test:\n' + test.title
      return next()
    # grep
    match = self._grep.test(test.fullTitle())
    if self._invert
      match = !match
    if !match
      return next()
    # pending
    if test.pending
      self.emit 'pending', test
      self.emit 'test end', test
      return next()
    # execute test and hook(s)
    self.emit 'test', self.test = test
    self.hookDown 'beforeEach', ->
      self.currentRunnable = self.test
      self.runTest (err) -> 
        test = self.test
        if err?
          self.fail test, err
          self.emit 'test end', test
          return self.hookUp('afterEach', next)
        test.state = 'passed'
        self.emit 'pass', test
        self.emit 'test end', test
        self.hookUp 'afterEach', next

  @next = next
  next()

innerRunner = mocha.Runner

mocha.Runner = (suite) ->
  runner = new innerRunner(suite)
  
  runner.on 'end', ->
    selective.saveDepsTree()
  
  runner.on 'test', (test) ->
    selective.cleanCoverageCounts()
    selective.log 'start run test:\n' + test.title
  
  runner.on 'pass', (test) ->
    selective.updateCoverageCounts test
    selective.log 'end run test (pass):\n' + test.title
  
  runner.on 'fail', (test) ->
    selective.removeFromCoverage test
    selective.log 'end run test (fail):\n' + test.title
  
  runner