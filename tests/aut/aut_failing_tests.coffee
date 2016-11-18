
assert = require('assert')

a = require("./a")

describe 'd', ->
  it 'should pass', ->
    a.a1()
  
  it 'should fail', ->
    assert false
