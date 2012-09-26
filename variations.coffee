
# variations - Generate search variations from given word
# TODO: Tests for the string normalization
module.exports = do ->

  _ = require 'underscore'
  splitWords = require 'icu-wordsplit'
  normalize = do ->
    StringPrep = require('node-stringprep').StringPrep
    prep = new StringPrep('nameprep')

    _.bindAll(prep)
    return prep.prepare

  return vars =
    normalizeWords: (words) ->
      return [] if !words? || words.length == 0
      words = [words] if typeof words == 'string'

      return (normalize(word) for word in words)

    splitWords: (word) ->
      return [] if !word? || word.length == 0
      splitWords(word)

    permuteWords: (words, degree) ->
      return [] if !words?
      return [words[0]] if words.length == 1
      degree ?= 3

      (_permute = (words, idx) ->
        return [] if idx == words.length

        word = words[idx]
        results = [word]

        # generate permutation from current word down
        from = idx + 1
        to = Math.min(words.length, degree) - 1

        for i in [from .. to] by 1
          word += words[i]
          results.push word

        # add results from next level
        results.push.apply results, _permute(words, idx + 1)
        return results

      )(words, 0)

    permuteTypos: (word, degree) ->
      return [] if !word? || word.length == 0
      degree ?= 2

      # cache everything early on so we don't slow down during tight loops
      uniq = { }
      results = [word]
      prevDegree = [word] # 0-degree = no typo

      # builds result from a degree by using result from previous degree
      for i in [1 .. degree] by 1

        results_ = []
        for result in prevDegree
          for i in [0 .. result.length - 1] by 1
            typo = result.substr 0, i
            typo += result.substr i + 1
            if typo.length and !uniq[typo]
              results_.push typo
              results.push typo
              uniq[typo] = true

        prevDegree = results_

      return results

