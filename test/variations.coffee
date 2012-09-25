
# test/variations - Test the variations module
do ->

  _ = require 'underscore'
  expect = require('chai').expect

  # template/macro
  checkFalsyInputs = (name) ->
    it 'should returns [] for null input', ->
      expect(this[name] null).to.eql []

    it 'should returns [] for undefined input', ->
      expect(this[name]()).to.eql []

    it 'should returns [] for empty array [] input', ->
      expect(this[name] []).to.eql []

    it "should returns [] for empty string '' input", ->
      expect(this[name] '').to.eql []

  # tests
  describe 'Variations module', ->
    before -> @var = require '../variations'
    after -> delete @var

    describe 'normalizeWords()', ->
      before -> @normalize = @var.normalizeWords
      after -> delete @normalize

      checkFalsyInputs 'normalize'

      # sample taken from the stringprep module
      it "should returns ['äffchen'] for string 'Äffchen' input", ->
        expect(@normalize 'Äffchen').to.eql(['äffchen'])

      it "should returns ['äffchen'] for array ['Äffchen'] input", ->
        expect(@normalize ['Äffchen']).to.eql(['äffchen'])

      it "should returns ['äffchen', 'ää'] for array ['Äffchen', 'ÄÄ'] input", ->
        expect(@normalize ['Äffchen', 'ÄÄ']).to.eql(['äffchen', 'ää'])

    describe 'splitWords()', ->
      before -> @split = @var.splitWords
      after -> delete @split

      checkFalsyInputs 'split'

      it "should returns ['one'] for 'one' input", ->
        expect(@split 'one').to.eql ['one']

      it "should returns ['ไทย'] for 'ไทย' input", ->
        expect(@split 'ไทย').to.eql ['ไทย']

      it "should returns ['ภาษา', 'ไทย'] for 'ภาษาไทย' input", ->
        expect(@split 'ภาษาไทย').to.eql ['ภาษา', 'ไทย']

    describe 'permuteWords()', ->
      before -> @permute = @var.permuteWords
      after -> delete @permute

      checkFalsyInputs 'permute'

      it "should returns ['word'] for single-word input", ->
        expect(@permute ['word']).to.eql ['word']

      it "should returns ['a', 'ab', 'b'] for two-words input", ->
        result = (@permute ['a', 'b']).sort()
        expect(result).to.eql ['a', 'ab', 'b'].sort()

      it "should returns ['a', 'ab', 'abc', 'b', 'bc', 'c'] for three-words input", ->
        result = (@permute "abc").sort()
        expect(result).to.eql ['a', 'ab', 'abc', 'b', 'bc', 'c'].sort()

    describe 'permuteTypos()', ->
      before -> @permute = @var.permuteTypos
      after -> delete @permute

      checkFalsyInputs 'permute'

      describe 'with degree 1', ->
        before -> @deg1 = (word) -> @permute word, 1
        after -> delete @deg1

        it "should returns superset of ['a', 'b'] for 'ab' input", ->
          expect(@deg1 'ab').to.include('a')
            .and.include('b')

        it "should returns superset of ['ab', 'bc', 'ac'] for 'abc' input", ->
          expect(@deg1 'abc').to.include('ab')
            .and.include('bc')
            .and.include('ac')

      describe 'with degree 2', ->
        before -> @deg2 = (word) -> @permute word, 2
        after -> delete @deg2

        it "should not returns any empty string for 'ab' input", ->
          expect(@deg2 'ab').to.not.include('')

        it "should returns superset of ['a', 'b'] for 'ab' input", ->
          expect(@deg2 'ab').to.include('a')
            .and.include('b')

        it "should returns superset of ['ab', 'ac', 'bc', 'a', 'b', 'c'] for 'abc' input", ->
          expect(@deg2 'abc').to.include('ab')
            .and.include('ac').and.include('bc')
            .and.include('a').and.include('b')
            .and.include('c')

      describe 'with degree 7 and 7-letters input', ->
        before -> @result = @permute (@input = 'abCDefG'), 7
        after -> delete @input and delete @result

        it "should include the input itself in output", ->
          expect(@result).to.include 'abCDefG'

        it "shuold produce no empty results", ->
          expect(@result).to.not.include ''

        it "should include seven 6-letters word in results", ->
          result = _(@result).filter (ar) -> ar.length == 6
          expect(result).to.have.length(7)

        it "should produce no duplicate results", ->
          expect(@result.sort()).to.eql _.uniq(@result).sort()

      describe 'with degree 10', ->
        before -> @deg10 = (word) -> @permute word, 10
        after -> delete @deg10

        it "should not takes longer than 100ms for a 15-letters word", ->
          # reference machine:
          # MBP 2GHz Intel Core i7
          # 4GB 1333 MHz DDR3
          @timeout(100)

          t = process.hrtime()
          @deg10 '012345678901234'
          t = process.hrtime(t)

          expect(t[0]).to.be.lt(1) # seconds
          expect(t[1]).to.be.lt(1000000 * 100) # nanoseconds

