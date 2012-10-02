
# test/variations.async - Test the asynchronous version of some of the variations module method
do ->

  _ = require 'underscore'
  expect = require('chai').expect

  # tests
  describe 'Variations module (async)', ->
    before -> @var = require '../variations'
    after -> delete @var

    describe 'permuteWordsAsync()', ->
      before -> @permute = @var.permuteWordsAsync
      after -> delete @permute

      it 'should throws if words is not an array or a string', ->
        expect(=> @permute 123, 123).to.throws /words/

      it 'should throws if degree is not number', ->
        expect(=> @permute 'word', 'word').to.throws /degree/

      it 'should returns [] if words input is falsy', (done) ->
        @permute null, 5, (e, result) ->
          done e, expect(result).to.eql([])

      it 'should returns [] if words input has length 0', (done) ->
        @permute [], 5, (e, result) ->
          done e, expect(result).to.eql([])

      it 'should calls back for valid input', (done) ->
        @timeout 100
        @permute 'word', 1, (e, result) ->
          done e, expect(result).to.be.an('array')

      it 'should calls complete callback for valid input', (done) ->
        @timeout 100
        @permute 'word', 1, ((e, result) ->), done

      it "should returns ['word'] for single-word input", (done) ->
        @timeout 100
        @permute ['word'], 1, (e, result) ->
          done e, expect(result).to.eql(['word'])

      it "should returns ['a', 'ab', 'b'] for two-words input"


