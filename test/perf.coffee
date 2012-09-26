
# perf - Test all modules for perfs and leaks in general

_ = require 'underscore'
a = require 'async'

# test data
word = 'Honorificabilitudinitatibus'
words = 'the quick brown fox jumps over the lazy dog'.split(' ')

# check template
leakCheck = (action) ->
  if typeof action == 'object'
    return (for key, value of action
      do (key, value) ->
        describe key, ->
          leakCheck -> value
    )

  if action.length == 0
    action = ((oldAction) ->
      (done) ->
        oldAction()
        process.nextTick done
    )(action)

  iterate = (num) ->
    it "#{num} iterations", (done) ->
      @timeout 5000
      a.forEach [1..num], ((n, next) => action.call(this, next)), done

  for i in [1..7]
    iterate Math.pow(10, i)


# describe tests
describe 'Leaks test', ->

  describe 'variations module', ->
    before -> @var = require '../variations'
    after -> delete @var

    # templated tests
    leakCheck
      normalizeWords: -> @var.normalizeWords(words)
      splitWords: -> @var.splitWords(word)
      permuteWords: -> @var.permuteWords(words)
      permuteTypos: -> @var.permuteTypos(word)

  describe 'indexer module', ->
    before -> @indexer = require '../indexer'
    after -> delete @indexer

    leakCheck
      addKey: (cb) -> @indexer.addKey 10, word, cb
      removeKey: (cb) -> @indexer.removeKey 10, word, cb
      index: (cb) -> @indexer.index 10, words, cb
      query: (cb) -> @indexer.query word, cb

