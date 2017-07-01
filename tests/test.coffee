execSync = require('execSync')
fs = require('fs')
consts = require('../lib/consts')
assert = require('assert')

describe 'selective test execution', ->
  beforeEach ->
    if fs.existsSync(consts.depsFile)
      fs.unlinkSync consts.depsFile

  it 'should only run tests that depend on changed code', ->
    results = runTests('aut_passing_tests.coffee')
    assert results.indexOf('3 passing') != -1, 'expected all tests to run because deps file does not exist yet'
    assert fs.existsSync(consts.depsFile), 'expected ' + consts.depsFile + ' to exist'
    deps = JSON.parse(fs.readFileSync(consts.depsFile))
    result = deps[Object.keys(deps)[0]]

    assert.deepEqual result, {
      'c':
        'should show a,b,c,e': [
          'tests/aut/aut_passing_tests.coffee'
          'tests/aut/a.coffee'
          'tests/aut/b.coffee'
          'tests/aut/c.coffee'
          'tests/aut/e.coffee'
        ]
        'should show a,b,c,e again': [
          'tests/aut/aut_passing_tests.coffee'
          'tests/aut/a.coffee'
          'tests/aut/b.coffee'
          'tests/aut/c.coffee'
          'tests/aut/e.coffee'
        ]
      'd':
        'should show a,b,d,e': [
          'tests/aut/aut_passing_tests.coffee'
          'tests/aut/a.coffee'
          'tests/aut/b.coffee'
          'tests/aut/e.coffee'
          'tests/aut/d.coffee'
        ]
    }, 'deps file does not contain expected content'
    
    results = runTests('aut_passing_tests.coffee')
    assert results.indexOf('0 passing') != -1, 'expected no tests to run because no code changes have been made'
    i = 0
    
    while i < 2
      results = runTests('aut_passing_tests.coffee', 'modified:   tests/aut/c.coffee')
      assert results.indexOf('2 passing') != -1, 'expected 2 tests to run because c.coffee has changed'
      i++
    results = runTests('aut_passing_tests.coffee')
    assert results.indexOf('0 passing') != -1, 'expected no tests to run because no code changes have been made'

  it 'should not have entry in deps file for failing tests', ->
    results = runTests('aut_failing_tests.coffee')
    #execSync cannot read stderr so we cannot detect this
    #assert(results.indexOf('1 of 2 tests failed')!=-1, 'expected one test to fail, and one test to pass')
    assert fs.existsSync(consts.depsFile), 'expected ' + consts.depsFile + ' to exist'
    deps = fs.readFileSync(consts.depsFile).toString()
    assert.notEqual deps.indexOf('should pass'), -1, 'deps file does not contain expected content'
    assert.equal deps.indexOf('should fail'), -1, 'deps file does not contain expected content'

  it 'should distinguish between tests with the same name', ->
    runTests 'aut_tests_duplicate1.coffee'
    runTests 'aut_tests_duplicate2.coffee', 'modified:   tests/aut/a.coffee'
    deps = JSON.parse(fs.readFileSync(consts.depsFile))
    result1 = JSON.stringify(deps[Object.keys(deps)[0]])
    result2 = JSON.stringify(deps[Object.keys(deps)[1]])
    assert.notEqual result1.indexOf('a.coffee'), -1, 'deps file does not contain expected content'
    assert.notEqual result1.indexOf('c.coffee'), -1, 'deps file does not contain expected content'
    assert.equal result1.indexOf('d.coffee'), -1, 'deps file does not contain expected content'
    assert.notEqual result2.indexOf('a.coffee'), -1, 'deps file does not contain expected content'
    assert.equal result2.indexOf('c.coffee'), -1, 'deps file does not contain expected content'
    assert.notEqual result2.indexOf('d.coffee'), -1, 'deps file does not contain expected content'

  it 'should run a test if its test file has changed', ->
    `var results`
    results = runTests('aut_passing_tests.coffee')
    assert results.indexOf('3 passing') != -1, 'expected all tests to run because deps file does not exist yet'
    results = runTests('aut_passing_tests.coffee', 'deleted: tests/aut/aut_passing_tests.coffee')
    assert results.indexOf('3 passing') != -1, 'expected all tests to run because the tests file has changed'

runTests = (file, gitstatus) ->
  gitstatus = gitstatus or ' '
  cmd = "gitstatus=\"#{gitstatus}\" ./node_modules/mocha/bin/mocha ./first.coffee ./tests/aut/#{file} --compilers coffee:coffee-script/register"
  res = execSync.stdout(cmd)
  res  
