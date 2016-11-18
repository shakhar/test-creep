
assert = require('assert')

a = require("./a")

describe 'c', -> 
  it 'should show a,b,c,e', -> a.a1()
  it 'should show a,b,c,e again', -> a.a1()

describe 'd', ->  
  it 'should show a,b,d,e', -> a.a2()
